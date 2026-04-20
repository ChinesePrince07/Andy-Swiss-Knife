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

    func testSkipsTimeRangeHeadersAndFindsContent() throws {
        let html = """
        <html><body>
        <h2>Sunday</h2>
        <p>Brunch: 10:00-12:30</p>
        <p>Dinner: 5:30-7:00</p>
        <p><strong>Brunch:</strong> Bacon, Eggs, Belgium Waffle Bar</p>
        <p><strong>Dinner:</strong> BBQ Kielbasa, Pierogies</p>
        </body></html>
        """
        let result = try DiningParser.parseToday(html: html, weekday: "Sunday")
        XCTAssertTrue(result.lunch.contains("Bacon"), "Got: \(result.lunch)")
        XCTAssertTrue(result.lunch.contains("Belgium Waffle"), "Got: \(result.lunch)")
        XCTAssertFalse(result.lunch.contains("10:00"), "Should not contain time header")
        XCTAssertTrue(result.dinner.contains("BBQ Kielbasa"), "Got: \(result.dinner)")
    }
}
