import Vision
import UIKit

/// Extracts text from images using the Vision framework's text recognition.
/// Uses VNImageRequestHandler(url:) for memory-efficient processing within the 120 MB extension limit.
final class OCRService {

    enum OCRError: LocalizedError {
        case noTextFound
        case recognitionFailed(String)

        var errorDescription: String? {
            switch self {
            case .noTextFound:
                return "No text could be found in this image. Try a clearer screenshot."
            case .recognitionFailed(let message):
                return "Text recognition failed: \(message)"
            }
        }
    }

    /// Recognizes text from an image at the given file URL.
    /// Uses file URL directly to avoid loading the full image bitmap into memory.
    func recognizeText(from url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            // Guard against double-resume: perform() may both call the completion handler
            // and throw, so we track whether the continuation has already been resumed.
            var hasResumed = false
            let resumeOnce: (Result<String, Error>) -> Void = { result in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(with: result)
            }

            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    resumeOnce(.failure(OCRError.recognitionFailed(error.localizedDescription)))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    resumeOnce(.failure(OCRError.noTextFound))
                    return
                }

                let rawText = observations
                    .filter { $0.confidence >= 0.3 }
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                let cleaned = OCRService.stripUIChrome(from: rawText)

                if cleaned.isEmpty {
                    resumeOnce(.failure(OCRError.noTextFound))
                } else {
                    resumeOnce(.success(cleaned))
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(url: url, options: [:])
            do {
                try handler.perform([request])
            } catch {
                resumeOnce(.failure(OCRError.recognitionFailed(error.localizedDescription)))
            }
        }
    }

    // MARK: - Post-Processing

    /// Strips common iOS UI chrome text from OCR output, keeping only message content.
    /// SMS screenshots contain status bar, phone numbers, timestamps, and button labels
    /// that pollute the extracted text.
    static func stripUIChrome(from text: String) -> String {
        let lines = text.components(separatedBy: "\n")

        let cleaned = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return false }

            // Normalize: strip special characters for matching (OCR renders • as various chars)
            let lowered = trimmed.lowercased()
            let normalized = lowered.replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)

            // Strip lines that are entirely iOS UI elements (exact match)
            if uiChromeStrings.contains(lowered) || uiChromeStrings.contains(normalized) { return false }

            // Strip lines matching UI chrome patterns (contains-based for multi-word with special chars)
            for pattern in uiChromePatterns {
                if lowered.contains(pattern) && trimmed.count < 60 { return false }
            }

            // Strip standalone time patterns: "12:34", "6:41", "12:34 PM", "6:416" (OCR mangling)
            if trimmed.range(of: #"^\d{1,2}:\d{2,3}\s*\S{0,2}$"#, options: .regularExpression) != nil {
                return false
            }

            // Strip date/time lines: "Thu, Oct 9 at 12:16 PM", "Today 2:30 PM", day-of-week patterns
            if trimmed.range(of: #"^(Mon|Tue|Wed|Thu|Fri|Sat|Sun|Today|Yesterday)"#, options: .regularExpression) != nil && trimmed.count < 40 {
                return false
            }

            // Strip date lines starting with month abbreviations: "Apr 6, 2024 at 10:44 AM"
            if trimmed.range(of: #"^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\b"#, options: .regularExpression) != nil && trimmed.count < 40 {
                return false
            }

            // Strip navigation artifacts: "< 813" (back arrow + badge count)
            if trimmed.range(of: #"^<\s*\d{1,4}$"#, options: .regularExpression) != nil {
                return false
            }

            // Strip carrier/status bar fragments
            if carrierPatterns.contains(where: { lowered == $0 }) { return false }
            if trimmed.range(of: #"^\d{1,3}%$"#, options: .regularExpression) != nil { return false }

            // Strip standalone phone numbers — generous matching for OCR artifacts like trailing )
            let digitsOnly = trimmed.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            if digitsOnly.count >= 10 && digitsOnly.count <= 11 && trimmed.count < 25 {
                return false
            }

            // Strip purely numeric short lines (badge counts like "813", nav numbers)
            if trimmed.range(of: #"^\d{1,4}$"#, options: .regularExpression) != nil { return false }

            // Strip very short lines (1-2 chars) that are typically UI artifacts
            if trimmed.count <= 2 { return false }

            return true
        }

        return cleaned.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let uiChromeStrings: Set<String> = [
        // Messages app UI
        "delete", "mark as known", "mark as junk", "report junk", "not junk",
        "reply", "more", "copy", "forward", "share",
        "imessage", "text message", "sms", "mms",
        "delivered", "read", "sent", "not delivered",
        "send", "cancel", "done", "ok", "edit",
        // Message filter UI
        "junk", "transaction", "unknown senders",
        // Status bar
        "lte", "5g", "4g", "3g", "wi-fi", "wifi",
        "no service", "searching...", "sos",
        // Navigation
        "back", "messages", "details", "info", "contact",
        // Keyboard/input
        "return", "space", "shift", "abc", "123",
        // Normalized versions (special chars replaced with spaces, collapsed)
        "text message sms",
    ]

    /// Patterns matched via contains — for lines with special characters OCR may mangle.
    /// Only use patterns specific enough to not appear in normal message content.
    private static let uiChromePatterns: [String] = [
        "text message \u{2022}", // "Text Message • SMS" with bullet
        "text message  sms",     // OCR sometimes drops the bullet
        "if you did not expect this message",
        "it may be spam",
        "from an unknown sender",
        "report junk",
        "mark as known",
    ]

    private static let carrierPatterns: Set<String> = [
        "at&t", "verizon", "t-mobile", "sprint", "us cellular",
        "visible", "mint", "cricket", "metro", "boost",
        "google fi", "xfinity", "spectrum", "consumer cellular",
    ]

    /// Creates a downsampled thumbnail from an image URL for preview display.
    /// Returns nil if the image cannot be loaded.
    /// Callers pass the real display scale (SwiftUI `displayScale`); the default
    /// is only a safety value for tests and callers without an environment.
    /// A non-positive `scale` is treated as 1.
    static func createThumbnail(from url: URL, maxHeight: CGFloat = 150, scale: CGFloat = 2) -> UIImage? {
        let pixelSize = maxHeight * max(scale, 1)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
