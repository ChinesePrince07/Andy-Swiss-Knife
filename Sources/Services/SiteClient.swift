import Foundation

enum SiteClientError: LocalizedError {
    case notConfigured
    case unauthorized
    case http(Int, String?)
    case decoding
    case unknown

    var errorDescription: String? {
        switch self {
        case .notConfigured:    return "Publishing isn’t set up. Add your site URL and secret in Settings."
        case .unauthorized:     return "Wrong publish secret."
        case .http(let c, let m): return m?.isEmpty == false ? "HTTP \(c): \(m!)" : "HTTP \(c)"
        case .decoding:         return "Unexpected response."
        case .unknown:          return "Something went wrong."
        }
    }
}

// MARK: - Models

struct BlogPostSummary: Codable, Identifiable, Hashable, Sendable {
    let slug: String
    let title: String
    let date: String
    let description: String
    let pinned: Bool
    var id: String { slug }
}

struct BlogPostDetail: Codable, Sendable {
    let slug: String
    let title: String
    let date: String
    let description: String
    let content: String
    let pinned: Bool
}

struct BlogPostInput: Codable, Sendable {
    var title: String
    var date: String
    var description: String
    var content: String
    var pinned: Bool
}

struct R2Photo: Codable, Identifiable, Hashable, Sendable {
    let key: String
    let size: Int64
    let lastModified: String?
    let url: String
    var id: String { key }
}

struct R2PresignedURL: Codable, Sendable {
    let name: String
    let url: String
}

struct R2PresignResponse: Codable, Sendable {
    let urls: [R2PresignedURL]
    let deployTriggered: Bool
}

struct UploadBlobResponse: Codable, Sendable {
    let url: String
    let pathname: String
}

// MARK: - Client

actor SiteClient {
    static let shared = SiteClient()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 600
        return URLSession(configuration: config)
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    // MARK: Endpoint construction

    @MainActor
    private func currentConfig() throws -> (URL, String) {
        let auth = SiteAuth.shared
        guard let base = auth.endpointURL, !auth.secret.isEmpty else {
            throw SiteClientError.notConfigured
        }
        return (base, auth.secret)
    }

    private func url(path: String, query: [URLQueryItem] = []) async throws -> (URLRequest, String) {
        let (base, secret) = try await currentConfig()

        // Next.js on andypandy.org is configured with trailingSlash: true. A request to
        // /api/admin/posts gets a 308 to /api/admin/posts/. URLSession drops the
        // Authorization header on cross-origin redirects, so hit the canonical
        // trailing-slash path directly.
        let normalizedPath = path.hasSuffix("/") ? path : path + "/"
        let baseString = base.absoluteString.hasSuffix("/")
            ? String(base.absoluteString.dropLast())
            : base.absoluteString
        guard var comps = URLComponents(string: baseString + normalizedPath) else {
            throw SiteClientError.notConfigured
        }
        if !query.isEmpty { comps.queryItems = query }
        guard let final = comps.url else { throw SiteClientError.notConfigured }

        var req = URLRequest(url: final)
        req.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        req.setValue("AndySwissKnife/0.1 (iOS)", forHTTPHeaderField: "User-Agent")
        return (req, secret)
    }

    private func send<T: Decodable>(_ req: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: req)
        try checkStatus(response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw SiteClientError.decoding
        }
    }

    @discardableResult
    private func sendVoid(_ req: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: req)
        try checkStatus(response, data: data)
        return data
    }

    private func checkStatus(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw SiteClientError.unknown }
        if http.statusCode == 401 { throw SiteClientError.unauthorized }
        if !(200...299).contains(http.statusCode) {
            throw SiteClientError.http(http.statusCode, Self.sanitizeServerMessage(data: data))
        }
    }

    /// Trims server error bodies to a safe length and strips anything that looks like a Bearer token,
    /// so a misbehaving 5xx body can't echo the secret back into the UI.
    private static func sanitizeServerMessage(data: Data) -> String? {
        guard var text = String(data: data, encoding: .utf8), !text.isEmpty else { return nil }
        if text.count > 240 { text = String(text.prefix(240)) + "…" }
        let stripped = text.replacingOccurrences(
            of: #"Bearer\s+\S+"#,
            with: "Bearer …",
            options: .regularExpression
        )
        return stripped
    }

    private func encodedSlug(_ slug: String) -> String {
        slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
    }

    // MARK: - Auth ping

    func verifyCredentials() async throws {
        var (req, _) = try await url(path: "/api/admin/posts")
        req.httpMethod = "GET"
        _ = try await sendVoid(req)
    }

    // MARK: - Posts

    func listPosts() async throws -> [BlogPostSummary] {
        var (req, _) = try await url(path: "/api/admin/posts")
        req.httpMethod = "GET"
        return try await send(req, as: [BlogPostSummary].self)
    }

    func loadPost(slug: String) async throws -> BlogPostDetail {
        var (req, _) = try await url(path: "/api/admin/posts/\(encodedSlug(slug))")
        req.httpMethod = "GET"
        return try await send(req, as: BlogPostDetail.self)
    }

    func createPost(_ input: BlogPostInput, slug: String? = nil) async throws -> String {
        var (req, _) = try await url(path: "/api/admin/posts")
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "title": input.title,
            "date": input.date,
            "description": input.description,
            "content": input.content,
            "pinned": input.pinned,
        ]
        if let slug { body["slug"] = slug }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        struct R: Decodable { let slug: String }
        let r = try await send(req, as: R.self)
        return r.slug
    }

    func savePost(slug: String, input: BlogPostInput) async throws {
        var (req, _) = try await url(path: "/api/admin/posts/\(encodedSlug(slug))")
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "title": input.title,
            "date": input.date,
            "description": input.description,
            "content": input.content,
            "pinned": input.pinned,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await sendVoid(req)
    }

    func deletePost(slug: String) async throws {
        var (req, _) = try await url(path: "/api/admin/posts/\(encodedSlug(slug))")
        req.httpMethod = "DELETE"
        _ = try await sendVoid(req)
    }

    func togglePin(slug: String, pinned: Bool) async throws {
        var (req, _) = try await url(path: "/api/admin/posts/\(encodedSlug(slug))")
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["pinned": pinned])
        _ = try await sendVoid(req)
    }

    // MARK: - Inline media upload (Vercel Blob via multipart)

    func uploadInlineMedia(data: Data, fileName: String, contentType: String) async throws -> URL {
        var (req, _) = try await url(path: "/api/admin/upload-blob")
        req.httpMethod = "POST"

        let boundary = "----SwissKnifeUpload\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let response: UploadBlobResponse = try await send(req, as: UploadBlobResponse.self)
        guard let url = URL(string: response.url) else { throw SiteClientError.decoding }
        return url
    }

    // MARK: - R2 photos

    func listR2Photos(prefix: String? = nil) async throws -> [R2Photo] {
        var query: [URLQueryItem] = []
        if let prefix, !prefix.isEmpty { query.append(URLQueryItem(name: "prefix", value: prefix)) }
        var (req, _) = try await url(path: "/api/admin/r2-photos", query: query)
        req.httpMethod = "GET"
        struct R: Decodable { let photos: [R2Photo]; let prefix: String }
        let r = try await send(req, as: R.self)
        return r.photos
    }

    func presignR2Uploads(files: [(name: String, type: String)], triggerDeploy: Bool = false) async throws -> R2PresignResponse {
        var (req, _) = try await url(path: "/api/admin/r2-upload")
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "files": files.map { ["name": $0.name, "type": $0.type] },
            "triggerDeploy": triggerDeploy,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(req, as: R2PresignResponse.self)
    }

    func triggerAfilmoryRebuild() async throws {
        // POST with empty files just to fire the deploy hook server-side.
        var (req, _) = try await url(path: "/api/admin/r2-upload")
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["files": [], "triggerDeploy": true]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await sendVoid(req)
    }

    func deleteR2Photos(keys: [String], triggerDeploy: Bool = true) async throws {
        var (req, _) = try await url(path: "/api/admin/r2-photos")
        req.httpMethod = "DELETE"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["keys": keys, "triggerDeploy": triggerDeploy]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await sendVoid(req)
    }

    func moveR2Photo(from: String, to: String, triggerDeploy: Bool = true) async throws {
        var (req, _) = try await url(path: "/api/admin/r2-photos/move")
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["from": from, "to": to, "triggerDeploy": triggerDeploy]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await sendVoid(req)
    }

    // MARK: - Raw R2 PUT to presigned URL

    func putToPresigned(url: URL, data: Data, contentType: String) async throws {
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        let (_, response) = try await session.upload(for: req, from: data)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SiteClientError.http((response as? HTTPURLResponse)?.statusCode ?? -1, "R2 PUT failed")
        }
    }
}
