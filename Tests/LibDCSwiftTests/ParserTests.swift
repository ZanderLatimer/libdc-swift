import XCTest
import Foundation
import Clibdivecomputer
import LibDCBridge

@testable import LibDCSwift

// MARK: - GenericParser Error Handling Tests

/// Intent: The parser is called with raw bytes from a dive computer.
/// Bad data must produce typed ParserError throws — never crashes, never
/// silently corrupt DiveData. The Diver app catches these to show the user
/// a meaningful error message.

class GenericParserErrorTests: XCTestCase {

    /// Intent: If the parser can't be created for a given family/model/data
    /// combination, it must throw parserCreationFailed — not crash.
    func testParserCreationFailsGracefullyWithGarbageData() {
        let garbage = Data([0xDE, 0xAD, 0xBE, 0xEF])

        XCTAssertThrowsError(
            try GenericParser.parseDiveData(
                family: .shearwaterPetrel,
                model: 11,
                diveNumber: 1,
                diveData: [UInt8](garbage),
                dataSize: garbage.count,
                context: nil
            )
        ) { error in
            guard let parserError = error as? GenericParser.ParserError else {
                XCTFail("Expected ParserError, got \(type(of: error))")
                return
            }
            // Should fail at parser creation (no context) or datetime retrieval
            switch parserError {
            case .parserCreationFailed, .datetimeRetrievalFailed:
                break // Expected
            default:
                XCTFail("Expected parserCreationFailed or datetimeRetrievalFailed, got \(parserError)")
            }
        }
    }

    /// Intent: Empty data is not a valid dive — must throw, not crash.
    func testParserRejectsEmptyData() {
        let empty = Data()

        XCTAssertThrowsError(
            try GenericParser.parseDiveData(
                family: .shearwaterPetrel,
                model: 11,
                diveNumber: 1,
                diveData: [UInt8](empty),
                dataSize: 0,
                context: nil
            )
        )
    }
}
