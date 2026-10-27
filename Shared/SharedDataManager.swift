import Foundation
import os.log

/// Centralized read/write access to the App Group shared storage.
/// Used by both the main app and the MessageFilter extension.
/// All storage is local — no networking is performed.
///
/// NOTE: ILMessageFilterExtension has an extremely restrictive sandbox that blocks
/// ALL write operations (UserDefaults, file I/O, Keychain, Darwin notifications).
/// Properties written by the extension (e.g. textsBlockedCount) will only persist
/// in-memory for the extension's process lifetime. Only the main app can persist data.
final class SharedDataManager {

    static let shared = SharedDataManager()

    private let defaults: UserDefaults?
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.millermedia.electiondeflection.sharedDataManager", qos: .utility)
    private let logger = Logger(subsystem: "com.millermedia.ElectionDeflection", category: "SharedDataManager")

    init(defaults: UserDefaults? = UserDefaults(suiteName: SharedConstants.appGroupIdentifier),
         fileManager: FileManager = .default) {
        self.defaults = defaults
        self.fileManager = fileManager
        applyFileProtection()
    }

    // MARK: - File Protection

    /// Ensures the shared container directory uses CompleteUntilFirstUserAuthentication protection.
    /// This encrypts data at rest while remaining accessible after first unlock (required for
    /// the extension to read filter settings when messages arrive on a locked device).
    private func applyFileProtection() {
        guard let containerURL = sharedContainerURL else { return }
        do {
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: containerURL.path
            )
        } catch {
            logger.error("Failed to apply file protection to shared container: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Container URL

    var sharedContainerURL: URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.appGroupIdentifier)
    }

    // MARK: - Onboarding State
    // NOTE: Setter writes are blocked by the ILMessageFilterExtension sandbox.
    // This property can only be written from the main app.

    var hasCompletedOnboarding: Bool {
        get { defaults?.bool(forKey: SharedConstants.hasCompletedOnboardingKey) ?? SharedConstants.defaultHasCompletedOnboarding }
        set { defaults?.set(newValue, forKey: SharedConstants.hasCompletedOnboardingKey) }
    }

    // MARK: - Filter Enabled

    var isFilterEnabled: Bool {
        get { defaults?.object(forKey: SharedConstants.filterEnabledKey) as? Bool ?? SharedConstants.defaultFilterEnabled }
        set { defaults?.set(newValue, forKey: SharedConstants.filterEnabledKey) }
    }

    // MARK: - Pro Tier Status

    var isProTier: Bool {
        get { defaults?.bool(forKey: SharedConstants.proTierStatusKey) ?? SharedConstants.defaultProTierStatus }
        set { defaults?.set(newValue, forKey: SharedConstants.proTierStatusKey) }
    }

    // MARK: - ML Model Enabled

    var isMLModelEnabled: Bool {
        get { defaults?.object(forKey: SharedConstants.mlModelEnabledKey) as? Bool ?? SharedConstants.defaultMLModelEnabled }
        set { defaults?.set(newValue, forKey: SharedConstants.mlModelEnabledKey) }
    }

    // MARK: - Texts Blocked Count
    // NOTE: The extension calls incrementTextsBlockedCount() but the write is blocked
    // by the ILMessageFilterExtension sandbox. This counter can only be updated from
    // the main app. See extension-sandbox.md in project memory for details.

    var textsBlockedCount: Int {
        get { defaults?.integer(forKey: SharedConstants.textsBlockedCountKey) ?? SharedConstants.defaultTextsBlockedCount }
        set { defaults?.set(newValue, forKey: SharedConstants.textsBlockedCountKey) }
    }

    // NOTE: Uses queue.sync intentionally to ensure the count is updated atomically
    // before returning. In the extension, the write is silently blocked by the sandbox
    // anyway, so the sync overhead is negligible.
    func incrementTextsBlockedCount() {
        queue.sync {
            let current = defaults?.integer(forKey: SharedConstants.textsBlockedCountKey) ?? 0
            defaults?.set(current + 1, forKey: SharedConstants.textsBlockedCountKey)
        }
    }

    // MARK: - Filter Method

    var filterMethod: String {
        get { defaults?.string(forKey: SharedConstants.filterMethodKey) ?? SharedConstants.defaultFilterMethod }
        set { defaults?.set(newValue, forKey: SharedConstants.filterMethodKey) }
    }

    // MARK: - V1 Purchaser

    var isV1Purchaser: Bool {
        get { defaults?.bool(forKey: SharedConstants.v1PurchaserKey) ?? SharedConstants.defaultIsV1Purchaser }
        set { defaults?.set(newValue, forKey: SharedConstants.v1PurchaserKey) }
    }

    // MARK: - Onboarding Completed Date (main app only)

    var onboardingCompletedDate: Date? {
        get { defaults?.object(forKey: SharedConstants.onboardingCompletedDateKey) as? Date }
        set { defaults?.set(newValue, forKey: SharedConstants.onboardingCompletedDateKey) }
    }

    // MARK: - Upgrade Prompt Seen (main app only)

    var hasSeenUpgradePrompt: Bool {
        get { defaults?.bool(forKey: SharedConstants.hasSeenUpgradePromptKey) ?? false }
        set { defaults?.set(newValue, forKey: SharedConstants.hasSeenUpgradePromptKey) }
    }

    // MARK: - V2 Welcome Seen (main app only)

    var hasSeenV2Welcome: Bool {
        get { defaults?.bool(forKey: SharedConstants.hasSeenV2WelcomeKey) ?? false }
        set { defaults?.set(newValue, forKey: SharedConstants.hasSeenV2WelcomeKey) }
    }

    // MARK: - Keyword List

    var keywordList: [String] {
        get { defaults?.stringArray(forKey: SharedConstants.keywordListKey) ?? [] }
        set { defaults?.set(newValue, forKey: SharedConstants.keywordListKey) }
    }

    // MARK: - Whitelist Contexts

    var whitelistContexts: [String: [String]] {
        get { defaults?.dictionary(forKey: SharedConstants.whitelistContextsKey) as? [String: [String]] ?? [:] }
        set { defaults?.set(newValue, forKey: SharedConstants.whitelistContextsKey) }
    }

    // MARK: - Combined Terms

    var combinedTerms: [[String]] {
        get { (defaults?.array(forKey: SharedConstants.combinedTermsKey) as? [[String]]) ?? [] }
        set { defaults?.set(newValue, forKey: SharedConstants.combinedTermsKey) }
    }

    // MARK: - Prefer Keyword Filtering (Pro users may opt out of AI)

    var preferKeywordFiltering: Bool {
        get { defaults?.object(forKey: SharedConstants.preferKeywordFilteringKey) as? Bool ?? SharedConstants.defaultPreferKeywordFiltering }
        set { defaults?.set(newValue, forKey: SharedConstants.preferKeywordFilteringKey) }
    }

    // MARK: - Filter Data Fingerprint

    /// DefaultFilterData.fingerprint as of the last successful seed. Compared against
    /// the current DefaultFilterData.fingerprint to detect when the bundled defaults
    /// (e.g. a new keyword) have changed since and the stored copy is stale.
    var filterDataFingerprint: String? {
        get { defaults?.string(forKey: SharedConstants.filterDataFingerprintKey) }
        set { defaults?.set(newValue, forKey: SharedConstants.filterDataFingerprintKey) }
    }

    // MARK: - Seed / Refresh Default Filter Data

    /// Seeds shared filter data from DefaultFilterData on first access, and reseeds it
    /// whenever the bundled defaults have changed since the last seed (fingerprint
    /// mismatch) — e.g. when a filter-data update ships a new keyword like "stop=end"
    /// (issue #3). Without this, a user who first ran the app before such an update
    /// would keep their original seeded copy forever.
    func seedDefaultFilterDataIfNeeded() {
        guard keywordList.isEmpty || filterDataFingerprint != DefaultFilterData.fingerprint else { return }
        keywordList = DefaultFilterData.keywords
        whitelistContexts = DefaultFilterData.whitelistContexts
        combinedTerms = DefaultFilterData.combinedTerms
        filterDataFingerprint = DefaultFilterData.fingerprint
    }

    /// The filter data callers should actually use: the stored copy when it's present
    /// and current (fingerprint matches), otherwise the bundled DefaultFilterData.
    ///
    /// This exists because seedDefaultFilterDataIfNeeded()'s writes are silently blocked
    /// by the ILMessageFilterExtension sandbox (see the NOTE at the top of this file) — the
    /// extension and FilterAuditClassifier can call seed, but if it can't actually write
    /// (extension) or hasn't run yet (app not opened since a data update), the stored
    /// copy may be empty or stale. Falling back here, not just when a list is empty,
    /// is what fixes issue #3.
    func effectiveFilterData() -> (keywords: [String], whitelistContexts: [String: [String]], combinedTerms: [[String]]) {
        guard !keywordList.isEmpty, filterDataFingerprint == DefaultFilterData.fingerprint else {
            return (DefaultFilterData.keywords, DefaultFilterData.whitelistContexts, DefaultFilterData.combinedTerms)
        }
        return (keywordList, whitelistContexts, combinedTerms)
    }
}
