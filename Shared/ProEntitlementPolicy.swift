import Foundation

/// A purchase transaction reduced to the fields entitlement logic needs, so the policy
/// stays Foundation-only (no StoreKit) and unit-testable on Linux.
struct EntitlementCandidate: Equatable {
    let productID: String
    /// nil for non-consumables (lifetime).
    let expirationDate: Date?
    let isRevoked: Bool

    init(productID: String, expirationDate: Date?, isRevoked: Bool = false) {
        self.productID = productID
        self.expirationDate = expirationDate
        self.isRevoked = isRevoked
    }
}

/// Which product IDs grant Pro, and which transaction wins when several are present.
enum ProEntitlementPolicy {
    /// Every product that unlocks Pro (and therefore Custom Filters). A Family annual
    /// purchase received through Family Sharing arrives as a transaction for the same
    /// product ID, so it is covered here too.
    static let proProductIDs: Set<String> = [
        SharedConstants.proAnnualProductID,
        SharedConstants.proFamilyAnnualProductID,
        SharedConstants.proLifetimeProductID
    ]

    static func isFamilyProduct(_ productID: String) -> Bool {
        productID == SharedConstants.proFamilyAnnualProductID
    }

    /// Relative strength of a product: lifetime > Family annual > individual annual.
    /// Family and individual annual share a subscription group where Family is the higher
    /// service level, so Family outranks individual regardless of expiration date.
    static func level(of productID: String) -> Int {
        switch productID {
        case SharedConstants.proLifetimeProductID: return 3
        case SharedConstants.proFamilyAnnualProductID: return 2
        case SharedConstants.proAnnualProductID: return 1
        default: return 0
        }
    }

    /// Picks the best active entitlement: a non-revoked lifetime purchase always wins;
    /// otherwise the non-revoked, unexpired subscription with the highest level (Family over
    /// individual, as can briefly be reported both after an in-group upgrade), with the latest
    /// expiration breaking ties. Returns nil when nothing unlocks Pro (expired, revoked, or
    /// unrelated products).
    static func bestEntitlement(from candidates: [EntitlementCandidate],
                                productIDs: Set<String> = proProductIDs,
                                now: Date = Date()) -> EntitlementCandidate? {
        var best: EntitlementCandidate?
        for candidate in candidates where productIDs.contains(candidate.productID) && !candidate.isRevoked {
            guard let expiration = candidate.expirationDate else { return candidate }
            guard expiration > now else { continue }
            if let current = best, let currentExpiration = current.expirationDate {
                let (newLevel, curLevel) = (level(of: candidate.productID), level(of: current.productID))
                if curLevel > newLevel { continue }
                if curLevel == newLevel && currentExpiration >= expiration { continue }
            }
            best = candidate
        }
        return best
    }
}

/// Whether a given product may be purchased right now, given what the user already holds.
enum PurchaseEligibility: Equatable {
    /// Nothing blocks the purchase (free user, or a different non-subscription product).
    case allowed
    /// An in-group move to a higher service level (individual annual -> Family annual).
    /// StoreKit applies it immediately and Apple prorates the remaining time.
    case upgrade
    /// The user already holds exactly this product.
    case currentPlan
    case blocked(Reason)

    enum Reason: Equatable {
        /// Lifetime already unlocks everything; nothing else is worth buying.
        case lifetimeOwned
        /// Family -> individual would be a downgrade; the user must let Family lapse first.
        case downgrade
        case unknownProduct
    }

    /// True when the purchase should go through `product.purchase()`.
    var canPurchase: Bool {
        switch self {
        case .allowed, .upgrade: return true
        case .currentPlan, .blocked: return false
        }
    }
}

extension ProEntitlementPolicy {
    /// Decides whether `targetProductID` can be bought given the user's current best entitlement
    /// (nil = free). An expired or revoked entitlement counts as free.
    ///
    /// Lifetime from a subscription is ALLOWED: the Pro screen has always shown the Lifetime card
    /// to subscribers, and it is a separate non-subscription product (the user may then cancel
    /// the subscription). The reverse is not offered: a lifetime owner is blocked from everything.
    static func purchaseEligibility(current: EntitlementCandidate?,
                                    target targetProductID: String,
                                    now: Date = Date()) -> PurchaseEligibility {
        guard proProductIDs.contains(targetProductID) else { return .blocked(.unknownProduct) }
        guard let current, !current.isRevoked, proProductIDs.contains(current.productID) else { return .allowed }
        if let expiration = current.expirationDate, expiration <= now { return .allowed }

        if current.productID == targetProductID { return .currentPlan }
        switch current.productID {
        case SharedConstants.proLifetimeProductID:
            return .blocked(.lifetimeOwned)
        case SharedConstants.proFamilyAnnualProductID:
            return targetProductID == SharedConstants.proAnnualProductID ? .blocked(.downgrade) : .allowed
        default: // individual annual
            return targetProductID == SharedConstants.proFamilyAnnualProductID ? .upgrade : .allowed
        }
    }
}

/// What the main app last verified about the user's entitlement, persisted in the App Group so
/// the message filter extension (no StoreKit / Keychain / network) can decide on its own whether
/// a subscription has run out since the app last ran.
struct ProEntitlementSnapshot: Equatable {
    /// Last verified entitled product ID, kept after a lapse so the UI can tell a lapsed
    /// subscriber from a never-subscribed user. nil = never written (legacy or free).
    var productID: String?
    /// nil for lifetime (non-consumable).
    var expirationDate: Date?
    /// The legacy boolean cache (`proTierStatus`).
    var cachedFlag: Bool
}

extension ProEntitlementPolicy {
    /// Annual subscriptions (individual and Family): they expire and can lapse.
    static func isSubscriptionProduct(_ productID: String?) -> Bool {
        productID == SharedConstants.proAnnualProductID || productID == SharedConstants.proFamilyAnnualProductID
    }

    /// Read-only evaluation of a persisted snapshot. Foundation-only so the extension can call it.
    /// - Lifetime is always entitled, even if an expiration date is somehow present.
    /// - Annual (individual or Family): entitled iff `expirationDate > now`; a missing expiration is NOT entitled
    ///   (never invent lifetime).
    /// - No product ID (legacy boolean-only user who has not opened the app since the update):
    ///   fall back to the cached boolean. This is a one-shot migration: the next entitlement check
    ///   in the app writes a full snapshot, after which the boolean is no longer consulted.
    /// - Unknown product ID: not entitled.
    static func isEntitled(_ snapshot: ProEntitlementSnapshot, now: Date = Date()) -> Bool {
        guard let productID = snapshot.productID else { return snapshot.cachedFlag }
        if productID == SharedConstants.proLifetimeProductID { return true }
        guard isSubscriptionProduct(productID), let expiration = snapshot.expirationDate else {
            return false
        }
        return expiration > now
    }

    /// True when the snapshot is an annual subscription that is no longer entitled. Lifetime,
    /// legacy and never-subscribed snapshots are never "lapsed".
    static func isLapsedSubscription(_ snapshot: ProEntitlementSnapshot, now: Date = Date()) -> Bool {
        guard isSubscriptionProduct(snapshot.productID) else { return false }
        return !isEntitled(snapshot, now: now)
    }

    /// Snapshot to persist after a verified entitlement check.
    /// - entitled: the winning product and expiration.
    /// - not entitled, previously a subscriber: keep the product ID with an expiration no later
    ///   than `now` (a refund/revocation can leave the old date in the future), marking the lapse.
    /// - not entitled otherwise (never subscribed, or lifetime revoked): empty snapshot.
    static func snapshotAfterCheck(entitlement: EntitlementCandidate?,
                                   previous: ProEntitlementSnapshot,
                                   now: Date = Date()) -> ProEntitlementSnapshot {
        if let entitlement {
            return ProEntitlementSnapshot(productID: entitlement.productID,
                                          expirationDate: entitlement.expirationDate,
                                          cachedFlag: true)
        }
        if isSubscriptionProduct(previous.productID) {
            let expiration = min(previous.expirationDate ?? now, now)
            return ProEntitlementSnapshot(productID: previous.productID, expirationDate: expiration, cachedFlag: false)
        }
        return ProEntitlementSnapshot(productID: nil, expirationDate: nil, cachedFlag: false)
    }

    /// Pro state to adopt at launch before StoreKit has answered. A stored snapshot wins over the
    /// Keychain so a stale Keychain `true` cannot resurrect an expired entitlement (or one whose
    /// lifetime was revoked). Without a snapshot (legacy), the Keychain value is used if present,
    /// otherwise the cached boolean.
    static func launchEntitlement(keychainValue: Bool?, snapshot: ProEntitlementSnapshot,
                                  now: Date = Date()) -> Bool {
        if snapshot.productID != nil { return isEntitled(snapshot, now: now) }
        return keychainValue ?? snapshot.cachedFlag
    }
}
