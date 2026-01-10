import Foundation
import CoreBluetooth
import Clibdivecomputer
import LibDCBridge
#if canImport(UIKit)
import UIKit
#endif

public class DiveLogRetriever {
    public class CallbackContext {
        var logCount: Int = 1
        let viewModel: DiveDataViewModel
        var lastFingerprint: Data?
        let deviceName: String
        let deviceUUID: String
        var deviceSerial: String?
        var hasNewDives: Bool = false
        weak var bluetoothManager: CoreBluetoothManager?
        var devicePtr: UnsafeMutablePointer<device_data_t>?
        var hasDeviceInfo: Bool = false
        var storedFingerprint: Data?
        var isCompleted: Bool = false
        
        var detectedFamily: dc_family_t = DC_FAMILY_NULL
        var detectedModel: UInt32 = 0
        
        init(viewModel: DiveDataViewModel, deviceName: String, deviceUUID: String, storedFingerprint: Data?, bluetoothManager: CoreBluetoothManager) {
            self.viewModel = viewModel
            self.deviceName = deviceName
            self.deviceUUID = deviceUUID
            self.storedFingerprint = storedFingerprint
            self.bluetoothManager = bluetoothManager
        }
    }

    private static let diveCallbackClosure: @convention(c) (
        UnsafePointer<UInt8>?,
        UInt32,
        UnsafePointer<UInt8>?,
        UInt32,
        UnsafeMutableRawPointer?
    ) -> Int32 = { data, size, fingerprint, fsize, userdata in
        guard let data = data,
              let userdata = userdata,
              let fingerprint = fingerprint else {
            return 0
        }
        
        let context = Unmanaged<CallbackContext>.fromOpaque(userdata).takeUnretainedValue()
        
        if context.bluetoothManager?.isRetrievingLogs == false {
            logInfo("🛑 Download cancelled")
            return 0
        }
        
        // 1. Capture Device Info (Once)
        if !context.hasDeviceInfo,
           let devicePtr = context.devicePtr,
           devicePtr.pointee.have_devinfo != 0 {
            context.deviceSerial = String(format: "%08x", devicePtr.pointee.devinfo.serial)
            context.detectedModel = devicePtr.pointee.devinfo.model
            
            if let desc = devicePtr.pointee.descriptor {
                context.detectedFamily = dc_descriptor_get_type(desc)
            }
            
            logInfo("📱 Detected Device Hardware - Family: \(context.detectedFamily), Model: \(context.detectedModel)")
            
            // Update storage if hardware tells us something different (e.g. 13 vs 9)
            DeviceConfiguration.updateDeviceConfigurationFromHardware(
                deviceAddress: context.deviceUUID,
                deviceDataPtr: devicePtr,
                deviceName: context.deviceName
            )
            
            context.hasDeviceInfo = true
        }
        
        let fingerprintData = Data(bytes: fingerprint, count: Int(fsize))
        
        if context.logCount == 1 {
            context.lastFingerprint = fingerprintData
        }
        
        if let storedFingerprint = context.storedFingerprint, storedFingerprint == fingerprintData {
            logInfo("✨ Found matching fingerprint - download complete")
            return 0
        }
        
        // 4. Parse & Store Dive
        var familyToUse: dc_family_t
        var modelToUse: UInt32
        
        // PRIORITY ORDER FOR MODEL SELECTION:
        // 1. Hardware Detection (Most reliable if available)
        // 2. Stored/Forced Configuration (What the user selected)
        // 3. Name-based Detection (Fallback)
        
        if context.detectedModel != 0 {
            familyToUse = context.detectedFamily
            modelToUse = context.detectedModel
        } else if let stored = DeviceStorage.shared.getStoredDevice(uuid: context.deviceUUID) {
            familyToUse = stored.family.asDCFamily
            modelToUse = stored.model
            logInfo("ℹ️ Using Stored Configuration - Model: \(modelToUse)")
        } else if let deviceInfo = DeviceConfiguration.fromName(context.deviceName) {
            familyToUse = deviceInfo.family.asDCFamily
            modelToUse = deviceInfo.model
        } else {
            logError("❌ Unknown device configuration")
            return 0
        }

        guard let deviceFamily = DeviceConfiguration.DeviceFamily(dcFamily: familyToUse) else {
            logError("❌ Failed to map C family ID \(familyToUse) to Swift DeviceFamily enum")
            return 0
        }

        do {
            let diveData = try GenericParser.parseDiveData(
                family: deviceFamily,
                model: modelToUse, 
                diveNumber: context.logCount,
                diveData: data,
                dataSize: Int(size)
            )
            
            DispatchQueue.main.async {
                context.viewModel.appendDives([diveData])
                context.viewModel.updateProgress(count: context.logCount)
            }
            
            context.hasNewDives = true
            context.logCount += 1
            return 1  
        } catch {
            logError("❌ Failed to parse dive #\(context.logCount): \(error)")
            return 1 
        }
    }
    
    #if os(iOS)
    private static var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    #endif
    
    private static let fingerprintLookup: @convention(c) (
        UnsafeMutableRawPointer?, 
        UnsafePointer<CChar>?, 
        UnsafePointer<CChar>?, 
        UnsafeMutablePointer<Int>?
    ) -> UnsafeMutablePointer<UInt8>? = { context, deviceType, serial, size in
        guard let context = context, let size = size else { return nil }
        
        let viewModel = Unmanaged<DiveDataViewModel>.fromOpaque(context).takeUnretainedValue()
        
        if let serialStr = serial.map({ String(cString: $0) }),
           let typeStr = deviceType.map({ String(cString: $0) }) {
             let cleanName = DeviceConfiguration.getDeviceDisplayName(from: typeStr)
             if let fingerprint = viewModel.getFingerprint(forDeviceType: cleanName, serial: serialStr) {
                logInfo("✅ Found stored fingerprint")
                size.pointee = fingerprint.count
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: fingerprint.count)
                fingerprint.copyBytes(to: buffer, count: fingerprint.count)
                return buffer
            }
        }
        return nil
    }
    
    private static var currentContext: CallbackContext?
    
    public static func retrieveDiveLogs(
            from devicePtr: UnsafeMutablePointer<device_data_t>,
            device: CBPeripheral,
            viewModel: DiveDataViewModel,
            bluetoothManager: CoreBluetoothManager,
            onProgress: ((Int, Int) -> Void)? = nil,
            completion: @escaping (Bool) -> Void
        ) {
            let retrievalQueue = DispatchQueue(label: "com.libdcswift.retrieval", qos: .userInitiated)
            
            retrievalQueue.async {
                DispatchQueue.main.async { viewModel.resetProgress() }
                
                guard let dcDevice = devicePtr.pointee.device else {
                    DispatchQueue.main.async {
                        viewModel.setDetailedError("No device connection found", status: DC_STATUS_IO)
                        completion(false)
                    }
                    return
                }

                let deviceName = device.name ?? "Unknown Device"

                var storedFingerprint: Data? = nil
                if devicePtr.pointee.have_devinfo != 0 {
                    let serial = String(format: "%08x", devicePtr.pointee.devinfo.serial)
                    storedFingerprint = viewModel.getFingerprint(forDeviceType: deviceName, serial: serial)
                }

                if storedFingerprint == nil {
                    _ = dc_device_set_fingerprint(dcDevice, nil, 0)
                }

                let context = CallbackContext(
                    viewModel: viewModel,
                    deviceName: deviceName,
                    deviceUUID: device.identifier.uuidString,
                    storedFingerprint: storedFingerprint,
                    bluetoothManager: bluetoothManager
                )
                context.devicePtr = devicePtr
                
                let contextPtr = UnsafeMutableRawPointer(Unmanaged.passRetained(context).toOpaque())
                
                let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
                    if devicePtr.pointee.have_progress != 0 {
                        onProgress?(Int(devicePtr.pointee.progress.current), Int(devicePtr.pointee.progress.maximum))
                    }
                }
                
                devicePtr.pointee.fingerprint_context = Unmanaged.passUnretained(viewModel).toOpaque()
                devicePtr.pointee.lookup_fingerprint = fingerprintLookup
                
                logInfo("🔄 Starting dive enumeration (Force Full Download)...")

                // Retry logic for ISO14229 protocol errors (Peregrine TX and similar devices)
                // Note: For now, we do NOT retry because the device needs a full power cycle
                // between failed attempts. Simply calling dc_device_foreach again doesn't
                // reset the device's internal state properly.

                let enumStatus = dc_device_foreach(dcDevice, diveCallbackClosure, contextPtr)

                // Log the exact error code for debugging
                if enumStatus != DC_STATUS_SUCCESS {
                    let errorName: String
                    switch enumStatus {
                    case DC_STATUS_UNSUPPORTED: errorName = "UNSUPPORTED"
                    case DC_STATUS_INVALIDARGS: errorName = "INVALIDARGS"
                    case DC_STATUS_NOMEMORY: errorName = "NOMEMORY"
                    case DC_STATUS_NODEVICE: errorName = "NODEVICE"
                    case DC_STATUS_NOACCESS: errorName = "NOACCESS"
                    case DC_STATUS_IO: errorName = "IO"
                    case DC_STATUS_TIMEOUT: errorName = "TIMEOUT"
                    case DC_STATUS_PROTOCOL: errorName = "PROTOCOL"
                    case DC_STATUS_DATAFORMAT: errorName = "DATAFORMAT"
                    case DC_STATUS_CANCELLED: errorName = "CANCELLED"
                    default: errorName = "UNKNOWN(\(enumStatus))"
                    }
                    logError("❌ dc_device_foreach returned DC_STATUS_\(errorName) (code: \(enumStatus))")
                    logError("   Context: hasNewDives=\(context.hasNewDives), logCount=\(context.logCount)")
                }

                progressTimer.invalidate()

                DispatchQueue.main.async {
                    if enumStatus != DC_STATUS_SUCCESS {
                        viewModel.setDetailedError("Download incomplete - DC_STATUS error code: \(enumStatus)", status: enumStatus)
                        completion(false)
                    } else {
                        if context.hasNewDives, let lastFP = context.lastFingerprint, let serial = context.deviceSerial {
                            viewModel.saveFingerprint(lastFP, deviceType: context.deviceName, serial: serial)
                            viewModel.updateProgress(.completed)
                        } else if context.storedFingerprint != nil {
                            viewModel.updateProgress(.noNewDives)
                        } else {
                            viewModel.updateProgress(.completed)
                        }
                        completion(true)
                    }
                    
                    context.isCompleted = true
                    Unmanaged<CallbackContext>.fromOpaque(contextPtr).release()
                    
                    #if os(iOS)
                    endBackgroundTask()
                    #endif
                }
                
                currentContext = context
            }
        }
    
    #if os(iOS)
    private static func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    #endif
    
    public static func getCurrentContext() -> CallbackContext? {
        return currentContext
    }
}
