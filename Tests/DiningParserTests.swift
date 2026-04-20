import XCTest
@testable import AndySwissKnife

final class DiningParserTests: XCTestCase {
    func testParsesNormalFormat() throws {
        let data = try TestFixture.load("dining-normal.html")
        let html = String(data: data, encoding: .utf8) ?? ""
        let result = try DiningParser.parseToday(html: html, weekday: "Tuesday")
        XCTAssertTrue(result.breakfast.contains("Scrambled eggs"))
        XCTAssertTrue(result.lunch.contains("Grilled chicken"))
        XCTAssertTrue(result.dinner.contains("Pasta primavera"))
        XCTAssertFalse(result.lunch.contains("Taco"))
    }

    func testParsesWednesdayEvenWhenOutOfOrder() throws {
        let data = try TestFixture.load("dining-normal.html")
        let html = String(data: data, encoding: .utf8) ?? ""
        let result = try DiningParser.parseToday(html: html, weekday: "Wednesday")
        XCTAssertTrue(result.breakfast.contains("Belgian waffle"))
        XCTAssertTrue(result.lunch.contains("Taco"))
    }

    func testThrowsOnBrokenHTML() throws {
        let data = try TestFixture.load("dining-broken.html")
        let html = String(data: data, encoding: .utf8) ?? ""
        XCTAssertThrowsError(try DiningParser.parseToday(html: html, weekday: "Monday"))
    }
}
