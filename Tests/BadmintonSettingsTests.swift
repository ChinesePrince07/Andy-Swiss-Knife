import XCTest
@testable import AndySwissKnife

@MainActor
final class BadmintonSettingsTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "badminton.tests")!
        d.removePersistentDomain(forName: "badminton.tests")
        return d
    }

    func testPersistsScaleAndUnit() {
        let d = freshDefaults()
        let s1 = BadmintonSettings(defaults: d)
        s1.scale = ReferenceScale(p1: .zero, p2: CGPoint(x: 100, y: 0), realMeters: 1.55)
        s1.unit = .mph

        let s2 = BadmintonSettings(defaults: d)   // reload
        XCTAssertEqual(s2.scale, s1.scale)
        XCTAssertEqual(s2.unit, .mph)
    }

    func testDisplayFormatsByUnit() {
        let d = freshDefaults()
        let s = BadmintonSettings(defaults: d)
        s.unit = .kmh
        XCTAssertEqual(s.display(ShotSpeed(metersPerSecond: 100)), "360 km/h")
        s.unit = .mph
        XCTAssertEqual(s.display(ShotSpeed(metersPerSecond: 100)), "224 mph")
    }
}
