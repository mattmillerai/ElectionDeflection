import Foundation

/// A verified entitlement reduced to the fields the policy needs, so it stays Foundation-only
/// (no StoreKit) and unit-testable on Linux.
struct EntitlementCandidate: Equatable {
    let productID: String
    /// nil for non-consumables (lifetime).
    let expirationDate: Date?
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

enum ProEntitlementPolicy {
    /// Read-only evaluation of a persisted snapshot. Foundation-only so the extension can call it.
    /// - Lifetime is always entitled, even if an expiration date is somehow present.
    /// - Annual: entitled iff `expirationDate > now`; a missing expiration is NOT entitled
    ///   (never invent lifetime).
    /// - No product ID (legacy boolean-only user who has not opened the app since the update):
    ///   fall back to the cached boolean. This is a one-shot migration: the next entitlement check
    ///   in the app writes a full snapshot, after which the boolean is no longer consulted.
    /// - Unknown product ID: not entitled.
    static func isEntitled(_ snapshot: ProEntitlementSnapshot, now: Date = Date()) -> Bool {
        guard let productID = snapshot.productID else { return snapshot.cachedFlag }
        if productID == SharedConstants.proLifetimeProductID { return true }
        guard productID == SharedConstants.proAnnualProductID, let expiration = snapshot.expirationDate else {
            return false
        }
        return expiration > now
    }

    /// True when the snapshot is an annual subscription that is no longer entitled. Lifetime,
    /// legacy and never-subscribed snapshots are never "lapsed".
    static func isLapsedSubscription(_ snapshot: ProEntitlementSnapshot, now: Date = Date()) -> Bool {
        guard snapshot.productID == SharedConstants.proAnnualProductID else { return false }
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
        if previous.productID == SharedConstants.proAnnualProductID {
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
