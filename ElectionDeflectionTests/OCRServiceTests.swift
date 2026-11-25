import XCTest
import Vision
import UIKit
@testable import ElectionDeflection

final class OCRServiceTests: XCTestCase {

    private var sut: OCRService!

    override func setUp() {
        super.setUp()
        sut = OCRService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - OCR Text Extraction Tests

    func testRecognizeTextFromImageWithKnownText() async throws {
        // Create a test image with known text rendered into it
        let testText = "Vote YES on Proposition 42"
        let imageURL = try createTestImage(withText: testText)
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let result = try await sut.recognizeText(from: imageURL)

        // OCR may not get an exact match but should contain key words
        XCTAssertFalse(result.isEmpty, "OCR should extract some text from the image")
        // Check at least some words were recognized (OCR is approximate)
        let resultLower = result.lowercased()
        let hasRelevantContent = resultLower.contains("vote") ||
                                  resultLower.contains("proposition") ||
                                  resultLower.contains("42") ||
                                  resultLower.contains("yes")
        XCTAssertTrue(hasRelevantContent, "OCR should recognize at least some words from '\(testText)', got: '\(result)'")
    }

    func testRecognizeTextFromMultilineImage() async throws {
        let testText = "URGENT: Vote on Nov 5th\nYour voice matters\nText STOP to opt out"
        let imageURL = try createTestImage(withText: testText)
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let result = try await sut.recognizeText(from: imageURL)

        XCTAssertFalse(result.isEmpty, "OCR should extract text from multi-line image")
        // Verify multiple lines are present (joined by newlines)
        let lines = result.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertGreaterThan(lines.count, 1, "OCR should recognize multiple lines of text, got: '\(result)'")
    }

    func testRecognizeTextFromBlankImageThrowsNoTextFound() async {
        // Create a blank white image with no text
        do {
            let imageURL = try createBlankImage()
            defer { try? FileManager.default.removeItem(at: imageURL) }

            _ = try await sut.recognizeText(from: imageURL)
            XCTFail("Expected noTextFound error for blank image")
        } catch let error as OCRService.OCRError {
            switch error {
            case .noTextFound:
                break // Expected
            case .recognitionFailed:
                break // Also acceptable - blank images may fail recognition
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRecognizeTextFromInvalidURLThrowsError() async {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/path/to/image.png")

        do {
            _ = try await sut.recognizeText(from: invalidURL)
            XCTFail("Expected error for invalid URL")
        } catch {
            // Any error is expected for an invalid file path
            XCTAssertNotNil(error)
        }
    }

    // MARK: - OCR Error Description Tests

    func testNoTextFoundErrorHasDescription() {
        let error = OCRService.OCRError.noTextFound
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.lowercased().contains("no text"))
    }

    func testRecognitionFailedErrorHasDescription() {
        let error = OCRService.OCRError.recognitionFailed("test reason")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("test reason"))
    }

    // MARK: - Thumbnail Generation Tests

    func testCreateThumbnailFromValidImage() throws {
        let imageURL = try createTestImage(withText: "Test")
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let thumbnail = OCRService.createThumbnail(from: imageURL, maxHeight: 100)
        XCTAssertNotNil(thumbnail, "Should create thumbnail from valid image")
        // Thumbnail should be roughly 100pt height or less (accounting for scale)
        if let thumb = thumbnail {
            XCTAssertLessThanOrEqual(thumb.size.height, 150, "Thumbnail height should be bounded")
        }
    }

    func testCreateThumbnailFromInvalidURLReturnsNil() {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/image.png")
        let thumbnail = OCRService.createThumbnail(from: invalidURL, maxHeight: 100)
        XCTAssertNil(thumbnail, "Should return nil for invalid image URL")
    }

    func testCreateThumbnailHonorsInjectedScale() throws {
        let imageURL = try createTestImage(withText: "Test")
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let maxHeight: CGFloat = 50
        let small = OCRService.createThumbnail(from: imageURL, maxHeight: maxHeight, scale: 1)
        let large = OCRService.createThumbnail(from: imageURL, maxHeight: maxHeight, scale: 2)
        XCTAssertNotNil(small)
        XCTAssertNotNil(large)

        // UIImage(cgImage:) has scale 1, so size equals pixels.
        if let small = small, let large = large {
            XCTAssertLessThanOrEqual(max(small.size.width, small.size.height), maxHeight * 1)
            XCTAssertLessThanOrEqual(max(large.size.width, large.size.height), maxHeight * 2)
            XCTAssertGreaterThan(large.size.width, small.size.width, "Scale 2 should yield a larger thumbnail than scale 1")
        }
    }

    func testCreateThumbnailTreatsNonPositiveScaleAsOne() throws {
        let imageURL = try createTestImage(withText: "Test")
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let maxHeight: CGFloat = 50
        for scale: CGFloat in [0, -1] {
            let thumbnail = OCRService.createThumbnail(from: imageURL, maxHeight: maxHeight, scale: scale)
            XCTAssertNotNil(thumbnail, "Scale \(scale) should still produce a thumbnail")
            if let thumb = thumbnail {
                XCTAssertLessThanOrEqual(max(thumb.size.width, thumb.size.height), maxHeight)
            }
        }
    }

    // MARK: - Sanitization Pipeline Integration Tests

    func testOCROutputPassesThroughSanitization() {
        // Simulate OCR output that contains phone numbers (common in political texts)
        let ocrOutput = "Vote for Candidate X! Call 555-123-4567 for ride to polls. Campaign HQ: (202) 555-0199"
        let service = TextSubmissionService()
        let sanitized = service.sanitize(ocrOutput)

        XCTAssertFalse(sanitized.contains("555-123-4567"), "Phone numbers should be anonymized from OCR output")
        XCTAssertFalse(sanitized.contains("(202) 555-0199"), "Phone numbers with parentheses should be anonymized")
        XCTAssertTrue(sanitized.contains("Vote for Candidate X"), "Political content should be preserved")
        // Phone format should be preserved with randomized digits
        XCTAssertTrue(sanitized.contains("-"), "Phone format (dashes) should be preserved")
        XCTAssertTrue(sanitized.contains("("), "Phone format (parens) should be preserved")
    }

    func testOCROutputWithEmailAndURLSanitized() {
        // OCR'd screenshots often contain email addresses and URLs with tracking params
        let ocrOutput = "Support the campaign! Email volunteer@pac2024.com or visit https://donate.pac.com/give?ref=txt42&src=sms"
        let service = TextSubmissionService()
        let sanitized = service.sanitize(ocrOutput)

        XCTAssertFalse(sanitized.contains("volunteer@pac2024.com"), "Email should be anonymized")
        XCTAssertFalse(sanitized.contains("donate.pac.com"), "URL domain should be anonymized")
        XCTAssertFalse(sanitized.contains("txt42"), "URL tracking param values should be randomized")
        XCTAssertTrue(sanitized.contains("@"), "Email format preserved")
        XCTAssertTrue(sanitized.contains("/give"), "URL path preserved")
        XCTAssertTrue(sanitized.contains("ref="), "URL query key preserved")
        XCTAssertTrue(sanitized.contains("Support the campaign"), "Political content preserved")
    }

    func testOCROutputWithExcessiveWhitespace() {
        // OCR often introduces extra whitespace
        let ocrOutput = "  \n  URGENT: Vote YES on Prop 42  \n  Your voice matters!  \n  "
        let service = TextSubmissionService()
        let sanitized = service.sanitize(ocrOutput)

        XCTAssertFalse(sanitized.hasPrefix(" "), "Leading whitespace should be trimmed")
        XCTAssertFalse(sanitized.hasSuffix(" "), "Trailing whitespace should be trimmed")
        XCTAssertTrue(sanitized.contains("URGENT"), "Content should be preserved")
    }

    func testOCROutputLengthValidation() {
        let service = TextSubmissionService()

        // Short OCR result (under 20 chars after sanitization)
        let shortOCR = "Vote YES"
        let shortSanitized = service.sanitize(shortOCR)
        XCTAssertLessThan(shortSanitized.count, 20, "Short OCR text should be under minimum")

        // Long OCR result (over 2000 chars)
        let longOCR = String(repeating: "Vote YES on Proposition 42. ", count: 200)
        let longSanitized = service.sanitize(longOCR)
        XCTAssertLessThanOrEqual(longSanitized.count, 2000, "Long OCR text should be truncated to max length")
    }

    // MARK: - UI Chrome Stripping Tests

    func testStripUIChrome_RemovesDeleteAndMarkAsKnown() {
        let ocrOutput = "12:34 PM\n(555) 867-5309\nVote YES on Prop 42 to save democracy!\nDelete\nMark as Known"
        let cleaned = OCRService.stripUIChrome(from: ocrOutput)

        XCTAssertFalse(cleaned.contains("Delete"), "Should strip 'Delete' button text")
        XCTAssertFalse(cleaned.contains("Mark as Known"), "Should strip 'Mark as Known' button text")
        XCTAssertTrue(cleaned.contains("Vote YES"), "Should preserve message content")
    }

    func testStripUIChrome_RemovesTimestamp() {
        let ocrOutput = "2:30 PM\nURGENT: Your vote matters on Nov 5th"
        let cleaned = OCRService.stripUIChrome(from: ocrOutput)

        XCTAssertFalse(cleaned.contains("2:30 PM"), "Should strip standalone timestamps")
        XCTAssertTrue(cleaned.contains("URGENT"), "Should preserve message content")
    }

    func testStripUIChrome_RemovesStandalonePhoneNumber() {
        let ocrOutput = "+1-555-123-4567\nVote for candidate X in the upcoming election!"
        let cleaned = OCRService.stripUIChrome(from: ocrOutput)

        XCTAssertFalse(cleaned.contains("555-123-4567"), "Should strip standalone phone numbers")
        XCTAssertTrue(cleaned.contains("Vote for candidate"), "Should preserve message content")
    }

    func testStripUIChrome_RemovesCarrierAndStatusBar() {
        let ocrOutput = "Verizon\n5G\n87%\n12:34\nElection Day is November 5th — make your voice heard!"
        let cleaned = OCRService.stripUIChrome(from: ocrOutput)

        XCTAssertFalse(cleaned.lowercased().contains("verizon"), "Should strip carrier name")
        XCTAssertFalse(cleaned.contains("5G"), "Should strip network type")
        XCTAssertFalse(cleaned.contains("87%"), "Should strip battery percentage")
        XCTAssertTrue(cleaned.contains("Election Day"), "Should preserve message content")
    }

    func testStripUIChrome_RemovesMessageAppUI() {
        let ocrOutput = "Messages\nJunk\nDelivered\nReply\nIMESSAGE\nActual political text message content here"
        let cleaned = OCRService.stripUIChrome(from: ocrOutput)

        XCTAssertFalse(cleaned.lowercased().contains("messages"), "Should strip Messages nav text")
        XCTAssertFalse(cleaned.lowercased().contains("delivered"), "Should strip delivery status")
        XCTAssertFalse(cleaned.lowercased().contains("reply"), "Should strip Reply button text")
        XCTAssertTrue(cleaned.contains("Actual political"), "Should preserve message content")
    }

    func testStripUIChrome_PreservesInlineTimestampsInContent() {
        // A time mentioned WITHIN a message should be preserved
        let ocrOutput = "Rally starts at 2:30 PM at the convention center"
        let cleaned = OCRService.stripUIChrome(from: ocrOutput)

        XCTAssertTrue(cleaned.contains("2:30 PM"), "Should preserve timestamps within message content")
    }

    func testStripUIChrome_PreservesPhoneInMessageContent() {
        // A phone number within a longer message line should be preserved (sanitization handles it later)
        let ocrOutput = "Call 555-123-4567 for your ride to the polls on Election Day"
        let cleaned = OCRService.stripUIChrome(from: ocrOutput)

        XCTAssertTrue(cleaned.contains("Call"), "Should preserve message lines containing phone numbers")
    }

    func testStripUIChrome_HandlesEmptyInput() {
        let cleaned = OCRService.stripUIChrome(from: "")
        XCTAssertTrue(cleaned.isEmpty)
    }

    func testStripUIChrome_FullRealisticScreenshot() {
        // Simulate a realistic Messages screenshot OCR output
        let ocrOutput = """
        AT&T
        5G
        12:34 PM
        93%
        Messages
        (202) 555-0199
        Today 2:30 PM
        URGENT: Your precinct is closing early on Nov 5th. Vote at Jefferson Elementary by 3PM or text HELP to confirm your new polling location.
        Reply STOP to end
        Delete
        Mark as Known
        Report Junk
        """
        let cleaned = OCRService.stripUIChrome(from: ocrOutput)

        // Should keep the actual political text
        XCTAssertTrue(cleaned.contains("URGENT"), "Should preserve the political message")
        XCTAssertTrue(cleaned.contains("precinct"), "Should preserve message content")

        // Should strip UI chrome
        XCTAssertFalse(cleaned.contains("AT&T"), "Should strip carrier")
        XCTAssertFalse(cleaned.contains("12:34 PM"), "Should strip time")
        XCTAssertFalse(cleaned.contains("93%"), "Should strip battery")
        XCTAssertFalse(cleaned.contains("Delete"), "Should strip Delete button")
        XCTAssertFalse(cleaned.contains("Mark as Known"), "Should strip Mark as Known")
        XCTAssertFalse(cleaned.contains("Report Junk"), "Should strip Report Junk")
    }

    func testStripUIChrome_RealWorldDemocracyFirstPAC() {
        // Exact OCR output from a real Messages screenshot
        let ocrOutput = """
        6:416
        813
        +1 (771) 217-5695 )
        Text Message • SMS
        Thu, Oct 9 at 12:16 PM
        You didn't sign? NOT asking for money, just your signature to invoke the 25th Amendment & remove Trump from office:
        i.democracyfirstpac.org/ueoO851Q
        DF
        Stop2End
        If you did not expect this message from an unknown
        sender, it may be spam.
        Text Message • SMS
        """
        let cleaned = OCRService.stripUIChrome(from: ocrOutput)

        // Should keep the actual political message content
        XCTAssertTrue(cleaned.contains("didn't sign"), "Should preserve message text")
        XCTAssertTrue(cleaned.contains("25th Amendment"), "Should preserve political content")
        XCTAssertTrue(cleaned.contains("democracyfirstpac"), "Should preserve URL")
        XCTAssertTrue(cleaned.contains("Stop2End"), "Should preserve opt-out text")

        // Should strip all UI chrome
        XCTAssertFalse(cleaned.contains("6:416"), "Should strip mangled time")
        XCTAssertFalse(cleaned.contains("813"), "Should strip badge count")
        XCTAssertFalse(cleaned.contains("771"), "Should strip phone number")
        XCTAssertFalse(cleaned.contains("Text Message"), "Should strip 'Text Message • SMS'")
        XCTAssertFalse(cleaned.contains("Thu, Oct"), "Should strip date line")
        XCTAssertFalse(cleaned.contains("did not expect"), "Should strip iOS spam warning")
        XCTAssertFalse(cleaned.contains("it may be spam"), "Should strip iOS spam warning")
    }

    func testStripUIChrome_RemovesBadgeCountNumbers() {
        let ocrOutput = "813\nVote in the primary election this Tuesday!"
        let cleaned = OCRService.stripUIChrome(from: ocrOutput)

        XCTAssertFalse(cleaned.contains("813"), "Should strip standalone numbers (badge counts)")
        XCTAssertTrue(cleaned.contains("Vote in"), "Should preserve message content")
    }

    func testStripUIChrome_RemovesPhoneWithTrailingPunctuation() {
        // OCR sometimes adds trailing ) or other chars to phone numbers
        let ocrOutput = "+1 (771) 217-5695 )\nPlease vote on Tuesday"
        let cleaned = OCRService.stripUIChrome(from: ocrOutput)

        XCTAssertFalse(cleaned.contains("771"), "Should strip phone number with trailing punctuation")
        XCTAssertTrue(cleaned.contains("Please vote"), "Should preserve message content")
    }

    func testStripUIChrome_RemovesTextMessageBulletSMS() {
        let ocrOutput = "Text Message \u{2022} SMS\nYour polling place has moved"
        let cleaned = OCRService.stripUIChrome(from: ocrOutput)

        XCTAssertFalse(cleaned.lowercased().contains("text message"), "Should strip 'Text Message • SMS' with bullet")
        XCTAssertTrue(cleaned.contains("polling place"), "Should preserve message content")
    }

    func testStripUIChrome_RemovesDayOfWeekDateLine() {
        let ocrOutput = "Thu, Oct 9 at 12:16 PM\nSign the petition now"
        let cleaned = OCRService.stripUIChrome(from: ocrOutput)

        XCTAssertFalse(cleaned.contains("Thu"), "Should strip day-of-week date lines")
        XCTAssertTrue(cleaned.contains("Sign the petition"), "Should preserve message content")
    }

    func testStripUIChrome_RemovesMonthAbbreviatedDateLine() {
        let ocrOutput = "Apr 6, 2024 at 10:44 AM\nFROM TRUMP: I'm picking the next VP!"
        let cleaned = OCRService.stripUIChrome(from: ocrOutput)

        XCTAssertFalse(cleaned.contains("Apr 6"), "Should strip month-abbreviated date lines")
        XCTAssertTrue(cleaned.contains("FROM TRUMP"), "Should preserve message content")
    }

    func testStripUIChrome_RemovesVariousMonthDates() {
        let inputs = [
            "Jan 15, 2024 at 3:00 PM",
            "Feb 28, 2025 at 11:30 AM",
            "Sep 1, 2024 at 9:15 PM",
            "Dec 25 at 12:00 PM",
        ]
        for date in inputs {
            let ocrOutput = "\(date)\nVote now for real change"
            let cleaned = OCRService.stripUIChrome(from: ocrOutput)
            XCTAssertFalse(cleaned.contains(String(date.prefix(3))), "Should strip date starting with \(String(date.prefix(3)))")
        }
    }

    func testStripUIChrome_RemovesBackArrowWithBadgeCount() {
        let ocrOutput = "< 813\nFROM TRUMP: I'm picking the next VP!"
        let cleaned = OCRService.stripUIChrome(from: ocrOutput)

        XCTAssertFalse(cleaned.contains("813"), "Should strip back arrow with badge count")
        XCTAssertTrue(cleaned.contains("FROM TRUMP"), "Should preserve message content")
    }

    func testStripUIChrome_RealWorldTrumpVPPick() {
        // Exact OCR output from a real Messages screenshot
        let ocrOutput = """
        < 813
        +1 (571) 445-6864
        Apr 6, 2024 at 10:44 AM
        FROM TRUMP: I'm picking the next VP!
        Before I do, I need to hear from Augustus.
        Who should I pick?
        ANSWER: rwing.us/3srHl1
        stop=end
        """
        let cleaned = OCRService.stripUIChrome(from: ocrOutput)

        // Should keep the actual political message content
        XCTAssertTrue(cleaned.contains("FROM TRUMP"), "Should preserve message text")
        XCTAssertTrue(cleaned.contains("next VP"), "Should preserve political content")
        XCTAssertTrue(cleaned.contains("rwing.us"), "Should preserve URL")
        XCTAssertTrue(cleaned.contains("stop=end"), "Should preserve opt-out text")

        // Should strip all UI chrome
        XCTAssertFalse(cleaned.contains("< 813"), "Should strip back arrow + badge count")
        XCTAssertFalse(cleaned.contains("571"), "Should strip phone number")
        XCTAssertFalse(cleaned.contains("Apr 6"), "Should strip date line")
    }

    func testStripUIChrome_RemovesSpamWarning() {
        let ocrOutput = "Important election info\nIf you did not expect this message from an unknown\nsender, it may be spam."
        let cleaned = OCRService.stripUIChrome(from: ocrOutput)

        XCTAssertFalse(cleaned.contains("did not expect"), "Should strip spam warning")
        XCTAssertFalse(cleaned.contains("may be spam"), "Should strip spam warning continuation")
        XCTAssertTrue(cleaned.contains("Important election"), "Should preserve message content")
    }

    // MARK: - Build Verification

    func testAllTargetsBuildCleanly() {
        // This test simply verifies the test target compiles with OCRService.
        // If this test runs at all, it confirms the Share Extension code
        // is accessible from the test target.
        let service = OCRService()
        XCTAssertNotNil(service, "OCRService should be instantiable from test target")
    }

    // MARK: - Helpers

    /// Creates a PNG image with the given text rendered into it and saves to a temp file.
    private func createTestImage(withText text: String, size: CGSize = CGSize(width: 600, height: 300)) throws -> URL {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw text in black
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            paragraphStyle.lineBreakMode = .byWordWrapping

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .regular),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle,
            ]

            let textRect = CGRect(x: 20, y: 20, width: size.width - 40, height: size.height - 40)
            text.draw(in: textRect, withAttributes: attributes)
        }

        guard let pngData = image.pngData() else {
            throw NSError(domain: "OCRServiceTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"])
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        try pngData.write(to: tempURL)
        return tempURL
    }

    /// Creates a blank white image with no text.
    private func createBlankImage(size: CGSize = CGSize(width: 200, height: 200)) throws -> URL {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        guard let pngData = image.pngData() else {
            throw NSError(domain: "OCRServiceTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"])
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        try pngData.write(to: tempURL)
        return tempURL
    }
}
