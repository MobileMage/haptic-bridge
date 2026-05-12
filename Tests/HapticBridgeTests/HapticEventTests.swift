import XCTest
@testable import HapticBridge

final class HapticEventTests: XCTestCase {

    func testImpactRoundTrip() throws {
        let event = HapticEvent.impact(.heavy, intensity: 0.75)
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(HapticEvent.self, from: data)
        XCTAssertEqual(decoded.type, .impact)
        XCTAssertEqual(decoded.style, .heavy)
        XCTAssertEqual(decoded.intensity, 0.75)
        XCTAssertNil(decoded.feedback)
    }

    func testSelectionRoundTrip() throws {
        let data = try JSONEncoder().encode(HapticEvent.selection)
        let decoded = try JSONDecoder().decode(HapticEvent.self, from: data)
        XCTAssertEqual(decoded.type, .selection)
        XCTAssertNil(decoded.style)
        XCTAssertNil(decoded.feedback)
    }

    func testNotificationRoundTrip() throws {
        let data = try JSONEncoder().encode(HapticEvent.notification(.warning))
        let decoded = try JSONDecoder().decode(HapticEvent.self, from: data)
        XCTAssertEqual(decoded.type, .notification)
        XCTAssertEqual(decoded.feedback, .warning)
    }

    func testCoreHapticRoundTrip() throws {
        let data = try JSONEncoder().encode(HapticEvent.coreHaptic(intensity: 0.5, sharpness: 0.9))
        let decoded = try JSONDecoder().decode(HapticEvent.self, from: data)
        XCTAssertEqual(decoded.type, .coreHaptic)
        XCTAssertEqual(decoded.intensity, 0.5)
        XCTAssertEqual(decoded.sharpness, 0.9)
    }
}
