import Foundation

// MARK: - Rule model

/// A Pro user's custom filter rule (issue #5). Foundation-only so it compiles in the
/// app, the MessageFilter extension, the share extension, and the Linux logic-test package.
///
/// Stored on-device only (App Group key `SharedConstants.userFilterRulesKey`) and never
/// included in Text Submission payloads.
struct UserFilterRule: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case keyword
        case regex
    }

    enum Action: String, Codable, CaseIterable {
        case block
        case alwaysAllow
    }

    var id: UUID
    var pattern: String
    var kind: Kind
    var action: Action
    var isCaseSensitive: Bool

    init(id: UUID = UUID(), pattern: String, kind: Kind = .keyword,
         action: Action = .block, isCaseSensitive: Bool = false) {
        self.id = id
        self.pattern = pattern
        self.kind = kind
        self.action = action
        self.isCaseSensitive = isCaseSensitive
    }
}

// MARK: - Versioned storage

/// Versioned container so a future schema change (e.g. a per-rule enabled toggle) can
/// migrate by switching on `version` instead of silently dropping fields or wiping rules.
struct UserFilterRuleSet: Codable, Equatable {
    var version: Int
    var rules: [UserFilterRule]
}

enum UserFilterRuleCodec {
    static let currentVersion = 1

    static func encode(_ rules: [UserFilterRule]) -> Data? {
        try? JSONEncoder().encode(UserFilterRuleSet(version: currentVersion, rules: rules))
    }

    /// Missing, garbage, or unknown-future-version data decodes to `[]` — never throws.
    static func decode(_ data: Data?) -> [UserFilterRule] {
        guard let data, let set = try? JSONDecoder().decode(UserFilterRuleSet.self, from: data) else {
            return []
        }
        switch set.version {
        case 1:
            return set.rules
        default:
            return []
        }
    }
}

// MARK: - Validation

enum UserFilterRuleError: Error, Equatable {
    case emptyPattern
    case patternTooLong(max: Int)
    case tooManyRules(max: Int)
    case invalidRegex
    case regexTooSlow

    var message: String {
        switch self {
        case .emptyPattern:
            return "Enter a word, phrase, or pattern."
        case .patternTooLong(let max):
            return "Patterns can be at most \(max) characters."
        case .tooManyRules(let max):
            return "You can have at most \(max) rules. Delete one to add another."
        case .invalidRegex:
            return "This isn't a valid regular expression."
        case .regexTooSlow:
            return "This regular expression is too slow or complex. Try a simpler pattern."
        }
    }
}

enum UserFilterRuleValidator {
    static let maxRules = 100
    static let maxPatternLength = 200
    /// Wall-clock budget for the save-time pathological-regex check.
    static let regexTimeBudget: TimeInterval = 0.05

    /// Fixed corpus the timing guard runs every regex against: short and long ordinary
    /// messages plus near-miss inputs that make nested quantifiers (e.g. `(a+)+`) blow up.
    static let timingCorpus: [String] = [
        "Hello, are we still on for lunch tomorrow?",
        "Your package has shipped and will arrive on Tuesday. Track it at the usual link.",
        String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 12),
        String(repeating: "a", count: 40) + "!",
        String(repeating: "ab", count: 24) + "!",
        String(repeating: "1", count: 40) + "x",
        String(repeating: " ", count: 40) + "x"
    ]

    /// Validates adding `candidate` to `existing` (or replacing the rule with the same id).
    /// Returns nil when valid, otherwise the first problem found.
    /// Run in the main app before persisting — pathological patterns must never reach
    /// the extension.
    static func validate(_ candidate: UserFilterRule,
                         existing: [UserFilterRule],
                         timeBudget: TimeInterval = regexTimeBudget) -> UserFilterRuleError? {
        let isReplacement = existing.contains { $0.id == candidate.id }
        if !isReplacement && existing.count >= maxRules {
            return .tooManyRules(max: maxRules)
        }
        if candidate.pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .emptyPattern
        }
        if candidate.pattern.count > maxPatternLength {
            return .patternTooLong(max: maxPatternLength)
        }
        if candidate.kind == .regex {
            guard let regex = UserRuleEngine.compile(candidate) else {
                return .invalidRegex
            }
            if !runsWithinBudget(regex, budget: timeBudget) {
                return .regexTooSlow
            }
        }
        return nil
    }

    /// Runs the regex over `timingCorpus` on a background thread and waits up to `budget`
    /// seconds in total. NSRegularExpression cannot be interrupted, so on timeout the
    /// worker is abandoned (it finishes on its own) and the pattern is rejected.
    private static func runsWithinBudget(_ regex: NSRegularExpression, budget: TimeInterval) -> Bool {
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            for text in timingCorpus {
                let range = NSRange(text.startIndex..., in: text)
                _ = regex.firstMatch(in: text, options: [], range: range)
            }
            done.signal()
        }
        return done.wait(timeout: .now() + budget) == .success
    }
}

// MARK: - Matching engine

/// Pure user-rule matching shared by MessageFilterExtension and FilterAuditClassifier so
/// their decisions can't drift apart. Regex rules are compiled once at init and reused
/// for the lifetime of the instance — never per message.
///
/// Rule order (see docs/plans/custom-filters-pro.md): "always allow" rules beat "block"
/// rules, and a decision from either beats all built-in keyword/ML logic. No decision
/// (`nil`) means the caller falls through to its existing logic unchanged.
struct UserRuleEngine {
    enum Decision: Equatable {
        case allow
        case block
    }

    private struct CompiledRule {
        let rule: UserFilterRule
        let regex: NSRegularExpression?
        /// Pre-lowercased keyword for case-insensitive keyword rules.
        let keyword: String
    }

    private let allowRules: [CompiledRule]
    private let blockRules: [CompiledRule]

    /// Number of regex rules that compiled successfully (rules that fail to compile are skipped).
    let compiledRegexCount: Int

    init(rules: [UserFilterRule]) {
        var allow: [CompiledRule] = []
        var block: [CompiledRule] = []
        var regexCount = 0
        for rule in rules where !rule.pattern.isEmpty {
            let compiled: CompiledRule
            switch rule.kind {
            case .keyword:
                compiled = CompiledRule(rule: rule, regex: nil,
                                        keyword: rule.isCaseSensitive ? rule.pattern : rule.pattern.lowercased())
            case .regex:
                guard let regex = Self.compile(rule) else { continue }
                regexCount += 1
                compiled = CompiledRule(rule: rule, regex: regex, keyword: "")
            }
            switch rule.action {
            case .alwaysAllow: allow.append(compiled)
            case .block: block.append(compiled)
            }
        }
        allowRules = allow
        blockRules = block
        compiledRegexCount = regexCount
    }

    var isEmpty: Bool { allowRules.isEmpty && blockRules.isEmpty }

    static func compile(_ rule: UserFilterRule) -> NSRegularExpression? {
        let options: NSRegularExpression.Options = rule.isCaseSensitive ? [] : [.caseInsensitive]
        return try? NSRegularExpression(pattern: rule.pattern, options: options)
    }

    /// Custom rules are a Pro feature: free users (and lapsed Pro users, whose rules are
    /// kept but inactive) always get `nil`.
    func evaluate(_ body: String, isProTier: Bool) -> Decision? {
        guard isProTier else { return nil }
        return decision(for: body)
    }

    func decision(for body: String) -> Decision? {
        guard !isEmpty else { return nil }
        let lowercased = body.lowercased()
        if allowRules.contains(where: { matches($0, body: body, lowercased: lowercased) }) {
            return .allow
        }
        if blockRules.contains(where: { matches($0, body: body, lowercased: lowercased) }) {
            return .block
        }
        return nil
    }

    private func matches(_ compiled: CompiledRule, body: String, lowercased: String) -> Bool {
        if let regex = compiled.regex {
            let range = NSRange(body.startIndex..., in: body)
            return regex.firstMatch(in: body, options: [], range: range) != nil
        }
        return compiled.rule.isCaseSensitive
            ? body.contains(compiled.keyword)
            : lowercased.contains(compiled.keyword)
    }
}
