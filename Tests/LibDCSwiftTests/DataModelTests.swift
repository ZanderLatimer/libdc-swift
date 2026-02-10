import XCTest
import Foundation
import Clibdivecomputer

@testable import LibDCSwift

// MARK: - DiveEvent Tests

/// Intent: DiveEvent represents safety-critical occurrences during a dive.
/// Each case must be distinguishable (Hashable), and the description must
/// communicate the event clearly to the user. Associated values like
/// safetyStop(mandatory:) must preserve their semantics.

class DiveEventTests: XCTestCase {

    func testSafetyStopMandatoryIsDistinct() {
        let voluntary = DiveEvent.safetyStop(mandatory: false)
        let mandatory = DiveEvent.safetyStop(mandatory: true)
        XCTAssertNotEqual(voluntary, mandatory,
            "Mandatory and voluntary safety stops are different events with different implications")
    }

    func testAllEventsAreHashable() {
        let events: Set<DiveEvent> = [
            .ascent, .violation, .decoStop, .gasChange,
            .bookmark, .safetyStop(mandatory: false),
            .safetyStop(mandatory: true), .ceiling, .po2, .deepStop
        ]
        XCTAssertEqual(events.count, 10, "All event cases should be distinct in a Set")
    }

    func testEventDescriptionsAreNonEmpty() {
        let events: [DiveEvent] = [
            .ascent, .violation, .decoStop, .gasChange,
            .bookmark, .safetyStop(mandatory: false),
            .safetyStop(mandatory: true), .ceiling, .po2, .deepStop
        ]
        for event in events {
            XCTAssertFalse(event.description.isEmpty, "\(event) should have a description")
        }
    }
}

// MARK: - DiveData Tests

/// Intent: DiveData is the primary output of the parsing pipeline.
/// Each parsed dive gets a unique identity (for SwiftUI lists etc.),
/// and the initializer must faithfully store all provided fields.

final class DiveDataTests: XCTestCase {

    func testDiveDataHasUniqueIdentity() {
        let a = makeDiveData(number: 1)
        let b = makeDiveData(number: 2)
        XCTAssertNotEqual(a.id, b.id, "Each DiveData must have a unique ID")
    }

    func testDiveDataStoresAllFields() {
        let dive = makeDiveData(
            number: 42,
            maxDepth: 30.5,
            avgDepth: 18.2,
            divetime: 3600
        )
        XCTAssertEqual(dive.number, 42)
        XCTAssertEqual(dive.maxDepth, 30.5)
        XCTAssertEqual(dive.avgDepth, 18.2)
        XCTAssertEqual(dive.divetime, 3600)
    }

    // MARK: - Nested Type Tests

    /// Intent: Tank data represents physical gas cylinders. Every field matters
    /// for gas consumption calculations and safety planning.

    func testTankInitStoresAllFields() {
        let tank = DiveData.Tank(
            volume: 12.0,
            workingPressure: 232.0,
            beginPressure: 210.0,
            endPressure: 50.0,
            gasMix: 0,
            usage: .oxygen
        )
        XCTAssertEqual(tank.volume, 12.0)
        XCTAssertEqual(tank.workingPressure, 232.0)
        XCTAssertEqual(tank.beginPressure, 210.0)
        XCTAssertEqual(tank.endPressure, 50.0)
        XCTAssertEqual(tank.gasMix, 0)
    }

    /// Intent: Location data ties dives to physical places on a map.
    /// Altitude is optional since most dives are at sea level.

    func testLocationWithoutAltitude() {
        let loc = DiveData.Location(latitude: 27.5, longitude: -80.3)
        XCTAssertEqual(loc.latitude, 27.5)
        XCTAssertEqual(loc.longitude, -80.3)
        XCTAssertNil(loc.altitude)
    }

    func testLocationWithAltitude() {
        let loc = DiveData.Location(latitude: 47.0, longitude: 8.0, altitude: 430.0)
        XCTAssertEqual(loc.altitude, 430.0)
    }

    /// Intent: DecoModel captures the decompression algorithm the dive computer used.
    /// For Bühlmann, gradient factors are critical safety parameters.

    func testDecoModelBuhlmannWithGradientFactors() {
        let model = DiveData.DecoModel(type: .buhlmann, conservatism: 0, gfLow: 30, gfHigh: 70)
        XCTAssertEqual(model.gfLow, 30)
        XCTAssertEqual(model.gfHigh, 70)
    }

    func testDecoModelDescriptionIncludesGradientFactors() {
        let model = DiveData.DecoModel(type: .buhlmann, conservatism: 0, gfLow: 30, gfHigh: 70)
        XCTAssertTrue(model.description.contains("30"), "Description should include GF low")
        XCTAssertTrue(model.description.contains("70"), "Description should include GF high")
    }

    /// Intent: DiveMode tells the user what kind of diving was done.
    /// Each mode has distinct implications for gas planning and risk.

    func testDiveModeDescriptionsAreMeaningful() {
        let modes: [DiveData.DiveMode] = [
            .freedive, .gauge, .openCircuit, .closedCircuit, .semiClosedCircuit
        ]
        for mode in modes {
            XCTAssertFalse(mode.description.isEmpty)
            XCTAssertNotEqual(mode.description, "Unknown",
                "Every dive mode should have a specific description")
        }
    }
}

// MARK: - DiveProfilePoint Tests

/// Intent: Profile points are the time-series backbone of a dive profile chart.
/// The required fields (time, depth) are always present; everything else is optional
/// because different dive computers report different sensors.

final class DiveProfilePointTests: XCTestCase {

    func testMinimalProfilePoint() {
        let point = DiveProfilePoint(time: 60.0, depth: 15.0)
        XCTAssertEqual(point.time, 60.0)
        XCTAssertEqual(point.depth, 15.0)
        XCTAssertNil(point.temperature)
        XCTAssertNil(point.pressure)
        XCTAssertTrue(point.events.isEmpty)
    }

    func testProfilePointWithEvents() {
        let point = DiveProfilePoint(
            time: 120.0,
            depth: 25.0,
            events: [.ascent, .decoStop]
        )
        XCTAssertEqual(point.events.count, 2)
        XCTAssertTrue(point.events.contains(.ascent))
    }
}

// MARK: - SampleData Tests

/// Intent: SampleData is the mutable scratch pad used during parsing.
/// Its defaults must be sensible: zero depth, infinite temp bounds (so the
/// first real reading becomes the min/max), empty collections.

final class SampleDataTests: XCTestCase {

    func testDefaultsAreSensible() {
        let data = SampleData()
        XCTAssertEqual(data.depth, 0)
        XCTAssertEqual(data.time, 0)
        XCTAssertEqual(data.maxDepth, 0)
        XCTAssertEqual(data.tempMinimum, Double.infinity,
            "tempMinimum should start at +infinity so any real reading becomes the new minimum")
        XCTAssertEqual(data.tempMaximum, -Double.infinity,
            "tempMaximum should start at -infinity so any real reading becomes the new maximum")
        XCTAssertTrue(data.profile.isEmpty)
        XCTAssertTrue(data.gasMixes.isEmpty)
        XCTAssertTrue(data.pressure.isEmpty)
        XCTAssertTrue(data.tanks.isEmpty)
    }
}

// MARK: - GasMix Tests

/// Intent: Gas mixes define what the diver is breathing. Incorrect percentages
/// could lead to wrong gas consumption or decompression calculations in the app.
/// The model must faithfully store all components.

final class GasMixTests: XCTestCase {

    func testAirMixPercentages() {
        let air = GasMix(helium: 0.0, oxygen: 0.21, nitrogen: 0.79, usage: DC_USAGE_NONE)
        XCTAssertEqual(air.oxygen, 0.21, accuracy: 0.001)
        XCTAssertEqual(air.nitrogen, 0.79, accuracy: 0.001)
        XCTAssertEqual(air.helium, 0.0, accuracy: 0.001)
    }

    func testTrimixPercentages() {
        // 18/45 trimix: 18% O2, 45% He, 37% N2
        let trimix = GasMix(helium: 0.45, oxygen: 0.18, nitrogen: 0.37, usage: DC_USAGE_NONE)
        XCTAssertEqual(trimix.oxygen, 0.18, accuracy: 0.001)
        XCTAssertEqual(trimix.helium, 0.45, accuracy: 0.001)
        let total = trimix.oxygen + trimix.helium + trimix.nitrogen
        XCTAssertEqual(total, 1.0, accuracy: 0.001,
            "Gas percentages should sum to 1.0")
    }

    func testUsageFieldIsPreserved() {
        let decoO2 = GasMix(helium: 0.0, oxygen: 1.0, nitrogen: 0.0, usage: DC_USAGE_OXYGEN)
        XCTAssertEqual(decoO2.usage, DC_USAGE_OXYGEN)

        let diluent = GasMix(helium: 0.0, oxygen: 0.21, nitrogen: 0.79, usage: DC_USAGE_DILUENT)
        XCTAssertEqual(diluent.usage, DC_USAGE_DILUENT)
    }
}

// MARK: - Test Helpers

private func makeDiveData(
    number: Int = 1,
    maxDepth: Double = 20.0,
    avgDepth: Double = 12.0,
    divetime: TimeInterval = 1800
) -> DiveData {
    DiveData(
        number: number,
        datetime: Date(),
        maxDepth: maxDepth,
        avgDepth: avgDepth,
        divetime: divetime,
        temperature: 22.0,
        profile: [],
        tankPressure: [],
        gasMix: nil,
        gasMixCount: nil,
        gasMixes: nil,
        salinity: nil,
        atmospheric: nil,
        surfaceTemperature: nil,
        minTemperature: nil,
        maxTemperature: nil,
        tankCount: nil,
        tanks: nil,
        diveMode: .openCircuit,
        decoModel: nil,
        location: nil,
        rbt: nil,
        heartbeat: nil,
        bearing: nil,
        setpoint: nil,
        ppo2Readings: [],
        cns: nil,
        decoStop: nil
    )
}
