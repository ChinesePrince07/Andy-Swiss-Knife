import Foundation

protocol HTTPClient: Sendable {
    func data(for url: URL) async throws -> Data
}

struct URLSessionHTTPClient: HTTPClient {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("AndySwissKnife/0.1 (iOS)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw HTTPError.badStatus(http.statusCode)
        }
        return data
    }
}

enum HTTPError: Error, Equatable {
    case badStatus(Int)
}
