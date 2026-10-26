import XCTest
@testable import ElectionDeflection

/// Tests for the SharedDataManager data-layer contracts used by
/// MessageFilterExtension (Stories 1.2 + 1.3).
///
/// SCOPE: These tests verify the data layer that the extension depends on —
/// NOT the extension class itself. iOS does not allow @testable import of
/// app extension targets from unit test bundles, so MessageFilterExtension
/// cannot be instantiated or invoked here.
///
/// What IS tested (automated):
/// - isFilterEnabled default, toggle, persistence (Story 1.2)
/// - textsBlockedCount increment, persistence, isolation from reads (Story 1.2)
/// - filterMethod default, mutation, persistence (Story 1.2)
/// - Cross-instance data sharing (simulating extension ↔ app reads) (Story 1.2)
/// - Default filter data seeding from DefaultFilterData (Story 1.3)
/// - Keyword count verification against v1.0 data (Story 1.3)
/// - Whitelist contexts and combined terms round-trip (Story 1.3)
/// - No-overwrite protection for seeded data that is still current (Story 1.3 / issue #3)
/// - Stale seeded data (missing/outdated fingerprint) is refreshed on reseed, and
///   effectiveFilterData() falls back to DefaultFilterData while stale (issue #3)
/// - DefaultFilterData.fingerprint is deterministic and order-independent (issue #3)
/// - KeywordFilterEngine semantics: "stop=end" regression, whitelist bypass, combined
///   terms (issue #3)
///
/// What is NOT tested (requires manual device verification):
/// - MessageFilterExtension.handle() calling SharedDataManager correctly
/// - determineAction() keyword matching, whitelist bypass, combined terms
/// - Extension activation and ILMessageFilterCapabilitiesQueryHandling
final class MessageFilterExtensionTests: XCTestCase {

    private var dataManager: SharedDataManager!
    private var testDefaults: UserDefaults!
    private let testSuiteName = "com.test.messageFilterExtension"

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: testSuiteName)
        testDefaults.removePersistentDomain(forName: testSuiteName)
        dataManager = SharedDataManager(defaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testSuiteName)
        testDefaults = nil
        dataManager = nil
        super.tearDown()
    }

    // MARK: - Filter Enabled / Disabled (AC 1)

    func testFilterEnabledByDefault() {
        XCTAssertTrue(dataManager.isFilterEnabled, "Filtering should be enabled by default")
    }

    func testFilterCanBeDisabled() {
        dataManager.isFilterEnabled = false
        XCTAssertFalse(dataManager.isFilterEnabled, "Filtering should be disableable")
    }

    func testFilterDisabledPersistsAcrossInstances() {
        dataManager.isFilterEnabled = false
        let newManager = SharedDataManager(defaults: testDefaults)
        XCTAssertFalse(newManager.isFilterEnabled, "Disabled state should persist across instances")
    }

    func testFilterReEnabled() {
        dataManager.isFilterEnabled = false
        dataManager.isFilterEnabled = true
        XCTAssertTrue(dataManager.isFilterEnabled, "Filtering should be re-enableable")
    }

    // MARK: - Texts Blocked Counter (AC 4)

    func testTextsBlockedCountStartsAtZero() {
        XCTAssertEqual(dataManager.textsBlockedCount, 0, "Initial count should be 0")
    }

    func testTextsBlockedCountIncrements() {
        dataManager.incrementTextsBlockedCount()
        XCTAssertEqual(dataManager.textsBlockedCount, 1, "Count should be 1 after one increment")
    }

    func testTextsBlockedCountIncrementsMultipleTimes() {
        dataManager.incrementTextsBlockedCount()
        dataManager.incrementTextsBlockedCount()
        dataManager.incrementTextsBlockedCount()
        XCTAssertEqual(dataManager.textsBlockedCount, 3, "Count should be 3 after three increments")
    }

    func testTextsBlockedCountPersistsAcrossInstances() {
        dataManager.incrementTextsBlockedCount()
        dataManager.incrementTextsBlockedCount()

        let newManager = SharedDataManager(defaults: testDefaults)
        XCTAssertEqual(newManager.textsBlockedCount, 2, "Count should persist across manager instances")
    }

    func testTextsBlockedCountNotIncrementedDirectly() {
        // Verify count stays at 0 when no increment is called
        _ = dataManager.isFilterEnabled
        _ = dataManager.filterMethod
        XCTAssertEqual(dataManager.textsBlockedCount, 0, "Count should not change from read operations")
    }

    // MARK: - Filter Method (AC 1 — future-proofing)

    func testFilterMethodDefaultsToKeyword() {
        XCTAssertEqual(dataManager.filterMethod, SharedConstants.filterMethodKeyword,
                       "Default filter method should be 'keyword' (Pro tier required for ML)")
    }

    func testFilterMethodCanBeSetToML() {
        dataManager.filterMethod = SharedConstants.filterMethodML
        XCTAssertEqual(dataManager.filterMethod, SharedConstants.filterMethodML,
                       "Filter method should be settable to 'ml'")
    }

    func testFilterMethodPersistsAcrossInstances() {
        dataManager.filterMethod = SharedConstants.filterMethodML
        let newManager = SharedDataManager(defaults: testDefaults)
        XCTAssertEqual(newManager.filterMethod, SharedConstants.filterMethodML,
                       "Filter method should persist across instances")
    }

    // MARK: - Cross-Target Data Sharing (AC 4 — readable from main app)

    func testDataWrittenByExtensionReadableByApp() {
        // Simulate extension writing data
        dataManager.incrementTextsBlockedCount()
        dataManager.isFilterEnabled = true

        // Simulate main app reading from same UserDefaults
        let appManager = SharedDataManager(defaults: testDefaults)
        XCTAssertEqual(appManager.textsBlockedCount, 1,
                       "Main app should read count written by extension")
        XCTAssertTrue(appManager.isFilterEnabled,
                       "Main app should read filter state written by extension")
    }

    // MARK: - Default Filter Data Seeding (Story 1.3, AC 2)

    func testSeedPopulatesKeywords() {
        XCTAssertTrue(dataManager.keywordList.isEmpty, "Keywords should start empty")
        dataManager.seedDefaultFilterDataIfNeeded()
        XCTAssertFalse(dataManager.keywordList.isEmpty, "Keywords should be populated after seeding")
        XCTAssertEqual(dataManager.keywordList, DefaultFilterData.keywords,
                       "Seeded keywords should match DefaultFilterData exactly")
    }

    func testSeedPopulatesWhitelistContexts() {
        XCTAssertTrue(dataManager.whitelistContexts.isEmpty, "Whitelist contexts should start empty")
        dataManager.seedDefaultFilterDataIfNeeded()
        XCTAssertFalse(dataManager.whitelistContexts.isEmpty, "Whitelist contexts should be populated after seeding")
        XCTAssertEqual(dataManager.whitelistContexts, DefaultFilterData.whitelistContexts,
                       "Seeded whitelist contexts should match DefaultFilterData exactly")
    }

    func testSeedPopulatesCombinedTerms() {
        XCTAssertTrue(dataManager.combinedTerms.isEmpty, "Combined terms should start empty")
        dataManager.seedDefaultFilterDataIfNeeded()
        XCTAssertFalse(dataManager.combinedTerms.isEmpty, "Combined terms should be populated after seeding")
        XCTAssertEqual(dataManager.combinedTerms, DefaultFilterData.combinedTerms,
                       "Seeded combined terms should match DefaultFilterData exactly")
    }

    // MARK: - Keyword Count Verification (Story 1.3, AC 1)

    func testSeededKeywordCountMatchesV1Data() {
        dataManager.seedDefaultFilterDataIfNeeded()
        XCTAssertEqual(dataManager.keywordList.count, DefaultFilterData.keywords.count,
                       "Seeded keyword count must match v1.0 DefaultFilterData count exactly")
        // Verify we have a substantial keyword list (400+)
        XCTAssertGreaterThan(dataManager.keywordList.count, 400,
                             "v1.0 keyword list should contain 400+ keywords")
    }

    func testSeededWhitelistContextCountMatchesV1Data() {
        dataManager.seedDefaultFilterDataIfNeeded()
        XCTAssertEqual(dataManager.whitelistContexts.count, DefaultFilterData.whitelistContexts.count,
                       "Seeded whitelist context count must match v1.0 DefaultFilterData count")
    }

    func testSeededCombinedTermsCountMatchesV1Data() {
        dataManager.seedDefaultFilterDataIfNeeded()
        XCTAssertEqual(dataManager.combinedTerms.count, DefaultFilterData.combinedTerms.count,
                       "Seeded combined terms count must match v1.0 DefaultFilterData count")
    }

    // MARK: - Whitelist Contexts Round-Trip (Story 1.3, AC 1)

    func testWhitelistContextsRoundTrip() {
        let testContexts: [String: [String]] = [
            "test": ["test context one", "test context two"],
            "example": ["example phrase"]
        ]
        dataManager.whitelistContexts = testContexts
        XCTAssertEqual(dataManager.whitelistContexts, testContexts,
                       "Whitelist contexts should round-trip through UserDefaults")
    }

    func testWhitelistContextsPersistAcrossInstances() {
        dataManager.seedDefaultFilterDataIfNeeded()
        let newManager = SharedDataManager(defaults: testDefaults)
        XCTAssertEqual(newManager.whitelistContexts, DefaultFilterData.whitelistContexts,
                       "Whitelist contexts should persist across SharedDataManager instances")
    }

    // MARK: - Combined Terms Round-Trip (Story 1.3, AC 1)

    func testCombinedTermsRoundTrip() {
        let testTerms: [[String]] = [
            ["term1", "term2"],
            ["alpha", "beta", "gamma"]
        ]
        dataManager.combinedTerms = testTerms
        XCTAssertEqual(dataManager.combinedTerms, testTerms,
                       "Combined terms should round-trip through UserDefaults")
    }

    func testCombinedTermsPersistAcrossInstances() {
        dataManager.seedDefaultFilterDataIfNeeded()
        let newManager = SharedDataManager(defaults: testDefaults)
        XCTAssertEqual(newManager.combinedTerms, DefaultFilterData.combinedTerms,
                       "Combined terms should persist across SharedDataManager instances")
    }

    // MARK: - No-Overwrite Protection When Current (Story 1.3 / issue #3)

    func testSeedDoesNotOverwriteExistingData() {
        // Seed with defaults first — this stores the current fingerprint alongside the data.
        dataManager.seedDefaultFilterDataIfNeeded()

        // Manually modify keyword list without changing the stored fingerprint.
        dataManager.keywordList = ["custom_keyword_only"]
        XCTAssertEqual(dataManager.keywordList.count, 1, "Should have 1 custom keyword")

        // Re-seeding should be skipped: keywordList is non-empty AND the stored
        // fingerprint still matches DefaultFilterData.fingerprint, so the data is
        // considered current rather than stale.
        dataManager.seedDefaultFilterDataIfNeeded()
        XCTAssertEqual(dataManager.keywordList, ["custom_keyword_only"],
                       "Re-seeding should not overwrite existing keyword data when it is still current")
    }

    func testSeedOnlyTriggersWhenKeywordListEmpty() {
        // Set custom whitelist/combined but leave keywords empty
        dataManager.whitelistContexts = ["custom": ["custom phrase"]]
        dataManager.combinedTerms = [["custom1", "custom2"]]

        // Seed should trigger because keywordList is empty — one of the two reseed
        // conditions (the other being a stale/missing fingerprint; see
        // testSeedRefreshesStaleKeywordList / testSeedRefreshesWhenFingerprintIsOld).
        dataManager.seedDefaultFilterDataIfNeeded()
        XCTAssertEqual(dataManager.keywordList, DefaultFilterData.keywords,
                       "Seeding should populate keywords when keywordList was empty")
        // Note: whitelist and combined get overwritten by seed since any trigger reseeds all three lists together.
        XCTAssertEqual(dataManager.whitelistContexts, DefaultFilterData.whitelistContexts,
                       "Seeding overwrites whitelist contexts when keywords were empty")
        XCTAssertEqual(dataManager.combinedTerms, DefaultFilterData.combinedTerms,
                       "Seeding overwrites combined terms when keywords were empty")
        XCTAssertEqual(dataManager.filterDataFingerprint, DefaultFilterData.fingerprint,
                       "Seeding should store the current fingerprint")
    }

    // MARK: - Stale Filter Data Refresh (issue #3)

    func testSeedRefreshesStaleKeywordList() {
        // Simulate a user seeded before "stop=end" was added, with no fingerprint
        // stored at all (i.e. seeded before fingerprinting existed).
        let staleKeywords = DefaultFilterData.keywords.filter { $0 != "stop=end" }
        dataManager.keywordList = staleKeywords
        dataManager.whitelistContexts = DefaultFilterData.whitelistContexts
        dataManager.combinedTerms = DefaultFilterData.combinedTerms

        dataManager.seedDefaultFilterDataIfNeeded()

        XCTAssertEqual(dataManager.keywordList, DefaultFilterData.keywords,
                       "A stale keyword list missing a current bundled keyword should be refreshed")
        XCTAssertEqual(dataManager.filterDataFingerprint, DefaultFilterData.fingerprint,
                       "Seeding should store the current fingerprint after refreshing")
    }

    func testSeedRefreshesWhenFingerprintIsOld() {
        dataManager.keywordList = DefaultFilterData.keywords
        dataManager.whitelistContexts = DefaultFilterData.whitelistContexts
        dataManager.combinedTerms = DefaultFilterData.combinedTerms
        dataManager.filterDataFingerprint = "a-deliberately-stale-fingerprint-value"

        dataManager.seedDefaultFilterDataIfNeeded()

        XCTAssertEqual(dataManager.filterDataFingerprint, DefaultFilterData.fingerprint,
                       "An outdated stored fingerprint should trigger a reseed even though the keyword list happens to already be current")
    }

    func testEffectiveFilterDataReturnsDefaultsWhenStale() {
        let staleKeywords = DefaultFilterData.keywords.filter { $0 != "stop=end" }
        dataManager.keywordList = staleKeywords
        // No fingerprint stored, so the stored copy is considered stale.

        let effective = dataManager.effectiveFilterData()

        XCTAssertEqual(effective.keywords, DefaultFilterData.keywords,
                       "effectiveFilterData() should fall back to bundled defaults when the stored data is stale")
    }

    func testEffectiveFilterDataReturnsStoredDataWhenCurrent() {
        dataManager.seedDefaultFilterDataIfNeeded()

        let effective = dataManager.effectiveFilterData()

        XCTAssertEqual(effective.keywords, DefaultFilterData.keywords)
        XCTAssertEqual(effective.whitelistContexts, DefaultFilterData.whitelistContexts)
        XCTAssertEqual(effective.combinedTerms, DefaultFilterData.combinedTerms)
    }

    // MARK: - Fingerprint Determinism (issue #3)

    func testFingerprintIsDeterministic() {
        XCTAssertEqual(DefaultFilterData.fingerprint, DefaultFilterData.fingerprint,
                       "Fingerprint of the same bundled data must be stable across calls")
    }

    func testFingerprintDiffersForDifferentData() {
        let base = DefaultFilterData.fingerprint(keywords: ["alpha", "beta"], whitelistContexts: [:], combinedTerms: [])
        let changed = DefaultFilterData.fingerprint(keywords: ["alpha", "beta", "gamma"], whitelistContexts: [:], combinedTerms: [])
        XCTAssertNotEqual(base, changed, "Fingerprint must change when the underlying data changes")
    }

    func testFingerprintIsStableAcrossDictionaryKeyOrdering() {
        let a = DefaultFilterData.fingerprint(
            keywords: ["alpha"],
            whitelistContexts: ["one": ["x"], "two": ["y"]],
            combinedTerms: []
        )
        let b = DefaultFilterData.fingerprint(
            keywords: ["alpha"],
            whitelistContexts: ["two": ["y"], "one": ["x"]],
            combinedTerms: []
        )
        XCTAssertEqual(a, b, "Fingerprint must not depend on Dictionary's nondeterministic key ordering")
    }

    // MARK: - KeywordFilterEngine Semantics (issue #3)

    func testStopEndKeywordFlagsPoliticalText() {
        let engine = KeywordFilterEngine(
            keywords: DefaultFilterData.keywords,
            whitelistContexts: DefaultFilterData.whitelistContexts,
            combinedTerms: DefaultFilterData.combinedTerms
        )
        // Contains no keyword/combined-term other than "stop=end", so this isolates
        // the regression: without the "stop=end" fix, this would be misclassified as allow.
        let body = "Hey! Just confirming our dinner reservation for Friday at 7pm. stop=end"
        XCTAssertTrue(engine.isPolitical(body), "\"stop=end\" alone should flag the text as junk (issue #3)")
    }

    func testStopEndKeywordCaseInsensitive() {
        let engine = KeywordFilterEngine(
            keywords: DefaultFilterData.keywords,
            whitelistContexts: DefaultFilterData.whitelistContexts,
            combinedTerms: DefaultFilterData.combinedTerms
        )
        let body = "Hey! Just confirming our dinner reservation for Friday at 7pm. STOP=END"
        XCTAssertTrue(engine.isPolitical(body), "\"STOP=END\" uppercase should match case-insensitively")
    }

    func testReplyStopToEndIsNotFlaggedByStopEnd() {
        let engine = KeywordFilterEngine(
            keywords: DefaultFilterData.keywords,
            whitelistContexts: DefaultFilterData.whitelistContexts,
            combinedTerms: DefaultFilterData.combinedTerms
        )
        let body = "Your package has shipped and will arrive Thursday. Reply STOP to end messages."
        XCTAssertFalse(engine.isPolitical(body), "Legitimate \"Reply STOP to end\" text must not be flagged by the \"stop=end\" keyword")
    }

    func testWhitelistedContextBypassesKeywordMatch() {
        let engine = KeywordFilterEngine(
            keywords: DefaultFilterData.keywords,
            whitelistContexts: DefaultFilterData.whitelistContexts,
            combinedTerms: DefaultFilterData.combinedTerms
        )
        XCTAssertFalse(engine.isPolitical("Join us for a tour of the Kennedy Space Center this weekend!"),
                       "\"kennedy space center\" is a whitelisted context for the \"kennedy\" keyword")
    }

    func testCombinedTermsFlagWhenBothPresent() {
        let engine = KeywordFilterEngine(
            keywords: [],
            whitelistContexts: [:],
            combinedTerms: [["musk", "stop to end"]]
        )
        XCTAssertTrue(engine.isPolitical("Elon Musk says to stop to end the madness."),
                      "\"musk\" + \"stop to end\" is a combined-terms match")
    }

    func testCombinedTermsRequireBothTerms() {
        let engine = KeywordFilterEngine(
            keywords: [],
            whitelistContexts: [:],
            combinedTerms: [["musk", "stop to end"]]
        )
        XCTAssertFalse(engine.isPolitical("Elon Musk announced a new rocket launch."),
                       "Only one half of a combined-terms pair should not match")
    }
}
