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

    // MARK: - Space-wrapped keywords next to punctuation

    func testSpaceWrappedKeywordMatchesAdjacentPunctuation() {
        let engine = KeywordFilterEngine(keywords: [" maga "], whitelistContexts: [:], combinedTerms: [])
        let bodies = [
            "MAGA!", "Go MAGA.", "Is it MAGA?", "Yes, MAGA, always", "Team (MAGA) rally",
            "He said \"MAGA\" twice", "MAGA's big night", "we love maga", "MAGA", "#MAGA now", "MAGA\u{2019}s plan"
        ]
        for body in bodies {
            XCTAssertTrue(engine.isPolitical(body), "\"\(body)\" should match \" maga \"")
        }
    }

    func testSpaceWrappedKeywordDoesNotMatchInsideWords() {
        let engine = KeywordFilterEngine(keywords: [" maga "], whitelistContexts: [:], combinedTerms: [])
        for body in ["Use your imagination!", "New magazine out today.", "Magazines, books", "Dr. Magahey called", "ima-ga"] {
            XCTAssertFalse(engine.isPolitical(body), "\"\(body)\" must not match \" maga \"")
        }
        let defaults = KeywordFilterEngine(
            keywords: DefaultFilterData.keywords,
            whitelistContexts: DefaultFilterData.whitelistContexts,
            combinedTerms: DefaultFilterData.combinedTerms
        )
        XCTAssertFalse(defaults.isPolitical("Use your imagination! The magazine is here."))
        XCTAssertTrue(defaults.isPolitical("Hello (MAGA)"))
    }

    func testPunctuationNormalizationKeepsHostsAndPunctuatedKeywordsWorking() {
        let engine = KeywordFilterEngine(
            keywords: ["cmp.lk", "win4tx.org", " gop:", " sen. ", "left-wing", " gop's "],
            whitelistContexts: [:],
            combinedTerms: []
        )
        XCTAssertTrue(engine.isPolitical("Visit https://cmp.lk/abc today"))
        XCTAssertTrue(engine.isPolitical("see win4tx.org/donate"))
        XCTAssertTrue(engine.isPolitical("GOP: act now"))
        XCTAssertTrue(engine.isPolitical("Message from Sen. Smith"))
        XCTAssertTrue(engine.isPolitical("a left-wing group"))
        XCTAssertTrue(engine.isPolitical("the GOP's plan"))
        XCTAssertFalse(engine.isPolitical("cmp lk and win4tx org"), "Dots in host keywords must not be treated as spaces")
    }

    // MARK: - 2026 Submission Triage Keywords (Story 13.1)

    private static let triageOptOutTerms = ["stop2end", "end2end", "stoptoend"]

    private static let triageHosts = [
        "crushmaga.io", "raaction.io", "edw-now.org", "progressaf.com", "takeoverfund.io",
        "demsfight.com", "win-26.us", "bold-lead.org", "ameripacfuture.org", "pia4fl.io",
        "helpdemswin.io", "gop-poll.com", "26text.com", "an4fl.com"
    ]

    private static var triageTerms: [String] { triageOptOutTerms + triageHosts }

    /// Engine holding ONLY the new terms, so a match proves the new term (not an older keyword) fired.
    private func triageOnlyEngine() -> KeywordFilterEngine {
        KeywordFilterEngine(keywords: Self.triageTerms, whitelistContexts: [:], combinedTerms: [])
    }

    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // ElectionDeflectionTests/
            .deletingLastPathComponent()  // project root
    }

    func testTriageTermsAreStandaloneDefaultKeywords() {
        for term in Self.triageTerms {
            XCTAssertTrue(DefaultFilterData.keywords.contains(term), "\"\(term)\" should be a standalone default keyword")
        }
    }

    func testTriageOptOutTermsCatchPoliticalExamples() {
        let engine = triageOnlyEngine()
        // Short paraphrased fixtures (not verbatim submissions).
        let examples = [
            "stop2end": "Your 2026 member card is about to lapse. Renew now to keep fighting. Stop2End",
            "end2end": "Final hours to double your gift before the deadline! Reply END2END to quit",
            "stoptoend": "We need 500 patriots by midnight. Chip in now. StopToEnd"
        ]
        for term in Self.triageOptOutTerms {
            let body = try! XCTUnwrap(examples[term])
            XCTAssertTrue(engine.isPolitical(body), "\"\(term)\" should flag: \(body)")
        }
    }

    func testTriageHostsCatchBareAndSchemedLinks() {
        let engine = KeywordFilterEngine(
            keywords: DefaultFilterData.keywords,
            whitelistContexts: DefaultFilterData.whitelistContexts,
            combinedTerms: DefaultFilterData.combinedTerms
        )
        for host in Self.triageHosts {
            // Neutral wording so only the host can trigger the match.
            let forms = [
                "Quick question for you, see here: \(host)/a1b2c3",
                "Quick question for you, see here: https://\(host)/a1b2c3",
                "Quick question for you, see here: t.\(host)/a1b2c3"
            ]
            for body in forms {
                XCTAssertTrue(engine.isPolitical(body), "\"\(host)\" should flag: \(body)")
                XCTAssertTrue(triageOnlyEngine().isPolitical(body), "Match must come from \"\(host)\" itself: \(body)")
            }
        }
    }

    func testTriageTermsDoNotFireOnTrainingDataNotPolitical() throws {
        let url = projectRoot.appendingPathComponent("TrainingData/training_data_v1.json")
        let rows = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: String]]
        let notPolitical = try XCTUnwrap(rows).filter { $0["label"] == "not_political" }.compactMap { $0["text"] }
        XCTAssertFalse(notPolitical.isEmpty, "training_data_v1.json should contain not_political rows")

        let engine = triageOnlyEngine()
        let hits = notPolitical.filter { engine.isPolitical($0) }
        XCTAssertTrue(hits.isEmpty, "New triage terms must not fire on training not_political rows:\n\(hits.joined(separator: "\n"))")
    }

    func testTriageTermsDoNotFireOnLabeledNotPoliticalSubmissions() {
        // Short paraphrases of the 2026-10-28 labeled:not_political KV items (no verbatim text).
        let notPolitical = [
            "Hi! Our hiring team has remote support roles open, $200-800 per day, flexible hours.",
            "Tired of high energy bills? This plug-in device steadies your home's power.",
            "A recruiter here: your background stood out, we have remote openings.",
            "Help share the gospel with World Cup fans from closed countries. Give: red-win.org/x1 stop=end",
            "Your cloud storage renewal failed; update payment or your files will be removed.",
            "Hi, I noticed your property on Elm Ct and wanted to talk about a purchase. Reply STOP to opt out",
            "Job fair in 3 days, see the employer list: test.net/x2 To opt-out, reply STOP",
            "Request a free prayer bookmark for military members: ptvictory.co/x3 stop=end",
            "$50 sends gospel booklets to World Cup fans. Give: us-26.co/x4 stop=end",
            "Hi, it's the painting crew working in your area, want an estimate?",
            "Payment alert: a $166 store charge is on hold due to unusual activity.",
            "Remote recruitment team here about a part-time position that fits you.",
            "Claim a free DVD set on ancient Christianity: usa26.io/x5 stop=end",
            "Gas over $4? Drivers plug this into their cars to save fuel: gwatng.com/x6 STOP to end",
            "Get ready for Easter with 12 days of scripture and prayer: prebrn.us/x7 STOP=end"
        ]
        let engine = triageOnlyEngine()
        for body in notPolitical {
            XCTAssertFalse(engine.isPolitical(body), "New triage terms must not fire on: \(body)")
        }
    }

    func testStop2EndKnownCollisionIsOptOutSpam() {
        // The only labeled:not_political item containing a new term is a get-rich-quick spam blast
        // using the "Stop2End" obfuscation. Accepted 2026-10-28 (Matt left the call to dev): filtering it costs nothing.
        let body = "FINAL WARNING: the AI profits program is closing. Start earning on autopilot now! Stop2End"
        XCTAssertTrue(triageOnlyEngine().isPolitical(body), "Documented, accepted \"stop2end\" collision")
    }

    func testReplyStopVariantsStayCombinedOnly() {
        XCTAssertFalse(DefaultFilterData.keywords.contains("stop to end"))
        XCTAssertFalse(DefaultFilterData.keywords.contains("reply stop to opt-out"))
        let engine = KeywordFilterEngine(
            keywords: DefaultFilterData.keywords,
            whitelistContexts: DefaultFilterData.whitelistContexts,
            combinedTerms: DefaultFilterData.combinedTerms
        )
        XCTAssertFalse(engine.isPolitical("Your table for two is confirmed for 7pm. Reply STOP to opt-out."),
                       "Legitimate \"Reply STOP to opt-out\" text must not be flagged")
        XCTAssertFalse(engine.isPolitical("Your prescription is ready for pickup. Text STOP to end alerts."),
                       "Legitimate \"STOP to end\" text must not be flagged")
    }

    func testFingerprintChangesWithTriageAdditions() {
        let preTriageKeywords = DefaultFilterData.keywords.filter { !Self.triageTerms.contains($0) }
        let preTriageFingerprint = DefaultFilterData.fingerprint(
            keywords: preTriageKeywords,
            whitelistContexts: DefaultFilterData.whitelistContexts,
            combinedTerms: DefaultFilterData.combinedTerms
        )
        XCTAssertNotEqual(preTriageFingerprint, DefaultFilterData.fingerprint,
                          "Adding the triage terms must change the fingerprint so seeded lists refresh")

        // A user seeded with the pre-triage list gets the new terms on the next reseed.
        dataManager.keywordList = preTriageKeywords
        dataManager.whitelistContexts = DefaultFilterData.whitelistContexts
        dataManager.combinedTerms = DefaultFilterData.combinedTerms
        dataManager.filterDataFingerprint = preTriageFingerprint

        dataManager.seedDefaultFilterDataIfNeeded()

        XCTAssertEqual(dataManager.keywordList, DefaultFilterData.keywords)
        XCTAssertEqual(dataManager.filterDataFingerprint, DefaultFilterData.fingerprint)
    }

    // MARK: - Triage Round 2: Extra Hosts and Devotional Contexts (Story 13.2)

    private static let roundTwoHosts = [
        "sherrodbrown.com", "jamestalarico.com", "alaskans4mary.org", "bolddems.com", "readyforthefight.com",
        "jnk4us.co", "2026give.com", "prochoicedems.org", "r4fp.org", "no-kings.io", "xavier4ca.com",
        "thehousepac.com", "vter.io"
    ]

    private static let devotionalKeywords = ["stop=end", "us-26.co", "usa26.io"]

    private func defaultEngine() -> KeywordFilterEngine {
        KeywordFilterEngine(
            keywords: DefaultFilterData.keywords,
            whitelistContexts: DefaultFilterData.whitelistContexts,
            combinedTerms: DefaultFilterData.combinedTerms
        )
    }

    func testRoundTwoHostsCatchBareAndSchemedLinks() {
        let hostOnly = KeywordFilterEngine(keywords: Self.roundTwoHosts, whitelistContexts: [:], combinedTerms: [])
        for host in Self.roundTwoHosts {
            XCTAssertTrue(DefaultFilterData.keywords.contains(host), "\"\(host)\" should be a default keyword")
            for body in [
                "Quick question for you, see here: \(host)/a1b2c3",
                "Quick question for you, see here: https://\(host)/a1b2c3",
                "Quick question for you, see here: go.\(host)/a1b2c3"
            ] {
                XCTAssertTrue(defaultEngine().isPolitical(body), "\"\(host)\" should flag: \(body)")
                XCTAssertTrue(hostOnly.isPolitical(body), "Match must come from \"\(host)\" itself: \(body)")
            }
        }
    }

    func testRoundTwoHostsDoNotFireOnTrainingDataNotPolitical() throws {
        let url = projectRoot.appendingPathComponent("TrainingData/training_data_v1.json")
        let rows = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: String]]
        let notPolitical = try XCTUnwrap(rows).filter { $0["label"] == "not_political" }.compactMap { $0["text"] }
        let hostOnly = KeywordFilterEngine(keywords: Self.roundTwoHosts, whitelistContexts: [:], combinedTerms: [])
        let hits = notPolitical.filter { hostOnly.isPolitical($0) }
        XCTAssertTrue(hits.isEmpty, "Round 2 hosts must not fire on training not_political rows:\n\(hits.joined(separator: "\n"))")
    }

    func testDefaultListFlagsNoTrainingDataNotPoliticalRows() throws {
        // The two training rows flagged before Story 13.2 were devotional appeals; the whole default list
        // (not just the new terms) now flags none of the not_political rows.
        let url = projectRoot.appendingPathComponent("TrainingData/training_data_v1.json")
        let rows = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: String]]
        let notPolitical = try XCTUnwrap(rows).filter { $0["label"] == "not_political" }.compactMap { $0["text"] }
        let hits = notPolitical.filter { defaultEngine().isPolitical($0) }
        XCTAssertTrue(hits.isEmpty, "Default list must not flag training not_political rows:\n\(hits.joined(separator: "\n"))")
    }

    func testDevotionalAppealsFromPoliticalVendorsAreNotFlagged() {
        // Short paraphrases of the devotional/charity items labeled not_political (no verbatim text).
        let devotional = [
            "Help share the gospel with World Cup fans from closed countries. Give: red-win.org/x1 stop=end",
            "Request a free prayer bookmark for military members: ptvictory.co/x3 stop=end",
            "$50 sends gospel booklets to World Cup fans. Give: us-26.co/x4 stop=end",
            "Claim a free DVD set on ancient Christianity: usa26.io/x5 stop=end",
            "Get ready for Easter with 12 days of scripture and prayer: prebrn.us/x7 STOP=end",
            "I've been praying for you. I believe God wants me to share this: usa26.io/x8"
        ]
        for body in devotional {
            XCTAssertFalse(defaultEngine().isPolitical(body), "Devotional appeal must not be flagged: \(body)")
        }
    }

    func testDevotionalContextsOnlyBypassTheirOwnKeywords() {
        let engine = defaultEngine()
        // Without a devotional phrase, the vendor keywords still flag.
        XCTAssertTrue(engine.isPolitical("Last chance to claim your member card: usa26.io/x9 stop=end"))
        XCTAssertTrue(engine.isPolitical("Your gift is matched 5x tonight: us-26.co/x10"))
        // A devotional phrase does not hide other political keywords.
        XCTAssertTrue(engine.isPolitical("Join our prayer call for Trump tonight: us-26.co/x11 stop=end"))
        XCTAssertTrue(engine.isPolitical("Gospel singers back the GOP ticket! crushmaga.io/x12 stop=end"))
        // The devotional whitelist is scoped to exactly these three keywords.
        for keyword in Self.devotionalKeywords {
            XCTAssertNotNil(DefaultFilterData.whitelistContexts[keyword], "\"\(keyword)\" should have devotional contexts")
        }
    }

    func testFingerprintChangesWithRoundTwo() {
        var releasedWhitelist = DefaultFilterData.whitelistContexts
        Self.devotionalKeywords.forEach { releasedWhitelist.removeValue(forKey: $0) }
        let released = DefaultFilterData.fingerprint(
            keywords: DefaultFilterData.keywords.filter { !Self.roundTwoHosts.contains($0) },
            whitelistContexts: releasedWhitelist,
            combinedTerms: DefaultFilterData.combinedTerms
        )
        XCTAssertNotEqual(released, DefaultFilterData.fingerprint,
                          "Round 2 changes must change the fingerprint so 2.1.5 users' seeded lists refresh")
    }

    // MARK: - Round 3 Keyword Gaps (2.1.6)

    func testRoundThreeKeywordGapsAreFlagged() {
        let engine = defaultEngine()
        let political = [
            "MAGA patriots: your gift is needed tonight. Reply STOP to end",
            "Chip in now: your gift gets a 5X MATCH until midnight",
            "Donate today and get a 7x match on your contribution",
            "Give before midnight for a 6x match",
            "Claim your tariff rebate, Trump says. Vote now",
            "Your stimulus check is waiting, courtesy of the Democrats",
            "Midterm deadline tonight: the GOP needs you to vote",
            "Midterm primary polls close soon"
        ]
        for body in political {
            XCTAssertTrue(engine.isPolitical(body), "Should be flagged: \(body)")
        }
    }

    func testRoundThreeKeywordsDoNotFlagOrdinaryTexts() {
        let engine = defaultEngine()
        let benign = [
            "Your midterm exam is moved to Room 204",
            "Midterm grades are posted on the portal",
            "New issue of Magazine arrived at the shop",
            "Lunch at noon?",
            "Your stimulus check is waiting at the bank",
            "Claim your tariff rebate today",
            "Midterm deadline tonight: can we count on you?",
            "Embrace the space, our package arrived",
            "Your gift gets a 5X MATCH until midnight",
            "Charity drive: 6x match for the food bank, give today",
            "St Jude 5x match: donate to the foundation",
            "Our church ministry has a 7x match, please give",
            "Nonprofit shelter appeal: 5x match, chip in"
        ]
        for body in benign {
            XCTAssertFalse(engine.isPolitical(body), "Should not be flagged: \(body)")
        }
    }

    func testRoundThreePhrasesAreNotStandaloneKeywords() {
        for term in ["5x match", "6x match", "7x match", "tariff rebate", "stimulus check", "midterm"] {
            XCTAssertFalse(DefaultFilterData.keywords.contains(term), "\(term) must be combined-only")
        }
    }

    func testMidtermWhitelistStillVetoesElectionGatedGroup() {
        XCTAssertFalse(defaultEngine().isPolitical("Midterm exam polls the class on the primary topic"))
    }

    // MARK: - Campaign gating (2.1.6)

    func testCampaignFlagsOnlyWithElectionContext() {
        let engine = defaultEngine()
        let political = [
            "Trump campaign needs you tonight",
            "Our campaign for governor is counting on you",
            "Campaign update: the Senate race is tightening",
            "Join the campaign, vote early",
            "Democrats campaign push: polls close Tuesday",
            "Your gift gets a 5x match on the campaign. Donate now"
        ]
        for body in political {
            XCTAssertTrue(engine.isPolitical(body), "Should be flagged: \(body)")
        }
    }

    func testCampaignAloneDoesNotFlagCharityOrMarketingTexts() {
        let engine = defaultEngine()
        let benign = [
            "Our fall food drive campaign for the food bank",
            "Our fall food drive campaign for the food bank starts Monday",
            "Email campaign launch is scheduled for Friday",
            "Our Kickstarter campaign is live",
            "The ad campaign shoots next week",
            "Marketing campaign review at 3pm"
        ]
        for body in benign {
            XCTAssertFalse(engine.isPolitical(body), "Should not be flagged: \(body)")
        }
    }

    func testCampaignIsNotAStandaloneKeywordButStaysADonationWord() {
        XCTAssertFalse(DefaultFilterData.keywords.contains("campaign"))
        XCTAssertTrue(DefaultFilterData.combinedTerms.contains(["5x match", "campaign"]))
        XCTAssertFalse(DefaultFilterData.combinedTerms.contains(["campaign", "campaign"]))
    }
}
