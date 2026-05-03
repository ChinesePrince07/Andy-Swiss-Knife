import Foundation

struct DriveItem: Identifiable, Equatable {
    let id: String       // full path relative to base, e.g. "Homework/notes.pdf"
    let name: String     // basename
    let isDirectory: Bool
    let size: Int64
    let modified: Date?
    let mimeType: String?

    var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }

    var fileType: DriveFileType {
        if isDirectory { return .folder }
        switch fileExtension {
        case "pdf": return .pdf
        case "doc", "docx": return .doc
        case "xls", "xlsx": return .xls
        case "ppt", "pptx": return .ppt
        case "jpg", "jpeg", "png", "gif", "heic", "webp": return .image
        case "txt", "md": return .text
        default: return .other
        }
    }
}

enum DriveFileType {
    case folder, pdf, doc, xls, ppt, image, text, other

    var label: String {
        switch self {
        case .folder: return "DIR"
        case .pdf:    return "PDF"
        case .doc:    return "DOC"
        case .xls:    return "XLS"
        case .ppt:    return "PPT"
        case .image:  return "IMG"
        case .text:   return "TXT"
        case .other:  return "FILE"
        }
    }
}
