import XCTest
import SwiftData
@testable import AndySwissKnife

@MainActor
final class AssignmentsSyncServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var http: MockHTTPClient!
    var feedURL: URL!

    override func setUpWithError() throws {
        container = try AppModelContainer.make(inMemory: true)
        context = container.mainContext
        http = MockHTTPClient()
        feedURL = URL(string: "https://test.local/canvas.ics")!
    }

    func testFirstSyncImportsAll() async throws {
        let data = try TestFixture.load("ics-canvas.ics")
        http.responses[feedURL] = data
        let sut = AssignmentsSyncService(http: http, context: context, feedURL: feedURL)

        try await sut.syncCanvas()

        let todos = try context.fetch(FetchDescriptor<Todo>())
        XCTAssertEqual(todos.count, 2)
        XCTAssertTrue(todos.allSatisfy { $0.source == .canvas })
        XCTAssertNotNil(todos.first(where: { $0.title.contains("English essay") }))
    }

    func testSecondSyncDoesNotDuplicate() async throws {
        http.responses[feedURL] = try TestFixture.load("ics-canvas.ics")
        let sut = AssignmentsSyncService(http: http, context: context, feedURL: feedURL)

        try await sut.syncCanvas()
        try await sut.syncCanvas()

        let todos = try context.fetch(FetchDescriptor<Todo>())
        XCTAssertEqual(todos.count, 2)
    }

    func testUpdatedFeedUpdatesTitleWhenNotUserEdited() async throws {
        http.responses[feedURL] = try TestFixture.load("ics-canvas.ics")
        let sut = AssignmentsSyncService(http: http, context: context, feedURL: feedURL)
        try await sut.syncCanvas()

        http.responses[feedURL] = try TestFixture.load("ics-canvas-updated.ics")
        try await sut.syncCanvas()

        let todos = try context.fetch(FetchDescriptor<Todo>())
        let english = todos.first(where: { $0.externalID == "canvas-hw-001@instructure.com" })
        XCTAssertEqual(english?.title, "English essay - FINAL draft")
    }

    func testDisappearedUIDIsNotDeleted() async throws {
        http.responses[feedURL] = try TestFixture.load("ics-canvas.ics")
        let sut = AssignmentsSyncService(http: http, context: context, feedURL: feedURL)
        try await sut.syncCanvas()

        http.responses[feedURL] = try TestFixture.load("ics-canvas-updated.ics")
        try await sut.syncCanvas()

        let todos = try context.fetch(FetchDescriptor<Todo>())
        XCTAssertNotNil(todos.first(where: { $0.externalID == "canvas-hw-002@instructure.com" }),
                       "Disappeared UIDs should still exist")
    }

    func testUserEditedTitleNotOverwritten() async throws {
        http.responses[feedURL] = try TestFixture.load("ics-canvas.ics")
        let sut = AssignmentsSyncService(http: http, context: context, feedURL: feedURL)
        try await sut.syncCanvas()

        let existing = try context.fetch(FetchDescriptor<Todo>())
            .first(where: { $0.externalID == "canvas-hw-001@instructure.com" })!
        existing.title = "My own title"
        existing.userEdited = true
        try context.save()

        http.responses[feedURL] = try TestFixture.load("ics-canvas-updated.ics")
        try await sut.syncCanvas()

        let reread = try context.fetch(FetchDescriptor<Todo>())
            .first(where: { $0.externalID == "canvas-hw-001@instructure.com" })!
        XCTAssertEqual(reread.title, "My own title")
    }
}
