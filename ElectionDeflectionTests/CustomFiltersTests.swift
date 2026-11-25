import XCTest
@testable import ElectionDeflection

/// Custom Filters Pro (issue #5): storage, validation, rule order, parity, and Pro gating.
/// The pure logic (Shared/UserFilterRules.swift, Shared/ProEntitlementPolicy.swift) is also
/// covered on Linux by tools/LinuxLogicTests; these run the same files inside the app host.
///
/// MessageFilterExtension itself can't be instantiated from the unit-test bundle (see
/// MessageFilterExtensionTests), so "compiled once" is asserted on UserRuleEngine, which the
/// extension builds once in init() and reuses for every handle(_:) call.
final class CustomFiltersTests: XCTestCase {

    private var sut: SharedDataManager!
    private var testDefaults: UserDefaults!
    private let suite = "com.test.customFilters"

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: suite)
        testDefaults.removePersistentDomain(forName: suite)
        sut = SharedDataManager(defaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suite)
        testDefaults = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Storage

    func testUserFilterRulesDefaultToEmpty() {
        XCTAssertEqual(sut.userFilterRules, [])
    }

    func testUserFilterRulesRoundTripAcrossInstances() {
        let rules = [
            UserFilterRule(pattern: "flash sale", kind: .keyword, action: .block),
            UserFilterRule(pattern: "^mom:", kind: .regex, action: .alwaysAllow, isCaseSensitive: true)
        ]
        sut.userFilterRules = rules
        XCTAssertEqual(SharedDataManager(defaults: testDefaults).userFilterRules, rules)
    }

    func testGarbageStoredDataDecodesToEmpty() {
        testDefaults.set(Data("garbage".utf8), forKey: SharedConstants.userFilterRulesKey)
        XCTAssertEqual(sut.userFilterRules, [])
        testDefaults.set("a string, not data", forKey: SharedConstants.userFilterRulesKey)
        XCTAssertEqual(sut.userFilterRules, [])
    }

    func testStoredFormatIsVersionedContainer() throws {
        sut.userFilterRules = [UserFilterRule(pattern: "x")]
        let data = try XCTUnwrap(testDefaults.data(forKey: SharedConstants.userFilterRulesKey))
        let obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(obj["version"] as? Int, 1)
    }

    func testSeedNeverReadsOrWritesUserRules() {
        let rules = [UserFilterRule(pattern: "keep me")]
        sut.userFilterRules = rules

        // Empty keyword list, stale fingerprint, then current — seed runs in each state.
        sut.seedDefaultFilterDataIfNeeded()
        XCTAssertEqual(sut.userFilterRules, rules)
        sut.keywordList = []
        sut.filterDataFingerprint = "stale"
        sut.seedDefaultFilterDataIfNeeded()
        XCTAssertEqual(sut.userFilterRules, rules)
    }

    func testSeedDoesNotCreateUserRulesKey() {
        sut.seedDefaultFilterDataIfNeeded()
        XCTAssertNil(testDefaults.object(forKey: SharedConstants.userFilterRulesKey))
    }

    // MARK: - Validation

    func testValidationLimits() {
        XCTAssertNil(UserFilterRuleValidator.validate(UserFilterRule(pattern: "ok"), existing: []))
        XCTAssertEqual(UserFilterRuleValidator.validate(UserFilterRule(pattern: "(["  , kind: .regex), existing: []), .invalidRegex)
        XCTAssertEqual(UserFilterRuleValidator.validate(UserFilterRule(pattern: String(repeating: "a", count: 201)), existing: []),
                       .patternTooLong(max: 200))
        let full = (0..<100).map { UserFilterRule(pattern: "r\($0)") }
        XCTAssertEqual(UserFilterRuleValidator.validate(UserFilterRule(pattern: "101st"), existing: full), .tooManyRules(max: 100))
    }

    func testCatastrophicBacktrackingRejected() {
        XCTAssertEqual(UserFilterRuleValidator.validate(UserFilterRule(pattern: "(a+)+$", kind: .regex), existing: []), .regexTooSlow)
    }

    @MainActor
    func testViewModelEnforcesLimitsAndProGate() {
        let vm = MyFiltersViewModel(dataManager: sut)
        XCTAssertNil(vm.save(UserFilterRule(pattern: "sale"), isProTier: true))
        XCTAssertEqual(sut.userFilterRules.count, 1)

        // Lapsed Pro: read-only — writes are ignored, stored rules are kept.
        XCTAssertNil(vm.save(UserFilterRule(pattern: "blocked while lapsed"), isProTier: false))
        vm.delete(at: IndexSet(integer: 0), isProTier: false)
        XCTAssertEqual(sut.userFilterRules.count, 1)

        XCTAssertEqual(vm.save(UserFilterRule(pattern: "(a+)+$", kind: .regex), isProTier: true), .regexTooSlow)
        XCTAssertEqual(sut.userFilterRules.count, 1)

        vm.delete(at: IndexSet(integer: 0), isProTier: true)
        XCTAssertEqual(sut.userFilterRules, [])
    }

    @MainActor
    func testViewModelRejectsHundredFirstRule() {
        sut.userFilterRules = (0..<100).map { UserFilterRule(pattern: "r\($0)") }
        let vm = MyFiltersViewModel(dataManager: sut)
        XCTAssertFalse(vm.canAddMore)
        XCTAssertEqual(vm.save(UserFilterRule(pattern: "one too many"), isProTier: true), .tooManyRules(max: 100))
        XCTAssertEqual(sut.userFilterRules.count, 100)
    }

    func testSuggestedPatternIsShortTrimmedAndWordBounded() {
        XCTAssertEqual(MyFiltersViewModel.suggestedPattern(from: "  hello \n  world  "), "hello world")
        let long = "Huge flash sale today only on every pair of shoes in the whole store, don't miss out"
        let suggestion = MyFiltersViewModel.suggestedPattern(from: long)
        XCTAssertLessThanOrEqual(suggestion.count, 40)
        XCTAssertTrue(long.hasPrefix(suggestion))
        XCTAssertFalse(suggestion.hasSuffix(" "))
    }

    // MARK: - Rule order, compile-once, parity, Pro gating

    func testAllowRuleBeatsBuiltInKeyword() {
        let builtIn = KeywordFilterEngine(keywords: ["vote"], whitelistContexts: [:], combinedTerms: [])
        let engine = UserRuleEngine(rules: [UserFilterRule(pattern: "pizza", action: .alwaysAllow)])
        XCTAssertTrue(builtIn.isPolitical("vote for pizza"))
        XCTAssertEqual(engine.evaluate("vote for pizza", isProTier: true), .allow)
    }

    func testBlockRuleFiresWhenBuiltInSaysNotPolitical() {
        let builtIn = KeywordFilterEngine(keywords: ["vote"], whitelistContexts: [:], combinedTerms: [])
        let engine = UserRuleEngine(rules: [UserFilterRule(pattern: "flash sale")])
        XCTAssertFalse(builtIn.isPolitical("Flash sale!"))
        XCTAssertEqual(engine.evaluate("Flash sale!", isProTier: true), .block)
    }

    func testZeroRulesChangesNothing() {
        XCTAssertNil(UserRuleEngine(rules: []).evaluate("vote now", isProTier: true))
    }

    func testRegexCompiledOncePerEngine() {
        let engine = UserRuleEngine(rules: [
            UserFilterRule(pattern: "a+", kind: .regex), UserFilterRule(pattern: "b+", kind: .regex)
        ])
        XCTAssertEqual(engine.compiledRegexCount, 2)
        for _ in 0..<20 { _ = engine.evaluate("aaa", isProTier: true) }
        XCTAssertEqual(engine.compiledRegexCount, 2)
    }

    func testProLapseKeepsRulesButDeactivatesThem() {
        sut.userFilterRules = [UserFilterRule(pattern: "sale")]
        let engine = UserRuleEngine(rules: sut.userFilterRules)
        XCTAssertEqual(engine.evaluate("big sale", isProTier: true), .block)
        XCTAssertNil(engine.evaluate("big sale", isProTier: false))
        XCTAssertEqual(sut.userFilterRules.count, 1)
        XCTAssertEqual(engine.evaluate("big sale", isProTier: true), .block)
    }

    func testFreeUsersHaveNoActiveRules() {
        let engine = UserRuleEngine(rules: [UserFilterRule(pattern: "sale", action: .alwaysAllow)])
        XCTAssertNil(engine.evaluate("sale", isProTier: false))
    }

    /// Extension and Filter Test both build UserRuleEngine from the same stored rules and call
    /// evaluate(_:isProTier:), so for fixed inputs their overrides must agree.
    func testExtensionAndAuditClassifierPathsAgree() {
        let rules = [
            UserFilterRule(pattern: "flash sale"),
            UserFilterRule(pattern: #"^mom\b"#, kind: .regex, action: .alwaysAllow),
            UserFilterRule(pattern: "vote", action: .alwaysAllow, isCaseSensitive: true)
        ]
        sut.userFilterRules = rules
        let extensionEngine = UserRuleEngine(rules: SharedDataManager(defaults: testDefaults).userFilterRules)
        let auditEngine = UserRuleEngine(rules: sut.userFilterRules)
        for message in ["FLASH SALE now", "Mom: call me", "please vote", "Please VOTE", "hello"] {
            for pro in [true, false] {
                XCTAssertEqual(extensionEngine.evaluate(message, isProTier: pro),
                               auditEngine.evaluate(message, isProTier: pro), message)
            }
        }
    }

    // MARK: - Privacy

    func testSubmissionPayloadTypesDoNotReferenceUserRules() {
        // Rules live only under userFilterRulesKey; the submission service must not read it.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ElectionDeflection/Services/TextSubmissionService.swift")
        guard let source = try? String(contentsOf: url) else {
            return XCTFail("Could not read TextSubmissionService.swift from source tree")
        }
        XCTAssertFalse(source.contains("userFilterRules"))
        XCTAssertFalse(source.contains("UserFilterRule"))
    }
}
