import XCTest
import Foundation
import CoreBluetooth
import Clibdivecomputer
import LibDCBridge

@testable import LibDCSwift

// MARK: - DeviceFamily Mapping Tests

/// Intent: DeviceFamily is the Swift-friendly representation of libdivecomputer's
/// dc_family_t enum. Every DeviceFamily case MUST map to exactly one dc_family_t
/// and back again — if this round-trip breaks, the entire device identification
/// pipeline silently uses the wrong protocol to talk to hardware.

class DeviceConfigurationTests: XCTestCase {

    func testDeviceFamilyRoundTrip() {
        for family in DeviceConfiguration.DeviceFamily.allCases {
            let dcFamily = family.asDCFamily
            let recovered = DeviceConfiguration.DeviceFamily(dcFamily: dcFamily)
            XCTAssertEqual(recovered, family, "Round-trip failed for \(family)")
        }
    }

    // MARK: - Descriptor Lookup (fromName)

    /// Intent: When the Diver app scans BLE and sees an advertised name like "Perdix 2",
    /// fromName() must resolve it to the correct family and model so the right protocol
    /// is used to communicate with the hardware. A wrong mapping = garbled data or no connection.

    func testFromNameIdentifiesKnownDevice() {
        let result = DeviceConfiguration.fromName("Perdix 2")
        XCTAssertNotNil(result, "Should identify 'Perdix 2' as a known dive computer")
        XCTAssertEqual(result?.family, .shearwaterPetrel)
    }

    func testFromNameRejectsUnknownDevice() {
        let result = DeviceConfiguration.fromName("My iPhone")
        XCTAssertNil(result, "Should return nil for non-dive-computer names")
    }

    // MARK: - Display Name

    /// Intent: The UI needs a human-readable "Vendor Product" string for display.
    /// For known devices, this comes from libdivecomputer's descriptor database.
    /// For unknown names, it falls back to the raw input — never nil, never empty.

    func testGetDeviceDisplayNameKnownDevice() {
        let displayName = DeviceConfiguration.getDeviceDisplayName(from: "Perdix 2")
        XCTAssertEqual(displayName, "Shearwater Perdix 2")
    }

    func testGetDeviceDisplayNameUnknownFallsBackToInput() {
        let displayName = DeviceConfiguration.getDeviceDisplayName(from: "UnknownGadget")
        XCTAssertEqual(displayName, "UnknownGadget", "Unknown names should pass through unchanged")
    }

    // MARK: - Parser Context Lifecycle

    /// Intent: The parser context wraps a libdivecomputer dc_context_t.
    /// It must be set up before any parsing can occur, and cleaned up to avoid leaks.
    /// These operations must be safe to call in any order and be idempotent.

    func testCreateParserWithoutContextReturnsNil() {
        DeviceConfiguration.cleanupContext()
        let parser = DeviceConfiguration.createParser(
            family: DC_FAMILY_SHEARWATER_PETREL,
            model: 11,
            data: Data([0x00])
        )
        XCTAssertNil(parser, "createParser should return nil when no context is set up")
    }

    func testSetupContextIsIdempotent() {
        DeviceConfiguration.setupContext()
        DeviceConfiguration.setupContext()
        // Should not crash or leak — just a no-op on the second call
        DeviceConfiguration.cleanupContext()
    }

    func testCleanupWithoutSetupIsHarmless() {
        DeviceConfiguration.cleanupContext()
        DeviceConfiguration.cleanupContext()
        // Should not crash — just a no-op
    }

    func testSetupCleanupCycle() {
        DeviceConfiguration.setupContext()
        DeviceConfiguration.cleanupContext()
        DeviceConfiguration.setupContext()
        // Second setup after cleanup should work
        DeviceConfiguration.cleanupContext()
    }

    func testConcurrentContextAccessDoesNotCrash() {
        let iterations = 100
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "context-stress", attributes: .concurrent)

        for _ in 0..<iterations {
            group.enter()
            queue.async {
                DeviceConfiguration.setupContext()
                DeviceConfiguration.cleanupContext()
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 5)
        XCTAssertEqual(result, .success, "Concurrent context access should not deadlock")
        DeviceConfiguration.cleanupContext()
    }

    // MARK: - Supported Models Consistency

    /// Intent: supportedModels is the list of devices the app advertises as supported.
    /// Every entry must resolve to a valid libdivecomputer descriptor — if it doesn't,
    /// the app promises support it can't deliver.

    func testAllSupportedModelsResolveToDescriptors() {
        for model in DeviceConfiguration.supportedModels {
            var descriptor: OpaquePointer?
            let rc = find_descriptor_by_model(
                &descriptor,
                model.family.asDCFamily,
                model.modelID
            )
            XCTAssertEqual(rc, DC_STATUS_SUCCESS,
                "\(model.name) (family: \(model.family), modelID: \(model.modelID)) has no matching libdivecomputer descriptor")
            if let desc = descriptor {
                dc_descriptor_free(desc)
            }
        }
    }

    func testSupportedModelsIsNotEmpty() {
        XCTAssertFalse(DeviceConfiguration.supportedModels.isEmpty,
            "The library must list at least one supported dive computer")
    }

    /// Intent: Every model must have a non-empty human-readable name for UI display.
    func testSupportedModelsHaveNames() {
        for model in DeviceConfiguration.supportedModels {
            XCTAssertFalse(model.name.isEmpty, "Model with family \(model.family) has no name")
        }
    }

    // MARK: - Known Service UUIDs

    /// Intent: knownServiceUUIDs drives BLE scanning — only peripherals advertising
    /// these services are considered dive computer candidates. The list must be
    /// non-empty and contain valid UUIDs.

    func testKnownServiceUUIDsIsNotEmpty() {
        XCTAssertFalse(DeviceConfiguration.knownServiceUUIDs.isEmpty,
            "Must have at least one service UUID for BLE scanning")
    }

    /// Intent: Each UUID string should be a full 128-bit UUID (not a short 16-bit one),
    /// since dive computer manufacturers use custom services, not Bluetooth SIG assigned ones.
    func testKnownServiceUUIDsAreFullLength() {
        for uuid in DeviceConfiguration.knownServiceUUIDs {
            // CBUUID.uuidString for 128-bit UUIDs is 36 chars (8-4-4-4-12 with dashes)
            XCTAssertEqual(uuid.uuidString.count, 36,
                "UUID \(uuid.uuidString) should be a full 128-bit UUID, not a short 16-bit one")
        }
    }
}

