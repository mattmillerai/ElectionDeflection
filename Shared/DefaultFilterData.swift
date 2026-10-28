import Foundation

/// Default filter data constants used for seeding SharedDataManager, and for refreshing
/// it whenever these constants change (see `fingerprint` below) — e.g. when a new
/// keyword like "stop=end" is added (issue #3) and existing users' seeded copy would
/// otherwise never pick it up.
/// This file preserves the exact keyword list, whitelist contexts, and combined terms
/// from the v1.0 MessageFilterExtension implementation, updated over time as new terms
/// are added.
/// Both the app and extension targets must include this file in their Compile Sources
/// build phase.
enum DefaultFilterData {

    // MARK: - Keywords (v1.0 — 400+ political terms)

    static let keywords: [String] = [
        "trump", "vance", "harris", "walz", "election", "vote", "campaign", "giuliani", "kamala", "democrat", "republican", "senate", "cruz", "congress", "impeach", "ballot", "radical left", "far right", "cmp.lk", "jim jordan", "fundprogress", "dems ", "gop ", " gop:", "kellyanne conway", "steve garvey", "gov. abbott", "governor abbott", "win4tx.org", "biden", "potus", " dems ", "left-wing", "right-wing", "super pac", "actblue", "winred", "dnc ", "rnc ", "pelosi", "chuck schumer", "mitch mcconnell", "lindsey graham", "bernie sanders", "elizabeth warren", "alexandria ocasio-cortez", "aoc ", "ron desantis", "mike pence", "nikki haley", "newsom", "marjorie taylor greene", "matt gaetz", "lauren boebert", "kevin mccarthy", "dm24.co", "bob casey", "dave mccormick", "rep-24", "reagan", "usred.co", "kari lake", "hannity", "maddow", "24-red", "gop-victory.com", "vivek", "ramaswamy", "cheney", "clinton", "obama", "dan osborn", "deb fischer", "vote24.io", "savedemocracypac", "letamericavote", "momsfedup", "lincoln project", "electdemsnow", "boldpac", "hmpac", "electdemocracticwomen", "bluewave", "demmajority", "retireddemocrat", "demgovs", "tim kaine", "trustrightusa", "israelsrvy", "cbcpac", "colin allred", "colinallred.com", "24win.co", "blue wave", "goplink", "tth07", "runityfund", "right-24", "pompeo", "gv077.org", "byron donalds", "gop.", "demturnout", "turnout", "go-24", "tammy baldwin", "fundraising", "elissa slotkin", "haley stevens", "haley4mi", "realclearpolitics", "shawn harris", "charlie kirk", "tpusa", "turning point", "laura loomer", "newt gingrich", "safegive24", "win24", "presidential poll", "drain the swamp", "trustgopusa", "deep state", " cnn ", " msnbc ", " fox news ", "dems-vote", "schiff", "secureliberty", "garvey", "anna paulina luna", "doj", "givegopnow", "robert f. kennedy", "rfk", "ron johnson", "senator", "rep.", "team mackenzie", "the left", "derrick van orden", "kennedy", "rubio", "for.gop", "hawley", " sen. ", "clarence thomas", "patriot", "donor", "gopgift", "nancy mace", "jack smith", "soros", ".gop/", "bannon", "stephen miller", "usgiv", "gv070", "growth action", "kyrsten sinema", "ruben gallego", "kari lake", "rick scott", "mucarsel-powell", "ben cardin", "alsobrooks", "larry hogan", "mike rogers", "stabenow", "slotkin", "jon tester", "tim sheehy", "manchin", "klobuchar", "josh hawley", "romney", "electoral", "don jr", " maga ", "blue victory", "bluevictory", "gv088.org", "8x match", "9x match", "10x match", "gopclick.io", "redsend.net", "hegseth", "scalise", "giv.win", "gv099", "2024wave", "vtred",
        "gv000", "gv001", "gv002", "gv003", "gv004", "gv005", "gv006", "gv007", "gv008", "gv009",
        "gv010", "gv011", "gv012", "gv013", "gv014", "gv015", "gv016", "gv017", "gv018", "gv019",
        "gv020", "gv021", "gv022", "gv023", "gv024", "gv025", "gv026", "gv027", "gv028", "gv029",
        "gv030", "gv031", "gv032", "gv033", "gv034", "gv035", "gv036", "gv037", "gv038", "gv039",
        "gv040", "gv041", "gv042", "gv043", "gv044", "gv045", "gv046", "gv047", "gv048", "gv049",
        "gv050", "gv051", "gv052", "gv053", "gv054", "gv055", "gv056", "gv057", "gv058", "gv059",
        "gv060", "gv061", "gv062", "gv063", "gv064", "gv065", "gv066", "gv067", "gv068", "gv069",
        "gv070", "gv071", "gv072", "gv073", "gv074", "gv075", "gv076", "gv077", "gv078", "gv079",
        "gv080", "gv081", "gv082", "gv083", "gv084", "gv085", "gv086", "gv087", "gv088", "gv089",
        "gv090", "gv091", "gv092", "gv093", "gv094", "gv095", "gv096", "gv097", "gv098", "gv099",
        "gv100", "gv101", "gv102", "gv103", "gv104", "gv105", "gv106", "gv107", "gv108", "gv109",
        "gv110", "gv111", "gv112", "gv113", "gv114", "gv115", "gv116", "gv117", "gv118", "gv119",
        "gv120", "gv121", "gv122", "gv123", "gv124", "gv125", "gv126", "gv127", "gv128", "gv129",
        "gv130", "gv131", "gv132", "gv133", "gv134", "gv135", "gv136", "gv137", "gv138", "gv139",
        "gv140", "gv141", "gv142", "gv143", "gv144", "gv145", "gv146", "gv147", "gv148", "gv149",
        "gv150", "gv151", "gv152", "gv153", "gv154", "gv155", "gv156", "gv157", "gv158", "gv159",
        "gv160", "gv161", "gv162", "gv163", "gv164", "gv165", "gv166", "gv167", "gv168", "gv169",
        "gv170", "gv171", "gv172", "gv173", "gv174", "gv175", "gv176", "gv177", "gv178", "gv179",
        "gv180", "gv181", "gv182", "gv183", "gv184", "gv185", "gv186", "gv187", "gv188", "gv189",
        "gv190", "gv191", "gv192", "gv193", "gv194", "gv195", "gv196", "gv197", "gv198", "gv199",
        "gv200",
        "r-txt.com", "r-txt.org", "r-txt.net", "alvin bragg", "kathy hocul", "giv.red", "greg abbott", "tx-win", "kash patel", "magaus", "20giv", "mike johnson", "chip24", "glenn youngkin", "tulsi gabbard", "franklin graham",
        "gop25", "gop24", "gop26", "gop27", "gop28", "gop29", "gop30", "gop31", "gop32", "gop33", "gop34", "gop35", "gop36", "gop37", "gop45", "gop47",
        "america first alliance", "redvt.cc", "saveusa", " gop's ", "djt", "DOGE", "D.O.G.E.", "gop1poll", "elise stefanik", "stefanik", "house majority", "epstein files", "speaker johnson", "fundnow", "fake news", "leftist", "eli crane", "democracyfirstpac", "white house", "situation room", "patriot consensus",
        "rep25", "rep26", "rep27", "rep28",
        "susan collins", "jordan wood", "race against", "cory booker", "redtxt.vip", "mike lee", "chip roy", "tap2go", "tom homan", "ice agent", "clkgo", "tucker carlson", "preborn",
        // 2026 cycle — from user-submission triage (tools/feedback). The 2024 short-domains
        // above (gv/gop24) are stale; these are the rotating 2026 hosts seen in the wild.
        "us-26.co", "win26.io", "usa26.io", "26u5a.co", "rght26.io", "win-red.io", "26-win.org", "right26.co", "rep2026.co",
        // 2026 fundraising hosts from the 2026-10-28 KV triage: each has ≥3 labeled:political hits and
        // 0 not_political hits. Bare hosts, so both "host/path" and "https://host/path" (and t./r. subdomains) match.
        "crushmaga.io", "raaction.io", "edw-now.org", "progressaf.com", "takeoverfund.io", "demsfight.com", "win-26.us",
        "bold-lead.org", "ameripacfuture.org", "pia4fl.io", "helpdemswin.io", "gop-poll.com", "26text.com", "an4fl.com",
        // Spam opt-out obfuscation legit senders never use (they write "reply STOP"); "stop to end" and
        // "reply stop to opt-out" are intentionally excluded (combined-only) — they collide with legitimate
        // "reply STOP to end" language.
        "stop=end", "stop2end", "end2end", "stoptoend"
    ]

    // MARK: - Whitelist Contexts (v1.0)

    static let whitelistContexts: [String: [String]] = [
        "kennedy": [
            "kennedy center",
            "kennedy center honors",
            "kennedy space center"
        ],
        "vote": [
            "batterysf.com/v/",
            "battery powered vote",
            "san francisco resurgence vote",
            "battery sf vote"
        ],
        "voting": [
            "batterysf.com/v/",
            "battery powered voting",
            "san francisco resurgence voting",
            "battery sf voting"
        ],
        "election": [
            "ballot.trax"
        ],
        "ballot": [
            "ballot.trax"
        ],
        "reply stop": [
            ".edu"
        ]
    ]

    // MARK: - Combined Terms (v1.0)

    static let combinedTerms: [[String]] = [
        ["musk", "stop=end"],
        ["musk", "stop to end"],
        ["musk", "reply stop"],
        ["musk", "stop2end"],
        ["elon", "stop=end"],
        ["elon", "stop to end"],
        ["elon", "reply stop"],
        ["elon", "stop2end"],
        ["democracy", "stop=end"],
        ["democracy", "stop to end"],
        ["democracy", "reply stop"],
        ["democracy", "stop2end"],
    ]
}

// MARK: - Content Fingerprint

extension DefaultFilterData {

    /// Fingerprint of the current bundled keywords/whitelistContexts/combinedTerms.
    /// SharedDataManager stores this when it seeds, and reseeds whenever the stored
    /// value no longer matches — i.e. whenever this file's data changes.
    static var fingerprint: String {
        fingerprint(keywords: keywords, whitelistContexts: whitelistContexts, combinedTerms: combinedTerms)
    }

    /// Deterministic FNV-1a hash of a canonical serialization (dictionary keys sorted,
    /// so Dictionary's nondeterministic ordering can't affect the result). Must stay
    /// stable across launches and processes, so this deliberately does NOT use Swift's
    /// `hashValue`/`Hasher`, which are randomized per-process.
    static func fingerprint(keywords: [String], whitelistContexts: [String: [String]], combinedTerms: [[String]]) -> String {
        let unitSeparator = "\u{1}"
        let recordSeparator = "\u{2}"
        let sectionSeparator = "\u{3}"

        let keywordsSection = keywords.joined(separator: unitSeparator)
        let whitelistSection = whitelistContexts.keys.sorted().map { key in
            "\(key)=\(whitelistContexts[key]!.joined(separator: unitSeparator))"
        }.joined(separator: recordSeparator)
        let combinedSection = combinedTerms.map { $0.joined(separator: unitSeparator) }.joined(separator: recordSeparator)

        let canonical = [keywordsSection, whitelistSection, combinedSection].joined(separator: sectionSeparator)

        var hash: UInt64 = 0xcbf29ce484222325
        for byte in canonical.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}

// MARK: - Keyword Filter Engine

/// Pure keyword-matching decision: given keywords, whitelist contexts, and combined
/// terms, decides whether a message body counts as political. This is the single
/// implementation shared by MessageFilterExtension and FilterAuditClassifier, so their
/// decisions can never drift apart. Semantics (case-insensitive; combined terms checked
/// first; a keyword match is bypassed when the body also contains one of that keyword's
/// whitelisted phrases) are unchanged from the original per-target implementations.
struct KeywordFilterEngine {
    let keywords: [String]
    let whitelistContexts: [String: [String]]
    let combinedTerms: [[String]]

    init(keywords: [String], whitelistContexts: [String: [String]], combinedTerms: [[String]]) {
        self.keywords = keywords
        self.whitelistContexts = whitelistContexts
        self.combinedTerms = combinedTerms
    }

    func isPolitical(_ body: String) -> Bool {
        let lowercased = body.lowercased()

        for group in combinedTerms where group.allSatisfy({ lowercased.contains($0.lowercased()) }) {
            return true
        }

        for keyword in keywords where lowercased.contains(keyword.lowercased()) {
            if let whitelistedPhrases = whitelistContexts[keyword.lowercased()],
               whitelistedPhrases.contains(where: { lowercased.contains($0.lowercased()) }) {
                continue
            }
            return true
        }

        return false
    }
}
