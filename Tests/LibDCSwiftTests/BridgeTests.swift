import XCTest
import Foundation
import Clibdivecomputer
import LibDCBridge

@testable import LibDCSwift

// MARK: - C Bridge Descriptor Tests

/// Intent: The C descriptor functions are the foundation of device identification.
/// find_descriptor_by_model maps (family, model) → descriptor.
/// find_descriptor_by_name maps BLE advertised name → descriptor.
/// These must resolve known devices correctly, reject unknown ones gracefully,
/// and produce descriptors that can be safely freed without leaking.

class CBridgeDescriptorTests: XCTestCase {

    func testFindDescriptorByModelKnownDevice() {
        var descriptor: OpaquePointer?
        let rc = find_descriptor_by_model(
            &descriptor,
            DC_FAMILY_SHEARWATER_PETREL,
            11 // Perdix 2
        )
        XCTAssertEqual(rc, DC_STATUS_SUCCESS)
        XCTAssertNotNil(descriptor)
        dc_descriptor_free(descriptor)
    }

    func testFindDescriptorByModelUnknownReturnsUnsupported() {
        var descriptor: OpaquePointer?
        let rc = find_descriptor_by_model(&descriptor, DC_FAMILY_NULL, 9999)
        XCTAssertEqual(rc, DC_STATUS_UNSUPPORTED)
        XCTAssertNil(descriptor)
    }

    func testFindDescriptorByNameKnownDevice() {
        var descriptor: OpaquePointer?
        let rc = find_descriptor_by_name(&descriptor, "Perdix 2")
        XCTAssertEqual(rc, DC_STATUS_SUCCESS)
        XCTAssertNotNil(descriptor)

        // Verify it resolved to the right vendor
        if let desc = descriptor {
            let vendor = String(cString: dc_descriptor_get_vendor(desc))
            XCTAssertEqual(vendor, "Shearwater")
        }
        dc_descriptor_free(descriptor)
    }

    /// NOTE: find_descriptor_by_name has a permissive fallback that uses
    /// libdivecomputer's dc_descriptor_filter(). Names containing substrings
    /// of known devices (e.g. "G2", "S1", "Computer") may false-positive.
    /// Use a name with no overlap to test the rejection path.
    func testFindDescriptorByNameUnknownReturnsUnsupported() {
        var descriptor: OpaquePointer?
        let rc = find_descriptor_by_name(&descriptor, "XYZZY_9876")
        XCTAssertEqual(rc, DC_STATUS_UNSUPPORTED)
    }

    /// Intent: The name_patterns table uses prefix matching for Cressi devices
    /// (e.g. "CARESIO_" prefix → Cressi Cartesio). This tests that the matching
    /// modes work as expected for real-world BLE names.
    func testFindDescriptorByNamePrefixMatch() {
        var descriptor: OpaquePointer?
        let rc = find_descriptor_by_name(&descriptor, "CARESIO_12345")
        XCTAssertEqual(rc, DC_STATUS_SUCCESS, "Prefix match should find Cressi Cartesio")
        if let desc = descriptor {
            let vendor = String(cString: dc_descriptor_get_vendor(desc))
            XCTAssertEqual(vendor, "Cressi")
        }
        dc_descriptor_free(descriptor)
    }
}

// MARK: - BLE Bridge Null-Safety Tests

/// Intent: The BLE bridge functions are called by libdivecomputer's C iostream layer.
/// C code cannot handle Swift exceptions or nil — it only understands error codes.
/// These functions MUST return appropriate dc_status_t error codes (never crash)
/// when called with invalid state: no manager injected, null pointers, etc.

final class BLEBridgeNullSafetyTests: XCTestCase {

    // No BLE manager is injected in the test process, so all tests below
    // exercise the "no manager" defensive paths.

    func testCreateBLEObjectWithoutManagerReturnsNull() {
        let obj = createBLEObject()
        XCTAssertNil(obj, "Should return NULL when no manager is injected")
    }

    func testFreeBLEObjectNullIsNoOp() {
        // Should not crash
        freeBLEObject(nil)
    }

    func testBleReadWithoutManagerReturnsError() {
        var buffer = [UInt8](repeating: 0, count: 64)
        var actual: Int = 0
        let rc = ble_read(nil, &buffer, 64, &actual)
        XCTAssertEqual(rc, DC_STATUS_INVALIDARGS)
    }

    func testBleWriteWithoutManagerReturnsError() {
        let data: [UInt8] = [0x01, 0x02]
        var actual: Int = 0
        let rc = ble_write(nil, data, 2, &actual)
        XCTAssertEqual(rc, DC_STATUS_INVALIDARGS)
    }

    func testBleCloseWithoutManagerIsHarmless() {
        let rc = ble_close(nil)
        XCTAssertEqual(rc, DC_STATUS_SUCCESS, "Closing with no manager should succeed (no-op)")
    }
}
