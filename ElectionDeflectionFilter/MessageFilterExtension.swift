import IdentityLookup
import CoreML
import os.log
import Foundation

private let logger = Logger(subsystem: "com.millermedia.ElectionDeflection.ElectionDeflectionFilter", category: "MessageFilter")

// NSLog wrapper for reliable idevicesyslog visibility
private func filterLog(_ message: String) {
    NSLog("[EDFilter] %@", message)
    logger.notice("\(message, privacy: .public)")
}

final class MessageFilterExtension: ILMessageFilterExtension {
    // Filter data loaded from SharedDataManager (seeded from DefaultFilterData on first access)
    var keywords: [String] = []
    var whitelistContexts: [String: [String]] = [:]
    var combinedTerms: [[String]] = []
    private var keywordEngine = KeywordFilterEngine(keywords: [], whitelistContexts: [:], combinedTerms: [])

    // MARK: - Core ML Text Classifier
    private var mlModel: MLModel?

    override init() {
        super.init()
        // NOTE: seedDefaultFilterDataIfNeeded() writes are silently blocked by the
        // ILMessageFilterExtension sandbox — data is only seeded/refreshed by the main
        // app. So read SharedDataManager.effectiveFilterData(), which falls back to
        // DefaultFilterData whenever the shared container's copy is empty OR stale
        // (e.g. before the main app has ever been opened, or after a filter-data update
        // the main app hasn't re-launched to pick up since — see issue #3), so the
        // extension always filters with the current data instead of a stale or empty one.
        SharedDataManager.shared.seedDefaultFilterDataIfNeeded()
        let effective = SharedDataManager.shared.effectiveFilterData()
        self.keywords = effective.keywords
        self.whitelistContexts = effective.whitelistContexts
        self.combinedTerms = effective.combinedTerms
        self.keywordEngine = KeywordFilterEngine(
            keywords: effective.keywords,
            whitelistContexts: effective.whitelistContexts,
            combinedTerms: effective.combinedTerms
        )
        filterLog("MessageFilterExtension initialized")
        filterLog("Loaded keywords: \(self.keywords.count) keywords")
        filterLog("Loaded whitelist contexts: \(self.whitelistContexts.count) contexts")
        filterLog("Loaded combined terms: \(self.combinedTerms.count) combinations")

        // Load ML model
        loadMLModel()
    }

    // MARK: - Core ML Model Loading

    private func loadMLModel() {
        guard let modelURL = Bundle.main.url(forResource: "PoliticalTextClassifier", withExtension: "mlmodelc") else {
            filterLog("ML Model file not found in bundle — falling back to keyword filtering")
            return
        }

        let config = MLModelConfiguration()
        config.computeUnits = .cpuOnly

        let loadStart = CFAbsoluteTimeGetCurrent()
        do {
            mlModel = try MLModel(contentsOf: modelURL, configuration: config)
            let elapsed = (CFAbsoluteTimeGetCurrent() - loadStart) * 1000
            filterLog("ML Model loaded in \(String(format: "%.2f", elapsed))ms")
        } catch {
            filterLog("ML Model failed to load: \(error.localizedDescription) — falling back to keyword filtering")
        }
    }

    // MARK: - Core ML Inference

    private func classifyWithML(_ messageBody: String) -> String? {
        guard let model = mlModel else { return nil }

        let provider = try? MLDictionaryFeatureProvider(dictionary: [
            "text": MLFeatureValue(string: messageBody)
        ])
        guard let input = provider else { return nil }

        let start = CFAbsoluteTimeGetCurrent()
        do {
            let prediction = try model.prediction(from: input)
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

            let label = prediction.featureValue(for: "label")?.stringValue ?? "unknown"
            filterLog("ML: \(label) in \(String(format: "%.2f", elapsed))ms")
            return label
        } catch {
            filterLog("ML inference failed: \(error.localizedDescription) — falling back to keyword filtering")
            return nil
        }
    }

    // MARK: - Keyword Filtering

    private func determineAction(for messageBody: String) -> ILMessageFilterAction {
        filterLog("Evaluating message (\(messageBody.count) chars)")

        // Run ML inference (log result for comparison, used as primary if available)
        let mlResult = classifyWithML(messageBody)

        // Run keyword filter
        let keywordAction = keywordFilter(for: messageBody)

        // Log comparison
        let keywordLabel = keywordAction == .junk ? "political" : "not_political"
        let mlLabel = mlResult ?? "n/a"
        let agree = (keywordLabel == mlLabel) ? "AGREE" : "DISAGREE"
        filterLog("Keyword: \(keywordLabel) | ML: \(mlLabel) | \(agree)")

        // Pro tier: use ML result if available, unless the user opted into
        // keyword-only. Free tier: keyword only.
        let isProTier = SharedDataManager.shared.isProTier
        let preferKeyword = SharedDataManager.shared.preferKeywordFiltering
        if isProTier, !preferKeyword, let label = mlResult {
            filterLog("Pro tier — using ML classification")
            return label == "political" ? .junk : .allow
        }
        if isProTier, preferKeyword {
            filterLog("Pro tier — user chose keyword classification")
        } else if !isProTier {
            filterLog("Free tier — using keyword classification")
        }
        return keywordAction
    }

    private func keywordFilter(for messageBody: String) -> ILMessageFilterAction {
        keywordEngine.isPolitical(messageBody) ? .junk : .allow
    }
}

extension MessageFilterExtension: ILMessageFilterQueryHandling {
    @available(iOS 16.0, *)
    func handle(_ capabilitiesQueryRequest: ILMessageFilterCapabilitiesQueryRequest, context: ILMessageFilterExtensionContext, completion: @escaping (ILMessageFilterCapabilitiesQueryResponse) -> Void) {
        let response = ILMessageFilterCapabilitiesQueryResponse()
        response.promotionalSubActions = []
        response.transactionalSubActions = []
        logger.notice("iOS 16+ Capabilities query handled - Extension is ACTIVE")
        completion(response)
    }

    func handle(_ queryRequest: ILMessageFilterQueryRequest, context: ILMessageFilterExtensionContext, completion: @escaping (ILMessageFilterQueryResponse) -> Void) {
        let response = ILMessageFilterQueryResponse()

        guard SharedDataManager.shared.isFilterEnabled else {
            logger.notice("Filtering is disabled, allowing message")
            response.action = .allow
            completion(response)
            return
        }

        if let messageBody = queryRequest.messageBody {
            let startTime = CFAbsoluteTimeGetCurrent()
            response.action = determineAction(for: messageBody)
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            logger.notice("Filter decision took \(String(format: "%.2f", elapsed), privacy: .public)ms")

            if response.action == .junk {
                SharedDataManager.shared.incrementTextsBlockedCount()
            }
        } else {
            logger.notice("No message body found.")
            response.action = .allow
        }

        let actionDescription: String
        switch response.action {
        case .allow:
            actionDescription = "Allow (goes to Messages inbox)"
        case .junk:
            actionDescription = "Junk (goes to Spam folder)"
        case .filter:
            actionDescription = "Filter (goes to Unknown Senders)"
        case .promotion:
            actionDescription = "Promotion (goes to Promotions folder)"
        case .transaction:
            actionDescription = "Transaction (goes to Transactions folder)"
        case .none:
            actionDescription = "None"
        @unknown default:
            actionDescription = "Unknown action"
        }

        filterLog("Action: \(actionDescription)")
        completion(response)
    }
}
