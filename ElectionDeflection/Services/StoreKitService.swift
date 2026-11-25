import StoreKit
import os.log

/// Abstraction over StoreKit product loading for testability.
protocol ProductFetching: Sendable {
    func products(for identifiers: Set<String>) async throws -> [Product]
}

/// Default implementation that calls the real StoreKit 2 API.
struct StoreKitProductFetcher: ProductFetching {
    func products(for identifiers: Set<String>) async throws -> [Product] {
        try await Product.products(for: identifiers)
    }
}

/// Abstraction over AppStore sync operations.
protocol StoreSyncing: Sendable {
    func sync() async throws
}

struct AppStoreSyncer: StoreSyncing {
    func sync() async throws {
        try await AppStore.sync()
    }
}

/// Abstraction over the purchase action for testability.
protocol PurchasePerforming: Sendable {
    func purchase(_ product: Product) async throws -> Product.PurchaseResult
}

struct StoreKitPurchasePerformer: PurchasePerforming {
    func purchase(_ product: Product) async throws -> Product.PurchaseResult {
        try await product.purchase()
    }
}

/// Detail about the active entitlement, used to derive subscription status.
struct EntitlementDetail: Equatable {
    let productID: String
    let expirationDate: Date?  // nil for lifetime (non-consumable)
}

/// Abstraction over entitlement checking.
protocol EntitlementChecking: Sendable {
    func isEntitled(productIDs: Set<String>) async -> Bool
    func entitlementDetail(productIDs: Set<String>) async -> EntitlementDetail?
}

struct StoreKitEntitlementChecker: EntitlementChecking {
    func isEntitled(productIDs: Set<String>) async -> Bool {
        await entitlementDetail(productIDs: productIDs) != nil
    }

    func entitlementDetail(productIDs: Set<String>) async -> EntitlementDetail? {
        // currentEntitlements includes purchases shared via Family Sharing (same product ID),
        // so a Family annual received from a family organizer unlocks Pro like a direct purchase.
        // Winner selection (lifetime first, else latest-expiring active subscription) lives
        // in the Foundation-only ProEntitlementPolicy so it is unit-tested on Linux too.
        var candidates: [EntitlementCandidate] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            candidates.append(EntitlementCandidate(
                productID: transaction.productID,
                expirationDate: transaction.expirationDate,
                isRevoked: transaction.revocationDate != nil
            ))
        }
        return ProEntitlementPolicy.bestEntitlement(from: candidates, productIDs: productIDs).map {
            EntitlementDetail(productID: $0.productID, expirationDate: $0.expirationDate)
        }
    }
}

/// Loads and caches IAP product information using StoreKit 2.
/// Main app only — the extension does NOT use this service.
@MainActor
final class StoreKitService: ObservableObject {

    static let shared = StoreKitService()

    // MARK: - Dependency Injection Support for Testing
    
    /// Internal initializer for testing with custom dependencies
    static func makeForTesting(
        userDefaults: UserDefaults,
        productFetcher: ProductFetching,
        storeSyncer: StoreSyncing,
        entitlementChecker: EntitlementChecking,
        purchasePerformer: PurchasePerforming = StoreKitPurchasePerformer()
    ) -> StoreKitService {
        return StoreKitService(
            defaults: userDefaults,
            productFetcher: productFetcher,
            storeSyncer: storeSyncer,
            entitlementChecker: entitlementChecker,
            purchasePerformer: purchasePerformer
        )
    }

    static let cacheKey = "cachedIAPProductDisplayData"

    static let loadErrorMessage = "Unable to load pricing. Please try again later."
    static let purchaseFailedMessage = "Purchase failed. Please try again."
    static let networkErrorMessage = "Cannot connect to the App Store. Check your internet connection and try again."
    static let alreadyOwnedMessage = "You already have Pro access!"
    static let pendingMessage = "Purchase pending approval. You'll get access once approved."
    static let unverifiedMessage = "Purchase could not be verified. Please try again."
    static let restoreFailedMessage = "Restore failed. Please try again."
    static let restoreSuccessMessage = "Pro tier restored successfully!"
    static let restoreNoPurchaseMessage = "No previous purchase found."

    /// Outcome of a purchase attempt, used by the UI to update state.
    enum PurchaseOutcome: Equatable {
        case success
        case pending
        case cancelled
        case unverified
        case alreadyOwned
        case networkError
        case failed
    }

    /// Outcome of a restore attempt, used by the UI to update state.
    enum RestoreOutcome: Equatable {
        case restored
        case noPurchaseFound
        case failed
    }

    /// Current subscription status for UI display.
    enum SubscriptionStatus: Equatable {
        case annual(renewalDate: Date)
        case familyAnnual(renewalDate: Date)
        case lifetime
        case none

        /// True for auto-renewing subscriptions (individual or Family), which have a
        /// manageable App Store subscription; false for lifetime and none.
        var isSubscription: Bool {
            switch self {
            case .annual, .familyAnnual: return true
            case .lifetime, .none: return false
            }
        }

        var displayLabel: String {
            switch self {
            case .annual: return "Pro — Annual"
            case .familyAnnual: return "Pro — Family Annual"
            case .lifetime: return "Pro — Lifetime"
            case .none: return "Pro"
            }
        }
    }

    /// Loaded StoreKit Product objects (empty until loadProducts() completes).
    @Published private(set) var products: [Product] = []

    /// Whether a product loading request is in progress.
    @Published private(set) var isLoading = false

    /// User-facing error message from the most recent load attempt, or nil if successful.
    @Published private(set) var errorMessage: String?

    /// Whether the user has an active pro tier entitlement. Observed by views for reactive updates.
    @Published private(set) var isProTier: Bool = SharedDataManager.shared.isProTier

    /// True when the user's annual subscription has ended (not lifetime, not never-subscribed).
    /// Drives the "Renew" card.
    @Published private(set) var isLapsedSubscriber: Bool = SharedDataManager.shared.isLapsedSubscriber

    /// Current subscription status (annual with renewal date, lifetime, or none).
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .none

    /// The verified best entitlement from the last check, or nil when free.
    @Published private(set) var currentEntitlement: EntitlementDetail?

    /// Product ID of the plan the user currently holds, or nil when free.
    var currentPlanProductID: String? { currentEntitlement?.productID }

    /// Whether (and how) `productID` can be purchased given the current plan.
    func eligibility(for productID: String) -> PurchaseEligibility {
        let current = currentEntitlement.map {
            EntitlementCandidate(productID: $0.productID, expirationDate: $0.expirationDate)
        }
        return ProEntitlementPolicy.purchaseEligibility(current: current, target: productID)
    }

    // MARK: - Convenience Accessors

    /// The annual subscription product, if loaded.
    var annualProduct: Product? {
        products.first { $0.id == SharedConstants.proAnnualProductID }
    }

    /// The Family annual subscription product (shareable with up to 5 family members), if loaded.
    var familyAnnualProduct: Product? {
        products.first { $0.id == SharedConstants.proFamilyAnnualProductID }
    }

    /// The lifetime (non-consumable) product, if loaded.
    var lifetimeProduct: Product? {
        products.first { $0.id == SharedConstants.proLifetimeProductID }
    }

    // MARK: - Private

    private let logger = Logger(
        subsystem: "com.millermedia.ElectionDeflection",
        category: "StoreKitService"
    )

    let productIDs: Set<String> = ProEntitlementPolicy.proProductIDs

    private let defaults: UserDefaults
    private let productFetcher: ProductFetching
    private let storeSyncer: StoreSyncing
    private let entitlementChecker: EntitlementChecking
    private let purchasePerformer: PurchasePerforming

    private init() {
        self.defaults = .standard
        self.productFetcher = StoreKitProductFetcher()
        self.storeSyncer = AppStoreSyncer()
        self.entitlementChecker = StoreKitEntitlementChecker()
        self.purchasePerformer = StoreKitPurchasePerformer()
    }

    /// Test-only initializer with dependency injection.
    init(
        defaults: UserDefaults,
        productFetcher: ProductFetching,
        storeSyncer: StoreSyncing,
        entitlementChecker: EntitlementChecking,
        purchasePerformer: PurchasePerforming = StoreKitPurchasePerformer()
    ) {
        self.defaults = defaults
        self.productFetcher = productFetcher
        self.storeSyncer = storeSyncer
        self.entitlementChecker = entitlementChecker
        self.purchasePerformer = purchasePerformer
    }

    // MARK: - Product Loading

    /// Loads products from the App Store asynchronously with a timeout.
    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let storeProducts = try await withTimeout(seconds: 15) {
                try await self.productFetcher.products(for: self.productIDs)
            }

            if storeProducts.isEmpty {
                logger.warning("App Store returned zero products for IDs: \(self.productIDs.joined(separator: ", "))")
                products = []
                isLoading = false
                errorMessage = "Products are not yet available. Please try again later."
                return
            }

            products = storeProducts.sorted { $0.price < $1.price }
            isLoading = false

            cacheProductDisplayData(storeProducts)
            logger.info("Loaded \(storeProducts.count) products from App Store: \(storeProducts.map { $0.id }.joined(separator: ", "))")
        } catch let error as StoreKitError {
            logger.error("Failed to load products: \(error.localizedDescription, privacy: .private)")
            isLoading = false
            if case .networkError(_) = error {
                errorMessage = Self.networkErrorMessage
            } else {
                errorMessage = Self.loadErrorMessage
            }
        } catch is TimeoutError {
            logger.error("Product loading timed out")
            isLoading = false
            errorMessage = Self.networkErrorMessage
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription, privacy: .private)")
            isLoading = false
            errorMessage = Self.loadErrorMessage
        }
    }

    // MARK: - Timeout Helper

    private struct TimeoutError: Error {}

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    // MARK: - Purchase

    /// Initiates a purchase for the given product ID. An individual annual subscriber buying
    /// Family goes through `product.purchase()`: StoreKit upgrades within the group immediately
    /// (prorated by Apple), and the entitlement refresh afterwards reports `.familyAnnual`.
    /// Returns a `PurchaseOutcome` the UI can switch on.
    func purchase(productID: String) async -> PurchaseOutcome {
        // Pro known only from the Keychain cache (no verified entitlement yet): verify first so
        // eligibility is decided on the real plan.
        if isProTier && currentEntitlement == nil {
            await checkEntitlements()
        }

        let eligibility = eligibility(for: productID)
        if case .blocked(.unknownProduct) = eligibility {
            logger.error("Purchase attempted for unknown product: \(productID, privacy: .private)")
            return .failed
        }
        guard eligibility.canPurchase else {
            logger.info("Purchase skipped — not eligible (\(String(describing: eligibility), privacy: .public))")
            return .alreadyOwned
        }

        guard let product = products.first(where: { $0.id == productID }) else {
            logger.error("Purchase attempted for unknown product: \(productID, privacy: .private)")
            return .failed
        }

        do {
            let result = try await purchasePerformer.purchase(product)
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await checkEntitlements()
                    ReviewRequestManager.shared.recordPurchase()
                    logger.info("Purchase verified for \(productID, privacy: .private)")
                    return .success
                case .unverified(_, _):
                    return .unverified
                }
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .cancelled
            }
        } catch let error as StoreKitError {
            logger.error("Purchase StoreKit error: \(error.localizedDescription, privacy: .private)")
            if case .networkError(_) = error {
                return .networkError
            }
            return .failed
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription, privacy: .private)")
            return .failed
        }
    }

    // MARK: - Entitlements

    /// Checks current entitlements and updates pro tier status and subscription status.
    /// Call on app launch and after restore to sync purchase state.
    func checkEntitlements() async {
        let detail = await entitlementChecker.entitlementDetail(productIDs: productIDs)
        let isEntitled = detail != nil
        currentEntitlement = detail
        await updateProTierStatus(detail)
        subscriptionStatus = resolveSubscriptionStatus(from: detail)
        logger.info("Entitlement check complete: proTier=\(isEntitled)")
    }

    /// Derives subscription status from entitlement detail.
    private func resolveSubscriptionStatus(from detail: EntitlementDetail?) -> SubscriptionStatus {
        guard let detail else { return .none }
        if let renewalDate = detail.expirationDate {
            return ProEntitlementPolicy.isFamilyProduct(detail.productID)
                ? .familyAnnual(renewalDate: renewalDate)
                : .annual(renewalDate: renewalDate)
        }
        return .lifetime
    }

    /// Listens for transaction updates for the app's lifetime.
    /// Call once from app launch in a detached task.
    nonisolated func listenForTransactionUpdates() {
        Task {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await MainActor.run {
                    Task {
                        await StoreKitService.shared.checkEntitlements()
                    }
                }
                
                // Logger is thread-safe
                let logger = Logger(subsystem: "com.millermedia.ElectionDeflection", category: "StoreKitService")
                logger.info("Transaction update processed: \(transaction.productID, privacy: .private)")
            }
        }
    }

    /// Refreshes the transaction history from the App Store, then checks entitlements.
    /// Returns a `RestoreOutcome` the UI can switch on.
    func restorePurchases() async -> RestoreOutcome {
        do {
            try await storeSyncer.sync()
            await checkEntitlements()
            // Since we are on MainActor, we can safely read isProTier which was updated by checkEntitlements
            let outcome: RestoreOutcome = isProTier ? .restored : .noPurchaseFound
            logger.info("Restore purchases completed: \(outcome == .restored ? "restored" : "noPurchaseFound")")
            return outcome
        } catch {
            logger.error("Restore failed: \(error.localizedDescription, privacy: .private)")
            return .failed
        }
    }

    // MARK: - Pro Tier Status

    /// Persists the full entitlement snapshot (App Group, read by the extension), mirrors the boolean
    /// to the Keychain, and updates published state. After a subscription lapses the snapshot keeps
    /// the product ID with a past expiration so the UI can offer renewal.
    private func updateProTierStatus(_ detail: EntitlementDetail?) async {
        let manager = SharedDataManager.shared
        let snapshot = ProEntitlementPolicy.snapshotAfterCheck(
            entitlement: detail.map { EntitlementCandidate(productID: $0.productID, expirationDate: $0.expirationDate) },
            previous: manager.proEntitlementSnapshot
        )
        let value = snapshot.cachedFlag
        KeychainService.saveProTierStatus(value)
        manager.recordProEntitlement(snapshot)
        isProTier = value
        isLapsedSubscriber = manager.isLapsedSubscriber
        // Entitlement just changed — recompute ML availability now so isMLModelEnabled
        // and filterMethod reflect the new tier immediately. Without this, a fresh Pro
        // purchase leaves the flag at its pre-purchase (false) value until the next
        // launch/foreground, surfacing a spurious "ML unavailable" banner. Covers the
        // purchase, restore, and Transaction.updates paths (all route through here).
        MLModelValidator.validateAndSync()
        if value {
            UpgradeNotificationManager.cancelPendingNotification()
        }
    }

    /// Adopts the stored Pro state on launch, before StoreKit has been queried. The App Group
    /// snapshot (product + expiration) wins over the Keychain boolean, so a stale Keychain `true`
    /// cannot resurrect an expired entitlement, e.g. when StoreKit is unreachable. The Keychain
    /// value only matters for legacy installs that have no snapshot yet.
    func syncProTierFromKeychain() {
        let manager = SharedDataManager.shared
        let snapshot = manager.proEntitlementSnapshot
        let keychainValue = KeychainService.loadProTierStatus()
        let value = ProEntitlementPolicy.launchEntitlement(keychainValue: keychainValue, snapshot: snapshot)
        if snapshot.productID != nil, keychainValue != value {
            KeychainService.saveProTierStatus(value)
        }
        if value != snapshot.cachedFlag {
            manager.isProTier = value
        }
        isProTier = value
        isLapsedSubscriber = manager.isLapsedSubscriber
    }

    // MARK: - Caching

    /// Persists product display data to UserDefaults for offline access.
    private func cacheProductDisplayData(_ products: [Product]) {
        var cache: [String: [String: String]] = [:]
        for product in products {
            cache[product.id] = [
                "displayName": product.displayName,
                "description": product.description,
                "displayPrice": product.displayPrice
            ]
        }
        defaults.set(cache, forKey: Self.cacheKey)
    }

    /// Returns cached display data for a product ID when live Product objects aren't available.
    func cachedDisplayData(for productID: String) -> (displayName: String, description: String, displayPrice: String)? {
        guard let cache = defaults.dictionary(forKey: Self.cacheKey) as? [String: [String: String]],
              let data = cache[productID],
              let displayName = data["displayName"],
              let description = data["description"],
              let displayPrice = data["displayPrice"] else {
            return nil
        }
        return (displayName, description, displayPrice)
    }
}
