import SwiftUI
import CoreML

// MARK: - Audit entry

/// One recorded filter self-test. This is a log of audits the USER ran on their own
/// device — not a log of intercepted messages (the ILMessageFilterExtension sandbox
/// makes real per-message capture impossible; see SharedDataManager notes). Stored
/// locally only; nothing leaves the device.
struct AuditEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let input: String
    let mlLabel: String?        // "political" / "not_political" / nil when model unavailable
    let mlConfidence: Double?   // probability of the predicted label, 0...1
    let keywordPolitical: Bool
    let activeMethod: String    // SharedConstants.filterMethodML / .filterMethodKeyword
    let activePolitical: Bool   // the decision the real filter would make for this user

    init(id: UUID = UUID(), date: Date = Date(), input: String, mlLabel: String?,
         mlConfidence: Double?, keywordPolitical: Bool, activeMethod: String, activePolitical: Bool) {
        self.id = id
        self.date = date
        self.input = input
        self.mlLabel = mlLabel
        self.mlConfidence = mlConfidence
        self.keywordPolitical = keywordPolitical
        self.activeMethod = activeMethod
        self.activePolitical = activePolitical
    }
}

// MARK: - Audit log store (local, app-owned)

/// Persists the user's audit history to the app's own storage. Unlike App Group data,
/// the app has full read/write here, so this is real, durable data the user can revisit.
final class AuditLogStore: ObservableObject {
    @Published private(set) var entries: [AuditEntry] = []

    private let key = "auditLogEntries"
    private let maxEntries = 100
    private let defaults = UserDefaults.standard

    init() { load() }

    func add(_ entry: AuditEntry) {
        entries.insert(entry, at: 0)
        if entries.count > maxEntries { entries = Array(entries.prefix(maxEntries)) }
        save()
    }

    func remove(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    func clear() {
        entries = []
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([AuditEntry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }
}

// MARK: - Classifier

struct AuditResult {
    let mlLabel: String?
    let mlConfidence: Double?
    let mlMilliseconds: Double?
    let keywordPolitical: Bool
    let modelAvailable: Bool
}

/// Runs the SAME classification the MessageFilterExtension runs: the identical bundled
/// Core ML model with the identical `text` input feature, plus the same keyword data
/// via the shared `KeywordFilterEngine` (Shared/DefaultFilterData.swift) — both
/// MessageFilterExtension and this classifier delegate to that one implementation, so
/// their decisions can't drift apart.
final class FilterAuditClassifier {
    static let shared = FilterAuditClassifier()

    private var model: MLModel?
    private let keywordEngine: KeywordFilterEngine
    private(set) var modelAvailable = false

    init() {
        // Mirror the extension's init: refresh stale shared data, then read the
        // effective filter data, which falls back to DefaultFilterData when the shared
        // copy is empty or stale (e.g. before the app ever seeded it, or after a
        // filter-data update — see issue #3).
        SharedDataManager.shared.seedDefaultFilterDataIfNeeded()
        let effective = SharedDataManager.shared.effectiveFilterData()
        keywordEngine = KeywordFilterEngine(
            keywords: effective.keywords,
            whitelistContexts: effective.whitelistContexts,
            combinedTerms: effective.combinedTerms
        )
        loadModel()
    }

    private func loadModel() {
        guard let url = Bundle.main.url(forResource: "PoliticalTextClassifier", withExtension: "mlmodelc") else { return }
        let config = MLModelConfiguration()
        config.computeUnits = .cpuOnly
        model = try? MLModel(contentsOf: url, configuration: config)
        modelAvailable = (model != nil)
    }

    func classify(_ text: String) -> AuditResult {
        let (label, confidence, ms) = classifyML(text)
        return AuditResult(
            mlLabel: label,
            mlConfidence: confidence,
            mlMilliseconds: ms,
            keywordPolitical: keywordPolitical(text),
            modelAvailable: modelAvailable
        )
    }

    private func classifyML(_ text: String) -> (String?, Double?, Double?) {
        guard let model,
              let provider = try? MLDictionaryFeatureProvider(dictionary: ["text": MLFeatureValue(string: text)])
        else { return (nil, nil, nil) }

        let start = CFAbsoluteTimeGetCurrent()
        guard let prediction = try? model.prediction(from: provider) else { return (nil, nil, nil) }
        let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000

        let label = prediction.featureValue(for: "label")?.stringValue

        // The class-probability dictionary feature name varies by model; find it by type
        // rather than hardcoding, then read the predicted label's probability.
        var confidence: Double?
        if let label {
            for name in prediction.featureNames {
                if let dict = prediction.featureValue(for: name)?.dictionaryValue as? [String: NSNumber],
                   let p = dict[label] {
                    confidence = p.doubleValue
                    break
                }
            }
        }
        return (label, confidence, ms)
    }

    private func keywordPolitical(_ body: String) -> Bool {
        keywordEngine.isPolitical(body)
    }
}

// MARK: - View

struct AuditLogView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var storeService = StoreKitService.shared
    @StateObject private var store = AuditLogStore()

    @State private var input = ""
    @State private var lastResult: AuditResult?
    @State private var showDetails = false
    @State private var showTester = true
    @State private var resultToken = 0
    @FocusState private var inputFocused: Bool

    private let samples: [String] = [
        "URGENT: The FEC deadline is TONIGHT. Chip in $10 to protect our majority before midnight!",
        "Your Amazon package was delivered to the front door. Track: amzn.to/3xK9mP2"
    ]

    private var navy: Color { storeService.isProTier ? .proNavy : .brandNavy }

    var body: some View {
        ZStack {
            navy.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                header
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 24) {
                            statusSection
                            testSection
                            logSection
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                    .onChange(of: resultToken) { _ in
                        withAnimation { proxy.scrollTo("auditResult", anchor: .center) }
                    }
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Close")
            Spacer()
            Text("Test the Filter")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: Live status

    private var statusSection: some View {
        section("Current status") {
            VStack(spacing: 0) {
                statusRow("Filter",
                          value: SharedDataManager.shared.isFilterEnabled ? "On" : "Off",
                          systemImage: SharedDataManager.shared.isFilterEnabled ? "checkmark.circle.fill" : "xmark.circle")
                divider
                statusRow("Method",
                          value: activeMethodIsML ? "AI model" : "Keywords",
                          systemImage: activeMethodIsML ? "brain" : "text.magnifyingglass")
                divider
                statusRow("Model",
                          value: FilterAuditClassifier.shared.modelAvailable ? "Loaded" : "Unavailable",
                          systemImage: FilterAuditClassifier.shared.modelAvailable ? "checkmark.seal.fill" : "exclamationmark.triangle")
                divider
                statusRow("Tier",
                          value: storeService.isProTier ? "Pro" : "Free",
                          systemImage: storeService.isProTier ? "star.fill" : "person")
            }
        }
    }

    private func statusRow(_ label: String, value: String, systemImage: String) -> some View {
        HStack {
            Text(label).foregroundColor(.white)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(value)
            }
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: Test input

    private var testSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
                // Collapsed header — keeps the log the star of the screen
                Button {
                    withAnimation { showTester.toggle() }
                    if !showTester { inputFocused = false }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "text.badge.checkmark")
                            .foregroundColor(.brandGold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Test a message")
                                .foregroundColor(.white)
                            Text("Check how the filter classifies any text")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                        Image(systemName: showTester ? "chevron.up" : "chevron.down")
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(16)
                }
                .accessibilityLabel(showTester ? "Hide message tester" : "Show message tester")

                if showTester {
                    divider
                    testerBody
                }
            }
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
    }

    private var testerBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste or type a text message to see how the filter classifies it — the same on-device model and rules used on your incoming messages.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))

                ZStack(alignment: .topLeading) {
                    if input.isEmpty {
                        Text("Type or paste a message…")
                            .foregroundColor(.white.opacity(0.35))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                    }
                    TextEditor(text: $input)
                        .focused($inputFocused)
                        .frame(minHeight: 90)
                        .padding(6)
                        .scrollContentBackground(.hidden)
                        .foregroundColor(.white)
                }
                .background(Color.black.opacity(0.25))
                .cornerRadius(10)

                // Sample chips
                VStack(alignment: .leading, spacing: 8) {
                    Text("Or try a sample:")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                    ForEach(samples, id: \.self) { sample in
                        Button {
                            input = sample
                            inputFocused = false
                        } label: {
                            Text(sample)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(8)
                        }
                    }
                }

                Button {
                    runAudit()
                } label: {
                    Text("Test message")
                        .fontWeight(.semibold)
                        .foregroundColor(navy)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.3) : Color.brandGold)
                        .cornerRadius(10)
                }
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Test the entered message")

                // Result shows directly beneath the button that produced it
                if let result = lastResult {
                    Divider().background(Color.white.opacity(0.15)).padding(.vertical, 4)
                    resultContent(result).id("auditResult")
                }
            }
            .padding(16)
    }

    // MARK: Result

    private func resultContent(_ result: AuditResult) -> some View {
        let filtered = activeDecision(result)
        return VStack(alignment: .leading, spacing: 16) {
                // One plain-language verdict for the user's own filter
                HStack(spacing: 12) {
                    Image(systemName: filtered ? "xmark.shield.fill" : "checkmark.shield.fill")
                        .foregroundColor(filtered ? .brandGold : .green)
                        .font(.system(size: 34))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(filtered ? "Would be filtered" : "Would reach your inbox")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(verdictSubtitle(result))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Confidence bar — only when the AI model actually made the call
                if activeMethodIsML, let c = result.mlConfidence {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Confidence")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("\(Int((c * 100).rounded()))%")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundColor(.white.opacity(0.85))
                        }
                        ProgressView(value: c)
                            .progressViewStyle(.linear)
                            .tint(.brandGold)
                    }
                }

                // Two-engine breakdown moved out of the default view — opt-in for the curious
                DisclosureGroup(isExpanded: $showDetails) {
                    VStack(alignment: .leading, spacing: 8) {
                        detailRow("On-device AI model",
                                  detail: result.mlLabel.map { labelText($0) } ?? "Unavailable",
                                  confidence: result.mlConfidence)
                        detailRow("Keyword rules",
                                  detail: labelText(result.keywordPolitical ? "political" : "not_political"),
                                  confidence: nil)
                        Text(methodExplanation)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)
                } label: {
                    Text("How this was decided")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .tint(.white.opacity(0.6))
            }
    }

    private func verdictSubtitle(_ result: AuditResult) -> String {
        let filtered = activeDecision(result)
        if activeMethodIsML {
            return filtered
                ? "The on-device AI model classified this as a political message."
                : "The on-device AI model didn't consider this political."
        }
        return filtered
            ? "Matched a political keyword rule. Pro adds smarter AI filtering."
            : "No political keywords matched. Pro adds smarter AI filtering."
    }

    private var methodExplanation: String {
        activeMethodIsML
            ? "Your Pro filter uses the AI model. The keyword result is shown only for comparison."
            : "Your free filter uses keyword rules. The AI model result (included with Pro) is shown for comparison."
    }

    private func detailRow(_ label: String, detail: String, confidence: Double?) -> some View {
        HStack {
            Text(label).foregroundColor(.white.opacity(0.85))
            Spacer()
            HStack(spacing: 6) {
                Text(detail)
                if let c = confidence {
                    Text("(\(Int((c * 100).rounded()))%)")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.75))
        }
    }

    // MARK: Log

    private var logSection: some View {
        section("Recent tests") {
            VStack(spacing: 0) {
                // Make it unmistakable this is a test history, not a feed of real texts
                Text("A history of messages you've tested here — not your received texts. iOS doesn't let the filter report actual intercepted messages back to the app.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)

                if store.entries.isEmpty {
                    divider
                    Text("Messages you test will appear here.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                } else {
                    divider
                    ForEach(store.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: entry.activePolitical ? "xmark.shield.fill" : "checkmark.shield.fill")
                                    .foregroundColor(entry.activePolitical ? .brandGold : .green)
                                    .font(.caption)
                                Text(entry.activePolitical ? "Filtered" : "Allowed")
                                    .font(.caption).fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Spacer()
                                Text(entry.date, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            Text(entry.input)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12)
                        if entry.id != store.entries.last?.id { divider }
                    }
                    divider
                    Button(role: .destructive) {
                        store.clear()
                    } label: {
                        Text("Clear history")
                            .font(.subheadline)
                            .foregroundColor(.red.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(14)
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private var activeMethodIsML: Bool {
        storeService.isProTier
            && FilterAuditClassifier.shared.modelAvailable
            && !SharedDataManager.shared.preferKeywordFiltering
    }

    private func activeDecision(_ result: AuditResult) -> Bool {
        if activeMethodIsML, let ml = result.mlLabel {
            return ml == "political"
        }
        return result.keywordPolitical
    }

    private func labelText(_ label: String) -> String {
        label == "political" ? "Political" : "Not political"
    }

    private func runAudit() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputFocused = false
        let result = FilterAuditClassifier.shared.classify(text)
        lastResult = result

        let active = activeDecision(result)
        store.add(AuditEntry(
            input: text,
            mlLabel: result.mlLabel,
            mlConfidence: result.mlConfidence,
            keywordPolitical: result.keywordPolitical,
            activeMethod: activeMethodIsML ? SharedConstants.filterMethodML : SharedConstants.filterMethodKeyword,
            activePolitical: active
        ))
        resultToken += 1  // triggers scroll-to-result in the ScrollViewReader
    }

    private var divider: some View {
        Divider().background(Color.white.opacity(0.15))
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 4)
            content()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
        }
        .padding(.horizontal, 20)
    }
}
