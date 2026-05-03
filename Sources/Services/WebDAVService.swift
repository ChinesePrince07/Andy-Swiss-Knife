import Foundation

enum WebDAVError: LocalizedError {
    case badURL, httpError(Int), parseError, downloadFailed

    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid URL"
        case .httpError(let code): return "Server error \(code)"
        case .parseError: return "Failed to parse response"
        case .downloadFailed: return "Download failed"
        }
    }
}

actor WebDAVService {
    static let shared = WebDAVService()

    private let base = URL(string: "https://app.koofr.net/dav/Koofr/documents/")!
    private let user = "zhangandy1234567@gmail.com"
    private let password = "66usz5o5kx7ryh4b"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.httpShouldSetCookies = false
        return URLSession(configuration: config)
    }()

    private func authHeader() -> String {
        let credentials = "\(user):\(password)"
        let encoded = Data(credentials.utf8).base64EncodedString()
        return "Basic \(encoded)"
    }

    private func url(for path: String) -> URL {
        if path.isEmpty { return base }
        return path.components(separatedBy: "/").reduce(base) { url, component in
            component.isEmpty ? url : url.appendingPathComponent(component)
        }
    }

    // MARK: - PROPFIND (list directory)

    func list(path: String) async throws -> [DriveItem] {
        var req = URLRequest(url: url(for: path))
        req.httpMethod = "PROPFIND"
        req.setValue(authHeader(), forHTTPHeaderField: "Authorization")
        req.setValue("1", forHTTPHeaderField: "Depth")
        req.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("text/xml,application/xml", forHTTPHeaderField: "Accept")
        let body = "<?xml version=\"1.0\" encoding=\"utf-8\"?><D:propfind xmlns:D=\"DAV:\"><D:prop><D:displayname/><D:resourcetype/><D:getcontentlength/><D:getlastmodified/><D:getcontenttype/></D:prop></D:propfind>"
        req.httpBody = body.data(using: .utf8)
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 207 {
            throw WebDAVError.httpError(http.statusCode)
        }

        return try WebDAVParser.parse(data: data, basePath: path, baseURL: base)
    }

    // MARK: - MKCOL (create folder)

    func createFolder(path: String) async throws {
        var req = URLRequest(url: url(for: path))
        req.httpMethod = "MKCOL"
        req.setValue(authHeader(), forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw WebDAVError.httpError(http.statusCode)
        }
    }

    // MARK: - DELETE

    func delete(path: String) async throws {
        var req = URLRequest(url: url(for: path))
        req.httpMethod = "DELETE"
        req.setValue(authHeader(), forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw WebDAVError.httpError(http.statusCode)
        }
    }

    // MARK: - MOVE (rename or move)

    func move(from fromPath: String, to toPath: String) async throws {
        var req = URLRequest(url: url(for: fromPath))
        req.httpMethod = "MOVE"
        req.setValue(authHeader(), forHTTPHeaderField: "Authorization")
        let destination = url(for: toPath).absoluteString
        req.setValue(destination, forHTTPHeaderField: "Destination")
        req.setValue("T", forHTTPHeaderField: "Overwrite")
        let (_, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw WebDAVError.httpError(http.statusCode)
        }
    }

    func rename(path: String, newName: String) async throws {
        let parentPath = (path as NSString).deletingLastPathComponent
        let newPath = parentPath.isEmpty ? newName : "\(parentPath)/\(newName)"
        try await move(from: path, to: newPath)
    }

    // MARK: - PUT (upload)

    func upload(data: Data, to path: String, mimeType: String = "application/octet-stream") async throws {
        var req = URLRequest(url: url(for: path))
        req.httpMethod = "PUT"
        req.setValue(authHeader(), forHTTPHeaderField: "Authorization")
        req.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        req.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        req.httpBody = data
        let (_, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw WebDAVError.httpError(http.statusCode)
        }
    }

    // MARK: - GET (download to temp file)

    func download(path: String) async throws -> URL {
        var req = URLRequest(url: url(for: path))
        req.setValue(authHeader(), forHTTPHeaderField: "Authorization")
        let (tempURL, response) = try await session.download(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw WebDAVError.httpError(http.statusCode)
        }
        let name = (path as NSString).lastPathComponent
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return dest
    }
}

// MARK: - XML Parser

private class WebDAVParser: NSObject, XMLParserDelegate {
    private let basePath: String
    private let baseURL: URL
    private var items: [DriveItem] = []

    private var currentPath = ""
    private var currentIsDir = false
    private var currentSize: Int64 = 0
    private var currentModified: Date? = nil
    private var currentMime: String? = nil

    private var currentText = ""
    private var insideResponse = false
    private var insideResourcetype = false

    static func parse(data: Data, basePath: String, baseURL: URL) throws -> [DriveItem] {
        let parser = WebDAVParser(basePath: basePath, baseURL: baseURL)
        let xml = XMLParser(data: data)
        xml.shouldProcessNamespaces = true
        xml.delegate = parser
        guard xml.parse() else { throw WebDAVError.parseError }
        return parser.items
    }

    init(basePath: String, baseURL: URL) {
        self.basePath = basePath
        self.baseURL = baseURL
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentText = ""
        if elementName == "response" {
            insideResponse = true
            currentPath = ""
            currentIsDir = false
            currentSize = 0
            currentModified = nil
            currentMime = nil
        } else if elementName == "collection" {
            currentIsDir = true
        } else if elementName == "resourcetype" {
            insideResourcetype = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "href":
            currentPath = decodedPath(from: currentText.trimmingCharacters(in: .whitespacesAndNewlines))
        case "getcontentlength":
            currentSize = Int64(currentText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        case "getlastmodified":
            currentModified = rfc1123.date(from: currentText.trimmingCharacters(in: .whitespacesAndNewlines))
        case "getcontenttype":
            let mime = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !mime.isEmpty { currentMime = mime }
        case "resourcetype":
            insideResourcetype = false
        case "response":
            let base = (baseURL.path as NSString).standardizingPath
            let decoded = currentPath
            let relative: String
            if decoded.hasPrefix(base) {
                relative = String(decoded.dropFirst(base.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            } else {
                relative = decoded.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }
            let selfPath = basePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard relative != selfPath else { break }
            let name = (relative as NSString).lastPathComponent
            guard !name.isEmpty else { break }
            items.append(DriveItem(
                id: relative,
                name: name,
                isDirectory: currentIsDir,
                size: currentSize,
                modified: currentModified,
                mimeType: currentMime
            ))
        default: break
        }
        currentText = ""
    }

    private func decodedPath(from href: String) -> String {
        return href.removingPercentEncoding ?? href
    }

    private var rfc1123: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return f
    }()
}
