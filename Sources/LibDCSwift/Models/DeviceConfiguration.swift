import Foundation
import CoreBluetooth
import Clibdivecomputer
import LibDCBridge

public enum DeviceConfiguration {

    // MARK: - Device Family

    /// Represents the family of dive computers that support BLE communication.
    public enum DeviceFamily: String, Codable, CaseIterable {
        case suuntoEonSteel
        case shearwaterPetrel
        case hwOstc3
        case uwatecSmart
        case oceanicAtom2
        case pelagicI330R
        case maresIconHD
        case deepsixExcursion
        case deepbluCosmiq
        case oceansS1
        case mcleanExtreme
        case divesoftFreedom
        case cressiGoa
        case diveSystem

        /// Converts the Swift enum to libdivecomputer's dc_family_t type.
        public var asDCFamily: dc_family_t {
            switch self {
            case .suuntoEonSteel: return DC_FAMILY_SUUNTO_EONSTEEL
            case .shearwaterPetrel: return DC_FAMILY_SHEARWATER_PETREL
            case .hwOstc3: return DC_FAMILY_HW_OSTC3
            case .uwatecSmart: return DC_FAMILY_UWATEC_SMART
            case .oceanicAtom2: return DC_FAMILY_OCEANIC_ATOM2
            case .pelagicI330R: return DC_FAMILY_PELAGIC_I330R
            case .maresIconHD: return DC_FAMILY_MARES_ICONHD
            case .deepsixExcursion: return DC_FAMILY_DEEPSIX_EXCURSION
            case .deepbluCosmiq: return DC_FAMILY_DEEPBLU_COSMIQ
            case .oceansS1: return DC_FAMILY_OCEANS_S1
            case .mcleanExtreme: return DC_FAMILY_MCLEAN_EXTREME
            case .divesoftFreedom: return DC_FAMILY_DIVESOFT_FREEDOM
            case .cressiGoa: return DC_FAMILY_CRESSI_GOA
            case .diveSystem: return DC_FAMILY_DIVESYSTEM_IDIVE
            }
        }

        /// Creates a DeviceFamily instance from libdivecomputer's dc_family_t type.
        public init?(dcFamily: dc_family_t) {
            switch dcFamily {
            case DC_FAMILY_SUUNTO_EONSTEEL: self = .suuntoEonSteel
            case DC_FAMILY_SHEARWATER_PETREL: self = .shearwaterPetrel
            case DC_FAMILY_HW_OSTC3: self = .hwOstc3
            case DC_FAMILY_UWATEC_SMART: self = .uwatecSmart
            case DC_FAMILY_OCEANIC_ATOM2: self = .oceanicAtom2
            case DC_FAMILY_PELAGIC_I330R: self = .pelagicI330R
            case DC_FAMILY_MARES_ICONHD: self = .maresIconHD
            case DC_FAMILY_DEEPSIX_EXCURSION: self = .deepsixExcursion
            case DC_FAMILY_DEEPBLU_COSMIQ: self = .deepbluCosmiq
            case DC_FAMILY_OCEANS_S1: self = .oceansS1
            case DC_FAMILY_MCLEAN_EXTREME: self = .mcleanExtreme
            case DC_FAMILY_DIVESOFT_FREEDOM: self = .divesoftFreedom
            case DC_FAMILY_CRESSI_GOA: self = .cressiGoa
            case DC_FAMILY_DIVESYSTEM_IDIVE: self = .diveSystem
            default: return nil
            }
        }
    }

    // MARK: - Supported Models

    public struct ComputerModel: Identifiable, Hashable {
        public let id = UUID()
        public let name: String
        public let family: DeviceFamily
        public let modelID: UInt32
        
        public static func == (lhs: ComputerModel, rhs: ComputerModel) -> Bool {
            lhs.family == rhs.family && lhs.modelID == rhs.modelID
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(family)
            hasher.combine(modelID)
        }
    }

    public static let supportedModels: [ComputerModel] = [
        // Shearwater
        ComputerModel(name: "Shearwater Peregrine", family: .shearwaterPetrel, modelID: 9),
        ComputerModel(name: "Shearwater Peregrine TX", family: .shearwaterPetrel, modelID: 13),
        ComputerModel(name: "Shearwater Petrel", family: .shearwaterPetrel, modelID: 3),
        ComputerModel(name: "Shearwater Petrel 2", family: .shearwaterPetrel, modelID: 3),
        ComputerModel(name: "Shearwater Petrel 3", family: .shearwaterPetrel, modelID: 10),
        ComputerModel(name: "Shearwater Perdix", family: .shearwaterPetrel, modelID: 5),
        ComputerModel(name: "Shearwater Perdix AI", family: .shearwaterPetrel, modelID: 6),
        ComputerModel(name: "Shearwater Perdix 2", family: .shearwaterPetrel, modelID: 11),
        ComputerModel(name: "Shearwater Teric", family: .shearwaterPetrel, modelID: 8),
        ComputerModel(name: "Shearwater Tern", family: .shearwaterPetrel, modelID: 12),
        ComputerModel(name: "Shearwater NERD 2", family: .shearwaterPetrel, modelID: 7),
        // Suunto
        ComputerModel(name: "Suunto EON Steel", family: .suuntoEonSteel, modelID: 0),
        ComputerModel(name: "Suunto EON Core", family: .suuntoEonSteel, modelID: 1),
        ComputerModel(name: "Suunto D5", family: .suuntoEonSteel, modelID: 2),
        ComputerModel(name: "Suunto EON Steel Black", family: .suuntoEonSteel, modelID: 3),
        // Scubapro / Uwatec
        ComputerModel(name: "Scubapro G2", family: .uwatecSmart, modelID: 0x32),
        ComputerModel(name: "Scubapro G2 TEK", family: .uwatecSmart, modelID: 0x31),
        ComputerModel(name: "Scubapro G2 Console", family: .uwatecSmart, modelID: 0x32),
        ComputerModel(name: "Scubapro G2 HUD", family: .uwatecSmart, modelID: 0x42),
        ComputerModel(name: "Scubapro G3", family: .uwatecSmart, modelID: 0x34),
        ComputerModel(name: "Scubapro Aladin A1", family: .uwatecSmart, modelID: 0x25),
        ComputerModel(name: "Scubapro Aladin A2", family: .uwatecSmart, modelID: 0x28),
        ComputerModel(name: "Scubapro Luna 2.0", family: .uwatecSmart, modelID: 0x51),
        ComputerModel(name: "Scubapro Luna 2.0 AI", family: .uwatecSmart, modelID: 0x50),
        // Heinrichs Weikamp
        ComputerModel(name: "Heinrichs Weikamp OSTC 3", family: .hwOstc3, modelID: 0x0A),
        ComputerModel(name: "Heinrichs Weikamp OSTC 4", family: .hwOstc3, modelID: 0x3B),
        ComputerModel(name: "Heinrichs Weikamp OSTC Plus", family: .hwOstc3, modelID: 0x13),
        ComputerModel(name: "Heinrichs Weikamp OSTC 2", family: .hwOstc3, modelID: 0x11),
        ComputerModel(name: "Heinrichs Weikamp OSTC Sport", family: .hwOstc3, modelID: 0x12),
        ComputerModel(name: "Heinrichs Weikamp OSTC 2 TR", family: .hwOstc3, modelID: 0x33),
        // Oceanic / Aeris / Sherwood / Hollis
        ComputerModel(name: "Oceanic Geo 4.0", family: .oceanicAtom2, modelID: 0x4653),
        ComputerModel(name: "Oceanic Veo 4.0", family: .oceanicAtom2, modelID: 0x4654),
        ComputerModel(name: "Oceanic Pro Plus 4", family: .oceanicAtom2, modelID: 0x4656),
        ComputerModel(name: "Oceanic Atom 3.1", family: .oceanicAtom2, modelID: 0x4456),
        ComputerModel(name: "Oceanic Geo Air", family: .oceanicAtom2, modelID: 0x474B),
        ComputerModel(name: "Aqualung i770R", family: .oceanicAtom2, modelID: 0x4651),
        ComputerModel(name: "Aqualung i550C", family: .oceanicAtom2, modelID: 0x4652),
        ComputerModel(name: "Aqualung i300C", family: .oceanicAtom2, modelID: 0x4648),
        ComputerModel(name: "Aqualung i200C", family: .oceanicAtom2, modelID: 0x4649),
        ComputerModel(name: "Sherwood Wisdom 3", family: .oceanicAtom2, modelID: 0x4458),
        ComputerModel(name: "Sherwood Sage", family: .oceanicAtom2, modelID: 0x4647),
        
        // Pelagic Pressure Systems (Oceanic, Aqua Lung, Sherwood, Tusa)
        ComputerModel(name: "Aqualung i330R", family: .pelagicI330R, modelID: 0x4744),
        ComputerModel(name: "Aqualung i330R Console", family: .pelagicI330R, modelID: 0x474D),
        ComputerModel(name: "Apeks DSX", family: .pelagicI330R, modelID: 0x4741),
        // Mares
        ComputerModel(name: "Mares Icon HD", family: .maresIconHD, modelID: 0x14),
        ComputerModel(name: "Mares Puck Pro", family: .maresIconHD, modelID: 0x18),
        ComputerModel(name: "Mares Smart", family: .maresIconHD, modelID: 0x000010),
        ComputerModel(name: "Mares Quad", family: .maresIconHD, modelID: 0x29),
        ComputerModel(name: "Mares Quad Air", family: .maresIconHD, modelID: 0x23),
        ComputerModel(name: "Mares Smart Air", family: .maresIconHD, modelID: 0x24),
        ComputerModel(name: "Mares Genius", family: .maresIconHD, modelID: 0x1C),
        ComputerModel(name: "Mares Puck 4", family: .maresIconHD, modelID: 0x35),
        // DeepSix
        ComputerModel(name: "Deep Six Excursion", family: .deepsixExcursion, modelID: 0),
        // Deepblu
        ComputerModel(name: "Deepblu Cosmiq+", family: .deepbluCosmiq, modelID: 0),
        // Oceans
        ComputerModel(name: "Oceans S1", family: .oceansS1, modelID: 0),
        // McLean
        ComputerModel(name: "McLean Extreme", family: .mcleanExtreme, modelID: 0),
        // Divesoft
        ComputerModel(name: "Divesoft Freedom", family: .divesoftFreedom, modelID: 19),
        ComputerModel(name: "Divesoft Liberty", family: .divesoftFreedom, modelID: 10),
        // Cressi
        ComputerModel(name: "Cressi Goa", family: .cressiGoa, modelID: 2),
        ComputerModel(name: "Cressi Cartesio", family: .cressiGoa, modelID: 1),
        ComputerModel(name: "Cressi Leonardo 2.0", family: .cressiGoa, modelID: 3),
        ComputerModel(name: "Cressi Donatello", family: .cressiGoa, modelID: 4),
        // DiveSystem / Ratio
        ComputerModel(name: "DiveSystem iDive Easy", family: .diveSystem, modelID: 0x09),
        ComputerModel(name: "DiveSystem iDive Free", family: .diveSystem, modelID: 0x08),
        ComputerModel(name: "DiveSystem iDive Deep", family: .diveSystem, modelID: 0x0B),
        ComputerModel(name: "Ratio iDive 2 Easy", family: .diveSystem, modelID: 0x82),
        ComputerModel(name: "Ratio iDive 2 Free", family: .diveSystem, modelID: 0x80),
        ComputerModel(name: "Ratio iDive 2 Deep", family: .diveSystem, modelID: 0x84),
        ComputerModel(name: "Ratio iDive Color Easy", family: .diveSystem, modelID: 0x52),
        ComputerModel(name: "Ratio iDive Color Free", family: .diveSystem, modelID: 0x50),
        ComputerModel(name: "Ratio iDive Color Deep", family: .diveSystem, modelID: 0x54),
    ]

    // MARK: - Known BLE Service UUIDs

    public static let knownServiceUUIDs: [CBUUID] = [
        CBUUID(string: "0000fefb-0000-1000-8000-00805f9b34fb"), // Heinrichs-Weikamp Telit/Stollmann
        CBUUID(string: "2456e1b9-26e2-8f83-e744-f34f01e9d701"), // Heinrichs-Weikamp U-Blox
        CBUUID(string: "544e326b-5b72-c6b0-1c46-41c1bc448118"), // Mares BlueLink Pro
        CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e"), // Nordic Semi UART
        CBUUID(string: "98ae7120-e62e-11e3-badd-0002a5d5c51b"), // Suunto EON Steel/Core
        CBUUID(string: "cb3c4555-d670-4670-bc20-b61dbc851e9a"), // Pelagic i770R/i200C
        CBUUID(string: "ca7b0001-f785-4c38-b599-c7c5fbadb034"), // Pelagic i330R/DSX
        CBUUID(string: "fdcdeaaa-295d-470e-bf15-04217b7aa0a0"), // ScubaPro G2/G3
        CBUUID(string: "fe25c237-0ece-443c-b0aa-e02033e7029d"), // Shearwater Perdix/Teric
        CBUUID(string: "0000fcef-0000-1000-8000-00805f9b34fb")  // Divesoft Freedom
    ]

    // MARK: - Descriptor Lookup

    /// Identifies a BLE device from its advertised name using libdivecomputer's descriptor system.
    public static func fromName(_ name: String) -> (family: DeviceFamily, model: UInt32)? {
        var descriptor: OpaquePointer?
        let rc = find_descriptor_by_name(&descriptor, name)

        guard rc == DC_STATUS_SUCCESS, let desc = descriptor else { return nil }

        let family = dc_descriptor_get_type(desc)
        let model = dc_descriptor_get_model(desc)

        guard let deviceFamily = DeviceFamily(dcFamily: family) else {
            dc_descriptor_free(desc)
            return nil
        }

        dc_descriptor_free(desc)
        return (deviceFamily, model)
    }

    /// Returns a human-readable "Vendor Product" display name for a device.
    public static func getDeviceDisplayName(from name: String) -> String {
        guard let cString = get_formatted_device_name(name) else { return name }
        defer { free(cString) }
        return String(cString: cString)
    }

    // MARK: - Device Opening

    /// Opens a BLE connection to a dive computer via libdivecomputer.
    ///
    /// The caller must have already injected a BLE manager via `setBLEManager()`
    /// and ensured the peripheral is connected at the CoreBluetooth level.
    ///
    /// - Returns: An allocated `device_data_t` pointer on success, or `nil` on failure.
    ///   The caller is responsible for eventually closing and deallocating it.
    public static func openDevice(
        name: String,
        deviceAddress: String,
        family: dc_family_t,
        model: UInt32
    ) -> UnsafeMutablePointer<device_data_t>? {
        var deviceData: UnsafeMutablePointer<device_data_t>?

        let status = open_ble_device_with_identification(
            &deviceData,
            name,
            deviceAddress,
            family,
            model
        )

        guard status == DC_STATUS_SUCCESS, let data = deviceData else {
            return nil
        }

        return data
    }

    // MARK: - Parser Context

    private static let contextLock = NSLock()
    private static var context: OpaquePointer?
    
    public static func setupContext() {
        contextLock.lock()
        defer { contextLock.unlock() }
        guard context == nil else { return }
        _ = dc_context_new(&context)
    }
    
    public static func cleanupContext() {
        contextLock.lock()
        defer { contextLock.unlock() }
        guard let ctx = context else { return }
        dc_context_free(ctx)
        context = nil
    }
    
    public static func createParser(family: dc_family_t, model: UInt32, data: Data) -> OpaquePointer? {
        contextLock.lock()
        let ctx = context
        contextLock.unlock()
        guard let ctx else { return nil }

        var parser: OpaquePointer?
        let rc = data.withUnsafeBytes { buffer -> dc_status_t in
            guard let baseAddress = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return DC_STATUS_INVALIDARGS
            }
            return create_parser_for_device(
                &parser,
                ctx,
                family,
                model,
                baseAddress,
                data.count
            )
        }

        guard rc == DC_STATUS_SUCCESS else { return nil }
        return parser
    }
}