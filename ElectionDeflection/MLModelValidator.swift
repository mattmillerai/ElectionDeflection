import CoreML
import os.log

/// Validates ML model availability by attempting to load from the app bundle.
/// Used by the main app to detect degradation and update UI accordingly.
/// The extension does its own independent validation — these don't need to agree.
enum MLModelValidator {

    private static let logger = Logger(
        subsystem: "com.millermedia.ElectionDeflection",
        category: "MLModelValidator"
    )

    /// Attempts to load the PoliticalTextClassifier model from the given bundle.
    /// Returns `true` if the model loads successfully, `false` otherwise.
    static func isMLModelAvailable(in bundle: Bundle = .main) -> Bool {
        guard let modelURL = bundle.url(forResource: "PoliticalTextClassifier", withExtension: "mlmodelc") else {
            logger.error("PoliticalTextClassifier.mlmodelc not found in bundle")
            return false
        }

        let config = MLModelConfiguration()
        config.computeUnits = .cpuOnly

        do {
            _ = try MLModel(contentsOf: modelURL, configuration: config)
            return true
        } catch {
            logger.error("ML model failed to load: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Validates ML model and updates SharedDataManager properties accordingly.
    /// Call on app launch and foreground to keep UI in sync with model availability.
    /// ML filtering requires both Pro tier AND a loadable model.
    static func validateAndSync(using dataManager: SharedDataManager = .shared, in bundle: Bundle = .main) {
        let available = isMLModelAvailable(in: bundle)
        let isProTier = dataManager.isProTier
        // isMLModelEnabled reflects model HEALTH (drives the degradation banner) and
        // stays true even if a Pro user opts into keyword-only. filterMethod reflects
        // what will actually run, which the keyword preference can override.
        let useML = available && isProTier && !dataManager.preferKeywordFiltering

        dataManager.isMLModelEnabled = available && isProTier
        dataManager.filterMethod = useML
            ? SharedConstants.filterMethodML
            : SharedConstants.filterMethodKeyword
    }
}
