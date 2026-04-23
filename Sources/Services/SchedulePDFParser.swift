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
                let rows = groupIntoRows(observations)
                let text = rows.map { row in
                    row.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
                }.joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    private static func groupIntoRows(_ observations: [VNRecognizedTextObservation]) -> [[VNRecognizedTextObservation]] {
        guard !observations.isEmpty else { return [] }
        let avgHeight = observations.map { $0.boundingBox.height }.reduce(0, +) / CGFloat(observations.count)
        let threshold = avgHeight * 0.6
        // Vision y-axis: 0 = bottom, 1 = top. Sort descending = top-of-page first.
        let sorted = observations.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        var rows: [[VNRecognizedTextObservation]] = []
        var currentRow: [VNRecognizedTextObservation] = [sorted[0]]
        var anchorY = sorted[0].boundingBox.midY
        for i in 1..<sorted.count {
            let midY = sorted[i].boundingBox.midY
            if abs(midY - anchorY) < threshold {
                currentRow.append(sorted[i])
            } else {
                rows.append(currentRow.sorted { $0.boundingBox.minX < $1.boundingBox.minX })
                currentRow = [sorted[i]]
                anchorY = midY
            }
        }
        rows.append(currentRow.sorted { $0.boundingBox.minX < $1.boundingBox.minX })
        return rows
    }

    static func parseText(_ text: String) -> [ParsedCourse] {
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let orderedPeriods = ["A","B","C","D","E","F","G"]
        let validPeriods = Set(orderedPeriods)
        var results: [ParsedCourse] = []
        var nextPeriodIdx = 0

        for line in lines {
            let words = line.split(separator: " ").map(String.init)
            guard words.count >= 4 else { continue }
            guard nextPeriodIdx < orderedPeriods.count else { break }

            var period: String
            var codeIdx: Int

            if words[0].count == 1, validPeriods.contains(words[0]) {
                period = words[0]
                codeIdx = 1
            } else if words[0].count >= 3, words[0].allSatisfy({ $0.isLetter || $0.isNumber }) {
                period = orderedPeriods[nextPeriodIdx]
                codeIdx = 0
            } else {
                continue
            }

            guard codeIdx < words.count else { continue }
            let code = words[codeIdx]
            guard code.count >= 3, code.allSatisfy({ $0.isLetter || $0.isNumber }) else { continue }

            // From right: teacher (last 2 words) → terms (FWS/F/W/S combos) → name [+ room].
            var idx = words.count - 1
            guard idx >= codeIdx + 2 else { continue }
            let teacherLast = words[idx]; idx -= 1
            let teacherFirst = words[idx]; idx -= 1
            let teacher = "\(teacherFirst) \(teacherLast)"

            while idx >= codeIdx + 1 && words[idx].allSatisfy({ "FWS".contains($0) }) && !words[idx].isEmpty {
                idx -= 1
            }

            let startBody = codeIdx + 1
            guard idx >= startBody else { continue }
            let bodyWords = Array(words[startBody...idx])
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

            if let pIdx = orderedPeriods.firstIndex(of: period), pIdx >= nextPeriodIdx {
                nextPeriodIdx = pIdx + 1
            } else {
                nextPeriodIdx += 1
            }

            results.append(ParsedCourse(periodLetter: period, name: name, room: room, teacher: teacher))
        }
        return results
    }

    private static func isRomanNumeral(_ s: String) -> Bool {
        s.allSatisfy { "IVXLCDM".contains($0) }
    }
}
