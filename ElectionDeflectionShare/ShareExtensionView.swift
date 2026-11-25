import SwiftUI
import UniformTypeIdentifiers

struct ShareExtensionView: View {
    let extensionContext: NSExtensionContext?

    @State private var textContent = ""
    @State private var thumbnail: UIImage?
    @State private var isRecognizing = true
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var ocrError: String?
    @State private var contentWidth: CGFloat = 0

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.displayScale) private var displayScale

    private let ocrService = OCRService()
    private let submissionService = TextSubmissionService.shared

    var body: some View {
        ZStack {
            Color.brandNavy
                .edgesIgnoringSafeArea(.all)

            if showSuccess {
                successView
            } else {
                mainContent
            }
        }
        .task {
            await loadImageAndExtractText()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Navigation bar
            HStack {
                Button {
                    cancel()
                } label: {
                    Text("Cancel")
                        .foregroundColor(.white.opacity(0.7))
                }
                .disabled(isSubmitting)

                Spacer()

                Text("Submit Screenshot")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button {
                    submitText()
                } label: {
                    Text("Submit")
                        .fontWeight(.semibold)
                        .foregroundColor(canSubmit ? .orange : .white.opacity(0.3))
                }
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            scrollContent(
                mode: AdaptiveLayout.mode(
                    horizontalSizeClass: horizontalSizeClass,
                    availableWidth: contentWidth
                )
            )
            // Measured in the background so the single column gets exactly the
            // same width proposal as before (an in-flow GeometryReader rounds it).
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { contentWidth = proxy.size.width }
                        .onChange(of: proxy.size.width) { contentWidth = $0 }
                }
            )
        }
    }

    // MARK: - Scroll Content

    private func scrollContent(mode: AdaptiveLayoutMode) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Preview (thumbnail, OCR status/error) beside the editable text
                // when wide; stacked exactly as before otherwise.
                AdaptiveStack(mode: mode, spacing: 16) {
                    if hasPreviewContent {
                        previewColumn
                            .frame(maxWidth: mode == .twoColumn ? CGFloat.infinity : nil)
                    }

                    textColumn
                        .frame(maxWidth: mode == .twoColumn ? CGFloat.infinity : nil)
                }

                // Privacy disclosure
                privacyDisclosure

                // Error message
                if let error = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                }

                // Submit button
                Button {
                    submitText()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text(isSubmitting ? "Submitting..." : "Submit")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(canSubmit ? Color.orange : Color.white.opacity(0.2))
                    .cornerRadius(14)
                }
                .disabled(!canSubmit)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .padding(.top, 8)
            .readableWidth(AdaptiveLayout.readableMaxWidth * 2)
        }
    }

    private var hasPreviewContent: Bool {
        thumbnail != nil || isRecognizing || ocrError != nil
    }

    private var previewColumn: some View {
        VStack(spacing: 16) {
            // Image thumbnail
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 150)
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
            }

            // OCR status
            if isRecognizing {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.brandGold)
                    Text("Extracting text from image...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.vertical, 8)
            }

            // OCR error
            if let ocrError = ocrError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text(ocrError)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal, 20)
            }
        }
    }

    private var textColumn: some View {
        // Editable text area
        VStack(alignment: .leading, spacing: 8) {
            Text("Extracted Text")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white.opacity(0.6))

            TextEditor(text: $textContent)
                .frame(minHeight: 120)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(Color.white.opacity(0.1))
                .foregroundColor(.white)
                .cornerRadius(12)
                .overlay(
                    Group {
                        if textContent.isEmpty && !isRecognizing {
                            Text("No text extracted. You can type or paste text here...")
                                .foregroundColor(.white.opacity(0.3))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )

            HStack {
                if trimmedCount > 0 && trimmedCount < 20 {
                    Text("\(20 - trimmedCount) more characters needed")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
                Spacer()
                Text("\(textContent.count)/2000")
                    .font(.caption)
                    .foregroundColor(textContent.count > 2000 ? .red : .white.opacity(0.4))
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Privacy Disclosure

    private var privacyDisclosure: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                Text("Privacy Disclosure")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                disclosureRow(icon: "checkmark.circle.fill", color: .green,
                              text: "Only the text below will be sent")
                disclosureRow(icon: "xmark.circle.fill", color: .red,
                              text: "No personal info, device ID, or metadata")
                disclosureRow(icon: "checkmark.circle.fill", color: .green,
                              text: "Your filter still works 100% on-device")
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }

    private func disclosureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Thank You!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Your contribution helps improve filtering for everyone.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                complete()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.brandGold)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Logic

    private var trimmedCount: Int {
        textContent.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    private var canSubmit: Bool {
        !isSubmitting && !isRecognizing && trimmedCount >= 20 && textContent.count <= 2000
    }

    private func loadImageAndExtractText() async {
        guard let extensionContext = extensionContext,
              let inputItem = extensionContext.inputItems.first as? NSExtensionItem,
              let provider = inputItem.attachments?.first else {
            isRecognizing = false
            ocrError = "No image was shared. Please share a screenshot image."
            return
        }

        // Load image as file URL for memory efficiency
        do {
            let url = try await loadFileURL(from: provider)

            // Generate thumbnail on background thread
            if let thumb = OCRService.createThumbnail(from: url, scale: displayScale) {
                await MainActor.run {
                    self.thumbnail = thumb
                }
            }

            // Extract text
            let text = try await ocrService.recognizeText(from: url)
            await MainActor.run {
                self.textContent = text
                self.isRecognizing = false
            }

            // Clean up temp file
            try? FileManager.default.removeItem(at: url)
        } catch let error as OCRService.OCRError {
            await MainActor.run {
                self.ocrError = error.localizedDescription
                self.isRecognizing = false
            }
        } catch {
            await MainActor.run {
                self.ocrError = "Failed to load image: \(error.localizedDescription)"
                self.isRecognizing = false
            }
        }
    }

    private func loadFileURL(from provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let url = url else {
                    continuation.resume(throwing: OCRService.OCRError.recognitionFailed("No image URL available"))
                    return
                }

                // Copy to temp directory before the provider deallocates the original
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension)

                do {
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    continuation.resume(returning: tempURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func submitText() {
        guard canSubmit else { return }
        errorMessage = nil
        isSubmitting = true

        Task {
            do {
                try await submissionService.submitText(textContent)
                await MainActor.run {
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(
            domain: NSCocoaErrorDomain,
            code: NSUserCancelledError
        ))
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
