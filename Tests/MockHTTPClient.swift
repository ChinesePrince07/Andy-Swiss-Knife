import Foundation
@testable import AndySwissKnife

final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    var responses: [URL: Data] = [:]
    var errors: [URL: Error] = [:]
    var requestCount = 0

    func data(for url: URL) async throws -> Data {
        requestCount += 1
        if let err = errors[url] { throw err }
        if let data = responses[url] { return data }
        throw HTTPError.badStatus(404)
    }
}

enum TestFixture {
    static func load(_ name: String) throws -> Data {
        let url = Bundle(for: FixtureMarker.self).url(forResource: name, withExtension: nil)
        guard let url else { throw NSError(domain: "TestFixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing fixture: \(name)"]) }
        return try Data(contentsOf: url)
    }
}

private final class FixtureMarker {}
