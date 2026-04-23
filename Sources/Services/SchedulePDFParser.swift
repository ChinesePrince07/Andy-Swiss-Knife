import PDFKit
import Vision
import UIKit

struct ParsedCourse {
    let periodLetter: String
    let name: String
    let room: String?
    let teacher: String?
}

enum SchedulePDFParser {
    static func parse(url: URL) -> [ParsedCourse]? {
        guard let doc = PDFDocument(url: url) else { return nil }
        var fullText = ""
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i), let text = page.string else { continue }
            fullText += text + "\n"
        }
        return parseText(fullText)
    }

    static func parseFromImage(_ image: UIImage) async -> [ParsedCourse] {
        guard let cgImage = image.cgImage else { return [] }
        let text = await ocrText(from: cgImage)
        return parseText(text)
    }

    private static func ocrText(from cgImage: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    static func parseText(_ text: String) -> [ParsedCourse] {
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let headerIdx = lines.firstIndex(where: {
            $0.contains("Period") && $0.contains("Course") && $0.contains("Teacher")
        }) else { return [] }

        var results: [ParsedCourse] = []
        let validPeriods: Set<String> = ["A","B","C","D","E","F","G"]
        let termLetters: Set<Character> = ["F","W","S"]

        for i in (headerIdx + 1)..<lines.count {
            let line = lines[i]
            guard let first = line.first, validPeriods.contains(String(first)) else {
                if !results.isEmpty { break }
                continue
            }
            let words = line.split(separator: " ").map(String.init)
            guard words.count >= 4 else { continue }

            let period = words[0]
            guard validPeriods.contains(period) else { continue }

            // Parse from the right: teacher (last 2 words), then terms (F/W/S), then name + room.
            var idx = words.count - 1
            let teacherLast = words[idx]; idx -= 1
            let teacherFirst = words[idx]; idx -= 1
            let teacher = "\(teacherFirst) \(teacherLast)"

            // Scan backwards past term indicators (F, W, S)
            while idx >= 2 && words[idx].count == 1 && termLetters.contains(words[idx].first!) {
                idx -= 1
            }

            // words[1] = course code. words[2...idx] = course name [+ room]
            let bodyWords = Array(words[2...idx])
            guard !bodyWords.isEmpty else { continue }

            var room: String? = nil
            var nameWords = bodyWords
            if let last = nameWords.last,
               last.allSatisfy({ $0.isUppercase || $0.isNumber }),
               last.count >= 3,
               !last.contains("("),
               !Self.isRomanNumeral(last) {
                room = last
                nameWords.removeLast()
            }

            let name = nameWords.joined(separator: " ")
            guard !name.isEmpty else { continue }

            results.append(ParsedCourse(
                periodLetter: period,
                name: name,
                room: room,
                teacher: teacher
            ))
        }
        return results
    }

    private static func isRomanNumeral(_ s: String) -> Bool {
        s.allSatisfy { "IVXLCDM".contains($0) }
    }
}
