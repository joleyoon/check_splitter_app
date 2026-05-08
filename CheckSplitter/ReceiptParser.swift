import Foundation
import UIKit
import Vision

enum ReceiptParser {
    static func recognizeItems(in image: UIImage) async throws -> [BillItem] {
        guard let cgImage = image.cgImage else { return [] }

        let lines = try await recognizeTextLines(in: cgImage)
        return parseItems(from: lines)
    }

    static func parseItems(from lines: [String]) -> [BillItem] {
        lines.compactMap(parseItemLine)
    }

    private static func recognizeTextLines(in cgImage: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                continuation.resume(returning: lines)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func parseItemLine(_ rawLine: String) -> BillItem? {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !line.isEmpty, !isSummaryLine(line) else { return nil }

        let pattern = #"(?i)^\s*(.+?)\s+\$?([0-9]+(?:[.,][0-9]{2}))\s*$"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
            match.numberOfRanges == 3,
            let nameRange = Range(match.range(at: 1), in: line),
            let priceRange = Range(match.range(at: 2), in: line)
        else {
            return nil
        }

        let name = line[nameRange]
            .trimmingCharacters(in: CharacterSet(charactersIn: " .:-\t"))
        let amountText = line[priceRange].replacingOccurrences(of: ",", with: ".")

        guard !name.isEmpty, let price = Decimal(string: amountText), price > 0 else {
            return nil
        }

        return BillItem(name: String(name), price: price)
    }

    private static func isSummaryLine(_ line: String) -> Bool {
        let normalized = line.lowercased()
        let summaryWords = [
            "subtotal",
            "sub total",
            "tax",
            "tip",
            "gratuity",
            "total",
            "balance",
            "amount due",
            "change",
            "visa",
            "mastercard",
            "amex"
        ]
        return summaryWords.contains { normalized.contains($0) }
    }
}
