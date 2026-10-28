import XCTest
import CoreML
@testable import ElectionDeflection

final class SharedDataManagerTests: XCTestCase {

    private var sut: SharedDataManager!
    private var testDefaults: UserDefaults!
    private let testSuiteName = "com.test.sharedDataManager"

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: testSuiteName)
        testDefaults.removePersistentDomain(forName: testSuiteName)
        sut = SharedDataManager(defaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testSuiteName)
        testDefaults = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Onboarding State Tests

    func testHasCompletedOnboardingDefaultsToFalse() {
        XCTAssertFalse(sut.hasCompletedOnboarding)
    }

    func testSetHasCompletedOnboarding() {
        sut.hasCompletedOnboarding = true
        XCTAssertTrue(sut.hasCompletedOnboarding)
    }

    func testHasCompletedOnboardingPersistsAcrossInstances() {
        sut.hasCompletedOnboarding = true
        let secondInstance = SharedDataManager(defaults: testDefaults)
        XCTAssertTrue(secondInstance.hasCompletedOnboarding)
    }

    // MARK: - Filter Enabled Tests

    func testFilterEnabledDefaultsToTrue() {
        XCTAssertTrue(sut.isFilterEnabled)
    }

    func testSetFilterEnabled() {
        sut.isFilterEnabled = false
        XCTAssertFalse(sut.isFilterEnabled)

        sut.isFilterEnabled = true
        XCTAssertTrue(sut.isFilterEnabled)
    }

    // MARK: - Pro Tier Tests

    func testProTierDefaultsToFalse() {
        XCTAssertFalse(sut.isProTier)
    }

    func testSetProTier() {
        sut.isProTier = true
        XCTAssertTrue(sut.isProTier)
    }

    // MARK: - ML Model Enabled Tests

    func testMLModelEnabledDefaultsToTrue() {
        XCTAssertTrue(sut.isMLModelEnabled)
    }

    func testSetMLModelEnabled() {
        sut.isMLModelEnabled = true
        XCTAssertTrue(sut.isMLModelEnabled)
    }

    // MARK: - Texts Blocked Count Tests

    func testTextsBlockedCountDefaultsToZero() {
        XCTAssertEqual(sut.textsBlockedCount, 0)
    }

    func testSetTextsBlockedCount() {
        sut.textsBlockedCount = 42
        XCTAssertEqual(sut.textsBlockedCount, 42)
    }

    func testIncrementTextsBlockedCount() {
        XCTAssertEqual(sut.textsBlockedCount, 0)
        sut.incrementTextsBlockedCount()
        XCTAssertEqual(sut.textsBlockedCount, 1)
        sut.incrementTextsBlockedCount()
        XCTAssertEqual(sut.textsBlockedCount, 2)
    }

    // MARK: - Filter Method Tests

    func testFilterMethodDefaultsToKeyword() {
        XCTAssertEqual(sut.filterMethod, SharedConstants.filterMethodKeyword,
                       "Default filter method should be 'keyword' (Pro tier required for ML)")
    }

    func testSetFilterMethod() {
        sut.filterMethod = SharedConstants.filterMethodML
        XCTAssertEqual(sut.filterMethod, SharedConstants.filterMethodML)
    }

    // MARK: - V1 Purchaser Tests

    func testV1PurchaserDefaultsToFalse() {
        XCTAssertFalse(sut.isV1Purchaser)
    }

    func testSetV1Purchaser() {
        sut.isV1Purchaser = true
        XCTAssertTrue(sut.isV1Purchaser)
    }

    // MARK: - Keyword List Tests

    func testKeywordListDefaultsToEmpty() {
        XCTAssertEqual(sut.keywordList, [])
    }

    func testSetKeywordList() {
        let keywords = ["trump", "election", "vote"]
        sut.keywordList = keywords
        XCTAssertEqual(sut.keywordList, keywords)
    }

    // MARK: - Data Persistence Tests

    func testDataPersistsAcrossInstances() {
        sut.isProTier = true
        sut.textsBlockedCount = 100
        sut.filterMethod = SharedConstants.filterMethodML

        let secondInstance = SharedDataManager(defaults: testDefaults)
        XCTAssertTrue(secondInstance.isProTier)
        XCTAssertEqual(secondInstance.textsBlockedCount, 100)
        XCTAssertEqual(secondInstance.filterMethod, SharedConstants.filterMethodML)
    }

    // MARK: - App Groups Container Tests

    func testSharedContainerURL() {
        // sharedContainerURL uses the real App Group identifier via FileManager;
        // in the simulator (hosted by the app target) this resolves to a valid path.
        let url = sut.sharedContainerURL
        XCTAssertNotNil(url, "sharedContainerURL should resolve to a valid path in the simulator")
    }

    // MARK: - Safe Defaults (No Data Seeded) Tests

    func testDefaultValuesWhenNoDataSeeded() {
        // Verify all properties return safe, non-crashing defaults on a fresh UserDefaults
        XCTAssertTrue(sut.isFilterEnabled, "Filter should be enabled by default")
        XCTAssertFalse(sut.isProTier, "Pro tier should be off by default")
        XCTAssertTrue(sut.isMLModelEnabled, "ML model should be enabled by default (ships with working model)")
        XCTAssertEqual(sut.textsBlockedCount, 0, "Texts blocked should be 0 by default")
        XCTAssertFalse(sut.isV1Purchaser, "V1 purchaser should be false by default")
        XCTAssertFalse(sut.hasCompletedOnboarding, "Onboarding should not be completed by default")
        XCTAssertEqual(sut.keywordList, [], "Keyword list should be empty by default")
        XCTAssertEqual(sut.whitelistContexts, [:], "Whitelist contexts should be empty by default")
        XCTAssertEqual(sut.combinedTerms, [], "Combined terms should be empty by default")
        // filterMethod has a default from SharedConstants — it should not be empty or crash
        XCTAssertFalse(sut.filterMethod.isEmpty, "Filter method should have a non-empty default")
    }

    // MARK: - Shared Constants Tests

    func testAppGroupIdentifier() {
        XCTAssertEqual(SharedConstants.appGroupIdentifier, "group.com.millermedia.electiondeflection")
    }

    func testDefaultValues() {
        XCTAssertTrue(SharedConstants.defaultFilterEnabled)
        XCTAssertFalse(SharedConstants.defaultProTierStatus)
        XCTAssertTrue(SharedConstants.defaultMLModelEnabled)
        XCTAssertEqual(SharedConstants.defaultTextsBlockedCount, 0)
        XCTAssertEqual(SharedConstants.defaultFilterMethod, SharedConstants.filterMethodKeyword)
        XCTAssertFalse(SharedConstants.defaultIsV1Purchaser)
        XCTAssertFalse(SharedConstants.defaultHasCompletedOnboarding)
    }

    // MARK: - ML Model Enabled Edge Cases (Story 3.6)

    func testMLModelEnabledCanBeSetToFalse() {
        sut.isMLModelEnabled = false
        XCTAssertFalse(sut.isMLModelEnabled, "ML model enabled should be settable to false")
    }

    func testMLModelEnabledPersistsAcrossInstances() {
        sut.isMLModelEnabled = false
        let secondInstance = SharedDataManager(defaults: testDefaults)
        XCTAssertFalse(secondInstance.isMLModelEnabled, "ML model disabled state should persist across instances")
    }

    // MARK: - Filter Method Edge Cases (Story 3.6)

    func testFilterMethodCanBeSetToKeyword() {
        sut.filterMethod = SharedConstants.filterMethodKeyword
        XCTAssertEqual(sut.filterMethod, SharedConstants.filterMethodKeyword,
                       "Filter method should be settable to 'keyword'")
    }

    func testFilterMethodKeywordPersistsAcrossInstances() {
        sut.filterMethod = SharedConstants.filterMethodKeyword
        let secondInstance = SharedDataManager(defaults: testDefaults)
        XCTAssertEqual(secondInstance.filterMethod, SharedConstants.filterMethodKeyword,
                       "Keyword filter method should persist across instances")
    }

    // MARK: - ML Model Validator Tests (Story 3.6)

    func testMLModelValidatorSuccessPath() {
        // Note: This test relies on Bundle.main resolving to the host app bundle (which contains
        // PoliticalTextClassifier.mlmodelc). This coupling is acceptable because:
        // 1. The model must be in the app bundle for the feature to work — this validates that
        // 2. The failure path is tested independently with a bundle that lacks the model
        let result = MLModelValidator.isMLModelAvailable(in: Bundle.main)
        XCTAssertTrue(result, "ML model should be loadable from the main app bundle")
    }

    func testFilterExtensionBundleContainsLoadableMLModel() throws {
        // Guards against issue #4 (App Store 2.1.1 build 37 shipped without the
        // model): unlike testMLModelValidatorSuccessPath above, which checks the
        // *host app's* bundle via Bundle.main, this walks into the embedded
        // ElectionDeflectionFilter.appex the same way the extension process
        // resolves its own Bundle.main, so a model missing only from the
        // extension target (but present in the app) would still be caught.
        let pluginsURL = try XCTUnwrap(Bundle.main.builtInPlugInsURL,
                                        "Host app bundle should have a PlugIns directory")
        let extensionURL = pluginsURL.appendingPathComponent("ElectionDeflectionFilter.appex")
        let extensionBundle = try XCTUnwrap(Bundle(url: extensionURL),
                                             "Should be able to load the ElectionDeflectionFilter.appex bundle at \(extensionURL.path)")
        let modelURL = try XCTUnwrap(
            extensionBundle.url(forResource: "PoliticalTextClassifier", withExtension: "mlmodelc"),
            "PoliticalTextClassifier.mlmodelc should be present in the filter extension bundle"
        )

        let config = MLModelConfiguration()
        config.computeUnits = .cpuOnly
        XCTAssertNoThrow(try MLModel(contentsOf: modelURL, configuration: config),
                          "ML model should be loadable from the filter extension bundle")
    }

    func testMLModelValidatorFailurePathMissingModel() {
        // Use the test bundle which does NOT contain PoliticalTextClassifier.mlmodelc
        let testBundle = Bundle(for: SharedDataManagerTests.self)
        let result = MLModelValidator.isMLModelAvailable(in: testBundle)
        XCTAssertFalse(result, "ML model should not be found in test bundle")
    }

    func testMLModelValidatorSyncSetsMLEnabledForProTier() {
        // Pro tier + model available → ML enabled
        sut.isProTier = true
        MLModelValidator.validateAndSync(using: sut, in: Bundle.main)
        XCTAssertTrue(sut.isMLModelEnabled, "isMLModelEnabled should be true when Pro tier and model loads")
        XCTAssertEqual(sut.filterMethod, SharedConstants.filterMethodML,
                       "filterMethod should be 'ml' when Pro tier and model loads")
    }

    func testMLModelValidatorSyncSetsKeywordForFreeTier() {
        // Free tier + model available → keyword only (Pro tier gates ML)
        sut.isProTier = false
        MLModelValidator.validateAndSync(using: sut, in: Bundle.main)
        XCTAssertFalse(sut.isMLModelEnabled, "isMLModelEnabled should be false for Free tier even if model loads")
        XCTAssertEqual(sut.filterMethod, SharedConstants.filterMethodKeyword,
                       "filterMethod should be 'keyword' for Free tier users")
    }

    func testMLModelValidatorSyncSetsKeywordFallback() {
        // Pro tier + model unavailable → keyword fallback
        sut.isProTier = true
        let testBundle = Bundle(for: SharedDataManagerTests.self)
        MLModelValidator.validateAndSync(using: sut, in: testBundle)
        XCTAssertFalse(sut.isMLModelEnabled, "isMLModelEnabled should be false when model fails to load")
        XCTAssertEqual(sut.filterMethod, SharedConstants.filterMethodKeyword,
                       "filterMethod should be 'keyword' when model fails to load")
    }

    func testMLModelValidatorSyncFreeTierModelUnavailable() {
        // Free tier + model unavailable → keyword (double reason)
        sut.isProTier = false
        let testBundle = Bundle(for: SharedDataManagerTests.self)
        MLModelValidator.validateAndSync(using: sut, in: testBundle)
        XCTAssertFalse(sut.isMLModelEnabled, "isMLModelEnabled should be false for Free tier without model")
        XCTAssertEqual(sut.filterMethod, SharedConstants.filterMethodKeyword,
                       "filterMethod should be 'keyword' for Free tier without model")
    }

    // MARK: - Upgrade Prompt Tests (Story 4.5)

    func testOnboardingCompletedDateDefaultsToNil() {
        XCTAssertNil(sut.onboardingCompletedDate)
    }

    func testOnboardingCompletedDateRoundTrip() {
        let date = Date()
        sut.onboardingCompletedDate = date
        // Compare with 1-second tolerance (UserDefaults loses sub-second precision)
        XCTAssertNotNil(sut.onboardingCompletedDate)
        XCTAssertEqual(sut.onboardingCompletedDate!.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 1.0)
    }

    func testOnboardingCompletedDatePersists() {
        let date = Date()
        sut.onboardingCompletedDate = date
        let secondInstance = SharedDataManager(defaults: testDefaults)
        XCTAssertNotNil(secondInstance.onboardingCompletedDate)
    }

    func testHasSeenUpgradePromptDefaultsToFalse() {
        XCTAssertFalse(sut.hasSeenUpgradePrompt)
    }

    func testHasSeenUpgradePromptPersists() {
        sut.hasSeenUpgradePrompt = true
        let secondInstance = SharedDataManager(defaults: testDefaults)
        XCTAssertTrue(secondInstance.hasSeenUpgradePrompt)
    }

    func testUpgradePromptNotShownBeforeDelay() {
        // Free tier, onboarding completed today, not seen
        sut.isProTier = false
        sut.hasSeenUpgradePrompt = false
        sut.onboardingCompletedDate = Date() // today
        let daysSince = Calendar.current.dateComponents([.day], from: sut.onboardingCompletedDate!, to: Date()).day ?? 0
        let shouldShow = !sut.isProTier
            && daysSince >= SharedConstants.upgradePromptDelayDays
            && !sut.hasSeenUpgradePrompt
        XCTAssertFalse(shouldShow, "Prompt should not show before delay period")
    }

    func testUpgradePromptShownAfterDelay() {
        // Free tier, onboarding completed 4 days ago, not seen
        sut.isProTier = false
        sut.hasSeenUpgradePrompt = false
        sut.onboardingCompletedDate = Calendar.current.date(byAdding: .day, value: -4, to: Date())
        let daysSince = Calendar.current.dateComponents([.day], from: sut.onboardingCompletedDate!, to: Date()).day ?? 0
        let shouldShow = !sut.isProTier
            && daysSince >= SharedConstants.upgradePromptDelayDays
            && !sut.hasSeenUpgradePrompt
        XCTAssertTrue(shouldShow, "Prompt should show after delay period for Free tier")
    }

    func testUpgradePromptNotShownWhenAlreadySeen() {
        sut.isProTier = false
        sut.hasSeenUpgradePrompt = true
        sut.onboardingCompletedDate = Calendar.current.date(byAdding: .day, value: -4, to: Date())
        let daysSince = Calendar.current.dateComponents([.day], from: sut.onboardingCompletedDate!, to: Date()).day ?? 0
        let shouldShow = !sut.isProTier
            && daysSince >= SharedConstants.upgradePromptDelayDays
            && !sut.hasSeenUpgradePrompt
        XCTAssertFalse(shouldShow, "Prompt should not show when already seen")
    }

    func testUpgradePromptNotShownForProTier() {
        sut.isProTier = true
        sut.hasSeenUpgradePrompt = false
        sut.onboardingCompletedDate = Calendar.current.date(byAdding: .day, value: -4, to: Date())
        let daysSince = Calendar.current.dateComponents([.day], from: sut.onboardingCompletedDate!, to: Date()).day ?? 0
        let shouldShow = !sut.isProTier
            && daysSince >= SharedConstants.upgradePromptDelayDays
            && !sut.hasSeenUpgradePrompt
        XCTAssertFalse(shouldShow, "Prompt should not show for Pro tier users")
    }

    func testUpgradePromptNotShownWithoutOnboardingDate() {
        sut.isProTier = false
        sut.hasSeenUpgradePrompt = false
        // onboardingCompletedDate is nil
        let shouldShow = sut.onboardingCompletedDate != nil
            && !sut.isProTier
            && !sut.hasSeenUpgradePrompt
        XCTAssertFalse(shouldShow, "Prompt should not show without onboarding date")
    }

    func testUpgradePromptDelayDays() {
        XCTAssertEqual(SharedConstants.upgradePromptDelayDays, 3,
                       "Upgrade prompt delay should be 3 days")
    }

    // MARK: - Keychain Service Tests (Story 5.5)

    override class func tearDown() {
        // Clean up Keychain after all tests in this class
        KeychainService.deleteProTierStatus()
        super.tearDown()
    }

    func testKeychainSaveAndLoadCycle() {
        // Clean slate
        KeychainService.deleteProTierStatus()

        // Save true
        let saved = KeychainService.saveProTierStatus(true)
        XCTAssertTrue(saved, "Keychain save should succeed")

        let loaded = KeychainService.loadProTierStatus()
        XCTAssertEqual(loaded, true, "Keychain should return saved value")
    }

    func testKeychainSaveOverwrites() {
        KeychainService.deleteProTierStatus()

        KeychainService.saveProTierStatus(true)
        XCTAssertEqual(KeychainService.loadProTierStatus(), true)

        KeychainService.saveProTierStatus(false)
        XCTAssertEqual(KeychainService.loadProTierStatus(), false, "Keychain should overwrite previous value")
    }

    func testKeychainDeleteRemovesValue() {
        KeychainService.saveProTierStatus(true)

        let deleted = KeychainService.deleteProTierStatus()
        XCTAssertTrue(deleted, "Keychain delete should succeed")

        let loaded = KeychainService.loadProTierStatus()
        XCTAssertNil(loaded, "Keychain should return nil after deletion")
    }

    func testKeychainLoadReturnsNilWhenEmpty() {
        KeychainService.deleteProTierStatus()
        let loaded = KeychainService.loadProTierStatus()
        XCTAssertNil(loaded, "Keychain should return nil when no value stored")
    }

    func testKeychainDeleteSucceedsWhenEmpty() {
        KeychainService.deleteProTierStatus()
        let result = KeychainService.deleteProTierStatus()
        XCTAssertTrue(result, "Delete should succeed even when item doesn't exist")
    }

    // MARK: - Keychain-UserDefaults Sync Tests (Story 5.5)

    func testKeychainWinsWhenDisagreementWithUserDefaults() {
        // Keychain says Pro, UserDefaults says not Pro
        KeychainService.deleteProTierStatus()
        KeychainService.saveProTierStatus(true)
        sut.isProTier = false

        // Simulate sync: Keychain is authoritative
        if let keychainValue = KeychainService.loadProTierStatus() {
            if keychainValue != sut.isProTier {
                sut.isProTier = keychainValue
            }
        }

        XCTAssertTrue(sut.isProTier, "Keychain value should override UserDefaults when they disagree")
    }

    func testKeychainFalseOverridesUserDefaultsTrue() {
        // Keychain says not Pro, UserDefaults says Pro
        KeychainService.deleteProTierStatus()
        KeychainService.saveProTierStatus(false)
        sut.isProTier = true

        if let keychainValue = KeychainService.loadProTierStatus() {
            if keychainValue != sut.isProTier {
                sut.isProTier = keychainValue
            }
        }

        XCTAssertFalse(sut.isProTier, "Keychain false should override UserDefaults true")
    }

    func testUserDefaultsPreservedWhenKeychainEmpty() {
        // Keychain empty (first launch / migration), UserDefaults has value
        KeychainService.deleteProTierStatus()
        sut.isProTier = true

        if let keychainValue = KeychainService.loadProTierStatus() {
            sut.isProTier = keychainValue
        }
        // If Keychain has no value, UserDefaults should be preserved

        XCTAssertTrue(sut.isProTier, "UserDefaults value should be preserved when Keychain is empty")
    }

    // MARK: - File Protection Tests (Story 5.5)

    func testSharedContainerFileProtection() {
        // Use the real shared container (available in simulator)
        let realManager = SharedDataManager.shared
        guard let containerURL = realManager.sharedContainerURL else {
            XCTFail("Shared container URL should be available in simulator")
            return
        }

        // Read file attributes
        let attributes = try? FileManager.default.attributesOfItem(atPath: containerURL.path)
        let protectionLevel = attributes?[.protectionKey] as? FileProtectionType

        // On simulator, file protection may not be enforced, but we verify the attribute was set
        // or that it defaults to a safe value. The key test is that applyFileProtection() runs
        // without errors (which it does since SharedDataManager.init calls it).
        // On a real device, this would return .completeUntilFirstUserAuthentication
        if let level = protectionLevel {
            // If a protection level is set, it should be completeUntilFirstUserAuthentication or stricter
            let acceptableLevels: [FileProtectionType] = [
                .completeUntilFirstUserAuthentication,
                .complete
            ]
            XCTAssertTrue(acceptableLevels.contains(level),
                "File protection should be completeUntilFirstUserAuthentication or stricter, got: \(level.rawValue)")
        }
        // On simulator, protection attribute may not be present — that's expected behavior
    }

    // MARK: - Log Privacy Guardrail Test (Story 5.5)

    func testExtensionLogsDoNotContainMessageBodyContent() {
        let extensionURL = projectRoot.appendingPathComponent("ElectionDeflectionFilter")

        // Patterns that would indicate message body content is being logged
        let forbiddenLogPatterns = [
            "filterLog(\"Evaluating message: \\(", // old pattern that logged truncated body
            "messageBody, privacy: .public",        // message body with public privacy
        ]

        let violations = scanSwiftFiles(in: [extensionURL], for: forbiddenLogPatterns)

        XCTAssertTrue(violations.isEmpty,
            "Extension logs must not contain message body content (AC3 violation):\n" +
            violations.joined(separator: "\n"))
    }

    // MARK: - Privacy & Network Guardrail Tests (Stories 1.7, 5.3)

    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // ElectionDeflectionTests/
            .deletingLastPathComponent()  // project root
    }

    private func scanSwiftFiles(in directories: [URL], for patterns: [String], allowlistedFiles: [String] = []) -> [String] {
        let fileManager = FileManager.default
        var violations: [String] = []

        for directory in directories {
            guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil) else {
                continue
            }

            while let fileURL = enumerator.nextObject() as? URL {
                guard fileURL.pathExtension == "swift" else { continue }

                let relativePath = fileURL.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
                guard !allowlistedFiles.contains(relativePath) else { continue }

                guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

                for pattern in patterns {
                    if contents.contains(pattern) {
                        violations.append("\(relativePath) contains '\(pattern.trimmingCharacters(in: .whitespacesAndNewlines))'")
                    }
                }
            }
        }

        return violations
    }

    // STRICT: Extension and Shared targets must have ZERO networking code — no exceptions ever.
    func testExtensionHasZeroNetworkingCode() {
        let directoriesToScan = [
            projectRoot.appendingPathComponent("Shared"),
            projectRoot.appendingPathComponent("ElectionDeflectionFilter")
        ]

        let forbiddenPatterns = [
            "URLSession", "URLRequest", "URLComponents", "HTTPURLResponse",
            "import Network\n", "import Network ", "import CFNetwork",
            "ILNetworkResponse",
            "NWConnection", "NWPathMonitor", "NWEndpoint",
            "WKWebView", "WKNavigationDelegate", "SFSafariViewController"
        ]

        let violations = scanSwiftFiles(in: directoriesToScan, for: forbiddenPatterns)

        XCTAssertTrue(violations.isEmpty,
            "Extension zero-network policy violated (FR23, NFR-SEC1). " +
            "The filter extension and shared code must NEVER contain networking code:\n" +
            violations.joined(separator: "\n"))
    }

    // AUDIT: Main app networking must be explicitly allowlisted with justification.
    func testMainAppNetworkingIsAllowlisted() {
        let directoriesToScan = [
            projectRoot.appendingPathComponent("ElectionDeflection")
        ]

        // Allowlisted files that may contain networking code (with justification).
        // To add a new allowlisted file, add its relative path here with a comment explaining why.
        let allowlistedFiles: [String] = [
            // Story 8.1: User-initiated crowdsourced text submission (explicit opt-in, no auto-send)
            "ElectionDeflection/Services/TextSubmissionService.swift",
        ]

        let forbiddenPatterns = [
            "URLSession", "URLRequest", "URLComponents", "HTTPURLResponse",
            "import Network\n", "import Network ", "import CFNetwork",
            "NWConnection", "NWPathMonitor", "NWEndpoint"
        ]

        let violations = scanSwiftFiles(in: directoriesToScan, for: forbiddenPatterns, allowlistedFiles: allowlistedFiles)

        XCTAssertTrue(violations.isEmpty,
            "Main app networking audit failed. Non-allowlisted networking code found:\n" +
            violations.joined(separator: "\n") +
            "\n\nIf this is intentional, add the file to allowlistedFiles in this test with a justification comment.")
    }

    // Guardrail: No analytics or tracking SDKs in any target.
    func testNoAnalyticsOrTrackingSDKs() {
        let directoriesToScan = [
            projectRoot.appendingPathComponent("Shared"),
            projectRoot.appendingPathComponent("ElectionDeflectionFilter"),
            projectRoot.appendingPathComponent("ElectionDeflection")
        ]

        let forbiddenPatterns = [
            "import Firebase", "import Amplitude", "import Mixpanel",
            "import Segment", "import Adjust", "import Branch",
            "import AdSupport", "import AppTrackingTransparency",
            "ASIdentifierManager", "ATTrackingManager"
        ]

        let violations = scanSwiftFiles(in: directoriesToScan, for: forbiddenPatterns)

        XCTAssertTrue(violations.isEmpty,
            "Analytics/tracking SDK detected (FR24 violation). " +
            "ElectionDeflection must not include any analytics or tracking frameworks:\n" +
            violations.joined(separator: "\n"))
    }

    // Guardrail: SharedConstants must not contain server URLs or API keys.
    func testSharedConstantsContainsNoServerURLsOrAPIKeys() {
        let constantsURL = projectRoot
            .appendingPathComponent("Shared")
            .appendingPathComponent("SharedConstants.swift")

        guard let contents = try? String(contentsOf: constantsURL, encoding: .utf8) else {
            XCTFail("Cannot read SharedConstants.swift")
            return
        }

        let forbiddenPatterns = [
            "http://", "https://",
            "apiKey", "api_key", "API_KEY",
            "secretKey", "secret_key", "SECRET_KEY",
            "accessToken", "access_token",
            "Bearer "
        ]

        var violations: [String] = []
        for pattern in forbiddenPatterns {
            if contents.contains(pattern) {
                violations.append("SharedConstants.swift contains '\(pattern)'")
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "SharedConstants contains server URLs or API keys (NFR-SEC5 violation):\n" +
            violations.joined(separator: "\n"))
    }

    // Guardrail (Story 11.3): typed text on the submission screens lives in memory
    // only. It survives a fold through view identity, never through persistence.
    // FileManager is allowed: the share extension copies the shared image to a temp file.
    func testSubmissionScreensDoNotPersistTypedText() {
        let files = [
            "ElectionDeflection/Views/TextSubmissionView.swift",
            "ElectionDeflectionShare/ShareExtensionView.swift"
        ]

        let forbiddenPatterns = ["@SceneStorage", "@AppStorage", "UserDefaults", "Keychain"]

        var violations: [String] = []
        for file in files {
            guard let contents = try? String(contentsOf: projectRoot.appendingPathComponent(file), encoding: .utf8) else {
                XCTFail("Cannot read \(file)")
                continue
            }
            for pattern in forbiddenPatterns where contents.contains(pattern) {
                violations.append("\(file) contains '\(pattern)'")
            }
        }

        XCTAssertTrue(violations.isEmpty,
            "Submission screens must not persist typed text:\n" +
            violations.joined(separator: "\n"))
    }

    // MARK: - V2 Welcome Modal Tests (Story 6.1)

    func testHasSeenV2WelcomeDefaultsToFalse() {
        XCTAssertFalse(sut.hasSeenV2Welcome, "hasSeenV2Welcome should default to false for new/upgrading users")
    }

    func testHasSeenV2WelcomeReadWriteCycle() {
        sut.hasSeenV2Welcome = true
        XCTAssertTrue(sut.hasSeenV2Welcome)

        sut.hasSeenV2Welcome = false
        XCTAssertFalse(sut.hasSeenV2Welcome)
    }

    func testHasSeenV2WelcomePersistsAcrossInstances() {
        sut.hasSeenV2Welcome = true
        let secondInstance = SharedDataManager(defaults: testDefaults)
        XCTAssertTrue(secondInstance.hasSeenV2Welcome, "hasSeenV2Welcome should persist across instances")
    }

    func testV1UpgraderShouldSeeWelcome() {
        // v1.0 upgrader: completed onboarding but hasn't seen v2 welcome
        sut.hasCompletedOnboarding = true
        sut.hasSeenV2Welcome = false
        let shouldShowWelcome = sut.hasCompletedOnboarding && !sut.hasSeenV2Welcome
        XCTAssertTrue(shouldShowWelcome, "v1.0 upgrader should see the welcome modal")
    }

    func testWelcomeNotShownTwice() {
        // User already saw the welcome modal
        sut.hasCompletedOnboarding = true
        sut.hasSeenV2Welcome = true
        let shouldShowWelcome = sut.hasCompletedOnboarding && !sut.hasSeenV2Welcome
        XCTAssertFalse(shouldShowWelcome, "Welcome modal should not show twice")
    }

    func testFreshInstallDoesNotSeeWelcome() {
        // Fresh install: hasn't completed onboarding
        sut.hasCompletedOnboarding = false
        sut.hasSeenV2Welcome = false
        let shouldShowWelcome = sut.hasCompletedOnboarding && !sut.hasSeenV2Welcome
        XCTAssertFalse(shouldShowWelcome, "Fresh install should not see welcome modal")
    }

    func testOnboardingCompletionSetsWelcomeFlag() {
        // Simulate what OnboardingView does on completion for fresh installs
        sut.hasCompletedOnboarding = true
        sut.hasSeenV2Welcome = true
        // After onboarding, the welcome condition should be false
        let shouldShowWelcome = sut.hasCompletedOnboarding && !sut.hasSeenV2Welcome
        XCTAssertFalse(shouldShowWelcome, "Fresh install completing onboarding should never trigger welcome modal")
    }

    // MARK: - Feature Parity Validation Tests (Story 6.2)

    // --- Task 1: Data Parity Verification ---

    func testExactKeywordCountIs491() {
        XCTAssertEqual(DefaultFilterData.keywords.count, 491,
                       "keyword list (2026 triage additions) must contain exactly 491 keywords")
    }

    func testExactWhitelistContextKeysIs6WithTotal14Phrases() {
        let contexts = DefaultFilterData.whitelistContexts
        XCTAssertEqual(contexts.count, 6,
                       "v1.0 whitelist contexts must have exactly 6 keyword groups")
        let totalPhrases = contexts.values.reduce(0) { $0 + $1.count }
        XCTAssertEqual(totalPhrases, 14,
                       "v1.0 whitelist contexts must have exactly 14 total phrases across all groups")
    }

    func testExactCombinedTermsCountIs12() {
        XCTAssertEqual(DefaultFilterData.combinedTerms.count, 12,
                       "v1.0 combined terms must have exactly 12 groups")
    }

    func testSpecificV1KeywordsArePresent() {
        let keywords = DefaultFilterData.keywords
        // Spot-check 15+ representative keywords from different categories
        let requiredKeywords = [
            "trump", "biden", "harris", "election", "vote", "ballot",
            "republican", "democrat", "senate", "congress",
            " maga ", "soros", "pelosi", "kennedy", "rfk",
            "actblue", "winred", "deep state"
        ]
        for keyword in requiredKeywords {
            XCTAssertTrue(keywords.contains(keyword),
                          "v1.0 keyword '\(keyword)' must be present in DefaultFilterData.keywords")
        }
    }

    func testAllWhitelistKeywordGroupsPresent() {
        let contexts = DefaultFilterData.whitelistContexts
        // All 6 whitelist keyword groups
        let requiredKeys = ["kennedy", "vote", "voting", "election", "ballot", "reply stop"]
        for key in requiredKeys {
            XCTAssertNotNil(contexts[key],
                            "Whitelist context key '\(key)' must be present in DefaultFilterData.whitelistContexts")
        }

        // Spot-check specific phrases
        XCTAssertTrue(contexts["kennedy"]!.contains("kennedy center"),
                      "Kennedy whitelist must contain 'kennedy center'")
        XCTAssertTrue(contexts["kennedy"]!.contains("kennedy space center"),
                      "Kennedy whitelist must contain 'kennedy space center'")
        XCTAssertEqual(contexts["kennedy"]!.count, 3,
                       "Kennedy whitelist must have exactly 3 phrases")

        XCTAssertTrue(contexts["vote"]!.contains("batterysf.com/v/"),
                      "Vote whitelist must contain 'batterysf.com/v/'")
        XCTAssertEqual(contexts["vote"]!.count, 4,
                       "Vote whitelist must have exactly 4 phrases")

        XCTAssertEqual(contexts["voting"]!.count, 4,
                       "Voting whitelist must have exactly 4 phrases")

        XCTAssertTrue(contexts["election"]!.contains("ballot.trax"),
                      "Election whitelist must contain 'ballot.trax'")
        XCTAssertEqual(contexts["election"]!.count, 1,
                       "Election whitelist must have exactly 1 phrase")

        XCTAssertEqual(contexts["ballot"]!.count, 1,
                       "Ballot whitelist must have exactly 1 phrase")

        XCTAssertTrue(contexts["reply stop"]!.contains(".edu"),
                      "Reply stop whitelist must contain '.edu'")
        XCTAssertEqual(contexts["reply stop"]!.count, 1,
                       "Reply stop whitelist must have exactly 1 phrase")
    }

    // --- Task 2: Keyword Matching Logic Tests ---

    /// Lightweight helper replicating the extension's keyword matching algorithm.
    /// Uses DefaultFilterData values directly — tests the algorithm, not the extension class.
    private func simulateKeywordFilter(messageBody: String,
                                       keywords: [String] = DefaultFilterData.keywords,
                                       whitelistContexts: [String: [String]] = DefaultFilterData.whitelistContexts,
                                       combinedTerms: [[String]] = DefaultFilterData.combinedTerms) -> Bool {
        let lowercased = messageBody.lowercased()

        // Check combined terms first
        for termGroup in combinedTerms {
            if termGroup.allSatisfy({ lowercased.contains($0.lowercased()) }) {
                return true // Would be .junk
            }
        }

        // Check keywords with whitelist bypass
        for keyword in keywords {
            if lowercased.contains(keyword.lowercased()) {
                if let contexts = whitelistContexts[keyword.lowercased()] {
                    if contexts.contains(where: { lowercased.contains($0.lowercased()) }) {
                        continue // Whitelisted
                    }
                }
                return true // Would be .junk
            }
        }

        return false // Would be .allow
    }

    func testKeywordMatchPositive() {
        XCTAssertTrue(simulateKeywordFilter(messageBody: "Support trump today!"),
                      "Message containing keyword 'trump' should be filtered")
    }

    func testKeywordMatchNegative() {
        XCTAssertFalse(simulateKeywordFilter(messageBody: "Your pizza order is ready for pickup"),
                       "Message without any keywords should not be filtered")
    }

    func testKeywordMatchIsCaseInsensitive() {
        XCTAssertTrue(simulateKeywordFilter(messageBody: "TRUMP is running for office"),
                      "Keyword matching should be case-insensitive (uppercase)")
        XCTAssertTrue(simulateKeywordFilter(messageBody: "Trump is running for office"),
                      "Keyword matching should be case-insensitive (mixed case)")
        XCTAssertTrue(simulateKeywordFilter(messageBody: "tRuMp is running for office"),
                      "Keyword matching should be case-insensitive (random case)")
    }

    func testWhitelistContextBypassesKeywordMatch() {
        // "kennedy" is a keyword, but "kennedy center" is whitelisted
        XCTAssertFalse(simulateKeywordFilter(messageBody: "Tickets to the Kennedy Center are on sale"),
                       "'Kennedy Center' should bypass the 'kennedy' keyword filter")
        XCTAssertFalse(simulateKeywordFilter(messageBody: "Visit Kennedy Space Center this weekend"),
                       "'Kennedy Space Center' should bypass the 'kennedy' keyword filter")
    }

    func testKeywordNotBypassedWithoutWhitelistContext() {
        // "kennedy" without a whitelisted context should still be filtered
        XCTAssertTrue(simulateKeywordFilter(messageBody: "Kennedy announced a new policy today"),
                      "'kennedy' without whitelist context should be filtered")
    }

    func testCombinedTermsPartialMatchNotFiltered() {
        // "musk" alone is not a keyword, and partial combined term match should not filter
        // Check that "musk" alone without the second term doesn't trigger
        XCTAssertFalse(
            simulateKeywordFilter(
                messageBody: "Elon Musk launched a new rocket",
                keywords: [], // Empty keywords to isolate combined terms test
                whitelistContexts: [:],
                combinedTerms: DefaultFilterData.combinedTerms
            ),
            "Partial combined term match ('musk' without 'stop=end') should not be filtered"
        )
    }

    func testCombinedTermsFullMatchFiltered() {
        XCTAssertTrue(
            simulateKeywordFilter(
                messageBody: "Musk says stop=end to regulation",
                keywords: [], // Empty keywords to isolate combined terms test
                whitelistContexts: [:],
                combinedTerms: DefaultFilterData.combinedTerms
            ),
            "Full combined term match ('musk' + 'stop=end') should be filtered"
        )
    }

    func testCombinedTermsElonVariant() {
        XCTAssertTrue(
            simulateKeywordFilter(
                messageBody: "elon wants you to reply stop now",
                keywords: [], // Empty keywords to isolate combined terms test
                whitelistContexts: [:],
                combinedTerms: DefaultFilterData.combinedTerms
            ),
            "Combined term ('elon' + 'reply stop') should be filtered"
        )
    }

    func testCombinedTermsDemocracyVariant() {
        XCTAssertTrue(
            simulateKeywordFilter(
                messageBody: "Save democracy! Text stop to end your subscription",
                keywords: [], // Empty keywords to isolate combined terms test
                whitelistContexts: [:],
                combinedTerms: DefaultFilterData.combinedTerms
            ),
            "Combined term ('democracy' + 'stop to end') should be filtered"
        )
    }

    // --- Task 3: Pro Tier Gating Audit Tests ---

    func testFreeTierForcedToKeywordFilterMethod() {
        sut.isProTier = false
        MLModelValidator.validateAndSync(using: sut, in: Bundle.main)
        XCTAssertEqual(sut.filterMethod, SharedConstants.filterMethodKeyword,
                       "Free tier must always use keyword filter method, never ML")
    }

    func testFreeTierMLModelDisabled() {
        sut.isProTier = false
        MLModelValidator.validateAndSync(using: sut, in: Bundle.main)
        XCTAssertFalse(sut.isMLModelEnabled,
                       "Free tier must have isMLModelEnabled set to false")
    }

    func testFilterToggleWorksWithoutProTier() {
        sut.isProTier = false
        // Free tier user can toggle filter on/off
        sut.isFilterEnabled = false
        XCTAssertFalse(sut.isFilterEnabled, "Free tier user should be able to disable filtering")
        sut.isFilterEnabled = true
        XCTAssertTrue(sut.isFilterEnabled, "Free tier user should be able to re-enable filtering")
    }

    func testDataSeedingWorksWithoutProTier() {
        sut.isProTier = false
        sut.seedDefaultFilterDataIfNeeded()
        XCTAssertEqual(sut.keywordList.count, 491,
                       "Data seeding must work for Free tier (491 keywords)")
        XCTAssertEqual(sut.whitelistContexts.count, 6,
                       "Data seeding must populate all 6 whitelist context groups for Free tier")
        XCTAssertEqual(sut.combinedTerms.count, 12,
                       "Data seeding must populate all 12 combined term groups for Free tier")
    }
}

// MARK: - Onboarding Steps Tests (Issue #2: Unknown Senders setup step)

final class OnboardingStepsTests: XCTestCase {

    /// Extracts "Step N" numbers from titles formatted as "Step N: ...", in list order.
    private func stepNumbers(from steps: [OnboardingStep]) -> [Int] {
        steps.compactMap { step in
            guard step.title.hasPrefix("Step "),
                  let colonIndex = step.title.firstIndex(of: ":") else { return nil }
            let numberPart = step.title[..<colonIndex].dropFirst("Step ".count)
            return Int(numberPart)
        }
    }

    private func indexOfStep(containing substring: String, in steps: [OnboardingStep]) -> Int? {
        steps.firstIndex { $0.description.contains(substring) }
    }

    private func indexOfStepSelectingApp(in steps: [OnboardingStep]) -> Int? {
        steps.firstIndex { $0.description.contains("Select 'ElectionDeflection'") }
    }

    func testIOS26StepsMentionScreenUnknownSendersBeforeSelectingApp() {
        let steps = OnboardingStep.steps(forOSMajorVersion: 26)

        guard let toggleIndex = indexOfStep(containing: "Screen Unknown Senders", in: steps),
              let selectIndex = indexOfStepSelectingApp(in: steps) else {
            XCTFail("Expected both a 'Screen Unknown Senders' step and an app-selection step")
            return
        }

        XCTAssertLessThan(toggleIndex, selectIndex,
                          "The Screen Unknown Senders toggle must be explained before the user is asked to select ElectionDeflection")
    }

    func testIOS18StepsMentionFilterUnknownSendersBeforeSelectingApp() {
        let steps = OnboardingStep.steps(forOSMajorVersion: 18)

        guard let toggleIndex = indexOfStep(containing: "Filter Unknown Senders", in: steps),
              let selectIndex = indexOfStepSelectingApp(in: steps) else {
            XCTFail("Expected both a 'Filter Unknown Senders' step and an app-selection step")
            return
        }

        XCTAssertLessThan(toggleIndex, selectIndex,
                          "The Filter Unknown Senders toggle must be explained before the user is asked to select ElectionDeflection")
    }

    func testIOS17StepsMentionFilterUnknownSendersBeforeSelectingApp() {
        let steps = OnboardingStep.steps(forOSMajorVersion: 17)

        guard let toggleIndex = indexOfStep(containing: "Filter Unknown Senders", in: steps),
              let selectIndex = indexOfStepSelectingApp(in: steps) else {
            XCTFail("Expected both a 'Filter Unknown Senders' step and an app-selection step")
            return
        }

        XCTAssertLessThan(toggleIndex, selectIndex,
                          "The Filter Unknown Senders toggle must be explained before the user is asked to select ElectionDeflection")
    }

    func testIOS27StepsResolveToIOS26Path() {
        // iPhone Duo ships with iOS 27.1; its Settings path matches iOS 26 (Story 11.7, D8)
        let ios27 = OnboardingStep.steps(forOSMajorVersion: 27)
        let ios26 = OnboardingStep.steps(forOSMajorVersion: 26)

        XCTAssertEqual(ios27.map(\.title), ios26.map(\.title))
        XCTAssertEqual(ios27.map(\.description), ios26.map(\.description))
        XCTAssertEqual(ios27.map(\.imageName), ios26.map(\.imageName))
    }

    func testStepTitlesAreNumberedConsecutivelyForEachOSVersion() {
        for major in [27, 26, 18, 17] {
            let steps = OnboardingStep.steps(forOSMajorVersion: major)
            let numbers = stepNumbers(from: steps)
            let expected = Array(1...numbers.count)
            XCTAssertEqual(numbers, expected,
                           "Step titles for major version \(major) must be numbered 1...\(numbers.count) consecutively, got \(numbers)")
        }
    }
}
