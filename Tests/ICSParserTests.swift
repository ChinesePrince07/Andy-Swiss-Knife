import XCTest
@testable import AndySwissKnife

final class ICSParserTests: XCTestCase {
    func testParsesSimpleEvents() throws {
        let data = try TestFixture.load("ics-simple.ics")
        let src = String(data: data, encoding: .utf8) ?? ""
        let events = try ICSParser.parse(src)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].uid, "event-001@test")
        XCTAssertEqual(events[0].summary, "Varsity Soccer")
        XCTAssertEqual(events[0].location, "Home Field")
        XCTAssertFalse(events[0].isAllDay)
        XCTAssertTrue(events[1].isAllDay)
    }

    func testExpandsWeeklyRRule() throws {
        let data = try TestFixture.load("ics-weekly.ics")
        let src = String(data: data, encoding: .utf8) ?? ""
        let parsed = try ICSParser.parse(src)
        XCTAssertEqual(parsed.count, 1)

        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        df.timeZone = TimeZone(identifier: "UTC")
        let windowStart = df.date(from: "20260413T000000Z")!
        let windowEnd = df.date(from: "20260606T000000Z")!

        let expanded = RRuleExpander.expand(event: parsed[0], from: windowStart, to: windowEnd)
        XCTAssertEqual(expanded.count, 8)
    }
}
