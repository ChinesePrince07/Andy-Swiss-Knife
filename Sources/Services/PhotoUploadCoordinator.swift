import Foundation
import Observation

@Observable
@MainActor
final class PhotoUploadCoordinator {
    struct Item: Identifiable, Hashable {
        let id = UUID()
        let fileName: String
        let displayName: String
        let contentType: String
        var status: Status = .pending

        enum Status: Hashable {
            case pending
            case uploading
            case done
            case failed(String)
        }
    }

    var items: [Item] = []
    var isUploading: Bool = false
    var message: String?
    var triggerDeploy: Bool = true

    func reset() {
        items = []
        message = nil
        isUploading = false
    }

    func append(fileName: String, displayName: String? = nil, contentType: String) {
        let safe = Self.safeName(for: fileName)
        guard !items.contains(where: { $0.fileName == safe }) else { return }
        items.append(Item(fileName: safe, displayName: displayName ?? safe, contentType: contentType))
    }

    func remove(_ item: Item) {
        items.removeAll { $0.id == item.id }
    }

    func upload(provider: @escaping @Sendable (Item) async throws -> Data) async {
        guard !items.isEmpty else { return }
        isUploading = true
        message = nil

        do {
            let files = items.map { (name: $0.fileName, type: $0.contentType) }
            let presign = try await SiteClient.shared.presignR2Uploads(files: files, triggerDeploy: false)

            let urlByName: [String: URL] = presign.urls.reduce(into: [:]) { acc, entry in
                if let url = URL(string: entry.url) { acc[entry.name] = url }
            }

            var anyFailed = false
            var anyOK = false

            for index in items.indices {
                items[index].status = .uploading
                let snapshot = items[index]
                guard let target = urlByName[snapshot.fileName] else {
                    items[index].status = .failed("No upload URL")
                    anyFailed = true
                    continue
                }
                do {
                    let data = try await provider(snapshot)
                    try await SiteClient.shared.putToPresigned(url: target, data: data, contentType: snapshot.contentType)
                    items[index].status = .done
                    anyOK = true
                } catch {
                    items[index].status = .failed(error.localizedDescription)
                    anyFailed = true
                }
            }

            if anyOK, triggerDeploy {
                try? await SiteClient.shared.triggerAfilmoryRebuild()
            }

            message = summary(success: anyOK, failed: anyFailed)
        } catch {
            message = error.localizedDescription
        }

        isUploading = false
    }

    private func summary(success: Bool, failed: Bool) -> String {
        let ok = items.filter { $0.status == .done }.count
        let fail = items.filter { if case .failed = $0.status { return true } else { return false } }.count
        if success && !failed { return "\(ok) uploaded" }
        if success && failed { return "\(ok) uploaded, \(fail) failed" }
        return "All uploads failed"
    }

    static func safeName(for raw: String) -> String {
        let trimmed = raw.replacingOccurrences(of: " ", with: "-")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-/"))
        return String(trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
    }
}
