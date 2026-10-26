import XCTest
import StoreKit
@testable import ElectionDeflection

// MARK: - Mocks

final class MockProductFetcher: ProductFetching, @unchecked Sendable {
    var shouldThrow = false
    var errorToThrow: Error?
    var productsToReturn: [Product] = []

    func products(for identifiers: Set<String>) async throws -> [Product] {
        if let error = errorToThrow { throw error }
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return productsToReturn
    }
}

final class MockStoreSyncer: StoreSyncing, @unchecked Sendable {
    var shouldThrow = false
    var syncCalled = false
    
    func sync() async throws {
        syncCalled = true
        if shouldThrow { throw NSError(domain: "test", code: 2) }
    }
}

final class MockPurchasePerformer: PurchasePerforming, @unchecked Sendable {
    var errorToThrow: Error?
    var purchaseCalled = false

    func purchase(_ product: Product) async throws -> Product.PurchaseResult {
        purchaseCalled = true
        if let error = errorToThrow { throw error }
        // Default: cannot return a real PurchaseResult without StoreKitTest session
        // Tests that need specific results should use errorToThrow to test error paths
        throw NSError(domain: "MockPurchasePerformer", code: 0, userInfo: [NSLocalizedDescriptionKey: "No mock result configured"])
    }
}

final class MockEntitlementChecker: EntitlementChecking, @unchecked Sendable {
    var isEntitledToReturn = false
    var detailToReturn: EntitlementDetail?
    var checkCalled = false

    func isEntitled(productIDs: Set<String>) async -> Bool {
        checkCalled = true
        return isEntitledToReturn
    }

    func entitlementDetail(productIDs: Set<String>) async -> EntitlementDetail? {
        checkCalled = true
        return detailToReturn
    }
}

@MainActor
final class StoreKitServiceTests: XCTestCase {

    private var testDefaults: UserDefaults!
    private var mockFetcher: MockProductFetcher!
    private var mockSyncer: MockStoreSyncer!
    private var mockChecker: MockEntitlementChecker!
    private var mockPurchaser: MockPurchasePerformer!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "StoreKitServiceTests")!
        testDefaults.removePersistentDomain(forName: "StoreKitServiceTests")

        mockFetcher = MockProductFetcher()
        mockSyncer = MockStoreSyncer()
        mockChecker = MockEntitlementChecker()
        mockPurchaser = MockPurchasePerformer()

        // Reset shared data manager state. checkEntitlements()/updateProTierStatus()
        // always write to the real SharedDataManager.shared (App Group suite) rather
        // than an injected instance, so these have to be reset directly rather than
        // through testDefaults.
        SharedDataManager.shared.isProTier = false
        SharedDataManager.shared.preferKeywordFiltering = SharedConstants.defaultPreferKeywordFiltering
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "StoreKitServiceTests")
        testDefaults = nil
        mockFetcher = nil
        mockSyncer = nil
        mockChecker = nil
        mockPurchaser = nil
        SharedDataManager.shared.isProTier = false
        SharedDataManager.shared.preferKeywordFiltering = SharedConstants.defaultPreferKeywordFiltering
        super.tearDown()
    }

    private func makeService() -> StoreKitService {
        StoreKitService.makeForTesting(
            userDefaults: testDefaults,
            productFetcher: mockFetcher,
            storeSyncer: mockSyncer,
            entitlementChecker: mockChecker,
            purchasePerformer: mockPurchaser
        )
    }

    // MARK: - Product ID Alignment

    func testProductIDsMatchSharedConstants() {
        let service = makeService()
        XCTAssertTrue(service.productIDs.contains(SharedConstants.proAnnualProductID))
        XCTAssertTrue(service.productIDs.contains(SharedConstants.proLifetimeProductID))
    }

    // MARK: - Load Products

    func testLoadProductsEmpty() async {
        let service = makeService()

        // MockProductFetcher returns empty array by default.
        // Empty products should set an error message (products not yet available).

        await service.loadProducts()

        XCTAssertFalse(service.isLoading)
        XCTAssertNotNil(service.errorMessage)
        XCTAssertTrue(service.products.isEmpty)
    }

    func testLoadProductsError() async {
        mockFetcher.shouldThrow = true
        let service = makeService()
        
        await service.loadProducts()
        
        XCTAssertFalse(service.isLoading)
        XCTAssertEqual(service.errorMessage, StoreKitService.loadErrorMessage)
    }

    // MARK: - Restore Purchases (Story 2.6 Logic Tests)

    func testRestorePurchases_Success_Restored() async {
        let service = makeService()

        // Setup: Sync succeeds, entitlement check finds pro tier
        mockSyncer.shouldThrow = false
        mockChecker.detailToReturn = EntitlementDetail(
            productID: SharedConstants.proAnnualProductID,
            expirationDate: Date().addingTimeInterval(365 * 24 * 60 * 60)
        )

        let outcome = await service.restorePurchases()

        XCTAssertTrue(mockSyncer.syncCalled, "AppStore.sync() should be called")
        XCTAssertTrue(mockChecker.checkCalled, "Entitlements should be checked")
        XCTAssertEqual(outcome, .restored)
        XCTAssertTrue(service.isProTier)
        XCTAssertTrue(SharedDataManager.shared.isProTier)
    }

    func testRestorePurchases_Success_NoPurchaseFound() async {
        let service = makeService()

        // Setup: Sync succeeds, entitlement check finds NO pro tier
        mockSyncer.shouldThrow = false
        mockChecker.detailToReturn = nil

        let outcome = await service.restorePurchases()

        XCTAssertTrue(mockSyncer.syncCalled)
        XCTAssertTrue(mockChecker.checkCalled)
        XCTAssertEqual(outcome, .noPurchaseFound)
        XCTAssertFalse(service.isProTier)
        XCTAssertFalse(SharedDataManager.shared.isProTier)
    }

    func testRestorePurchases_Failure_SyncThrows() async {
        let service = makeService()
        
        // Setup: Sync throws error
        mockSyncer.shouldThrow = true
        
        let outcome = await service.restorePurchases()
        
        XCTAssertTrue(mockSyncer.syncCalled)
        // Check entitlements might NOT be called if sync throws, depending on implementation.
        // Current implementation: try await storeSyncer.sync(); await checkEntitlements()
        // So if sync throws, checkEntitlements is skipped.
        XCTAssertFalse(mockChecker.checkCalled)
        
        XCTAssertEqual(outcome, .failed)
    }

    // MARK: - Entitlements Logic

    func testCheckEntitlementsUpdatesState() async {
        let service = makeService()

        mockChecker.detailToReturn = EntitlementDetail(
            productID: SharedConstants.proAnnualProductID,
            expirationDate: Date().addingTimeInterval(365 * 24 * 60 * 60)
        )
        await service.checkEntitlements()

        XCTAssertTrue(service.isProTier)
        XCTAssertTrue(SharedDataManager.shared.isProTier)

        mockChecker.detailToReturn = nil
        await service.checkEntitlements()

        XCTAssertFalse(service.isProTier)
        XCTAssertFalse(SharedDataManager.shared.isProTier)
    }

    // MARK: - Message Constants

    func testRestoreMessageConstants() {
        XCTAssertFalse(StoreKitService.restoreSuccessMessage.isEmpty)
        XCTAssertFalse(StoreKitService.restoreNoPurchaseMessage.isEmpty)
        XCTAssertTrue(StoreKitService.restoreSuccessMessage.contains("restored"))
        XCTAssertTrue(StoreKitService.restoreNoPurchaseMessage.contains("No previous purchase"))
    }
    
    // MARK: - Subscription Status (Story 2.7)

    func testSubscriptionStatusEnumCases() {
        let renewalDate = Date().addingTimeInterval(365 * 24 * 60 * 60)
        let annual = StoreKitService.SubscriptionStatus.annual(renewalDate: renewalDate)
        let lifetime = StoreKitService.SubscriptionStatus.lifetime
        let none = StoreKitService.SubscriptionStatus.none

        XCTAssertNotEqual(annual, lifetime)
        XCTAssertNotEqual(annual, none)
        XCTAssertNotEqual(lifetime, none)
    }

    func testCheckEntitlementsUpdatesSubscriptionStatus_Annual() async {
        let service = makeService()
        let renewalDate = Date().addingTimeInterval(365 * 24 * 60 * 60)
        mockChecker.detailToReturn = EntitlementDetail(
            productID: SharedConstants.proAnnualProductID,
            expirationDate: renewalDate
        )

        await service.checkEntitlements()

        XCTAssertTrue(service.isProTier)
        XCTAssertEqual(service.subscriptionStatus, .annual(renewalDate: renewalDate))
    }

    func testCheckEntitlementsUpdatesSubscriptionStatus_Lifetime() async {
        let service = makeService()
        mockChecker.detailToReturn = EntitlementDetail(
            productID: SharedConstants.proLifetimeProductID,
            expirationDate: nil
        )

        await service.checkEntitlements()

        XCTAssertTrue(service.isProTier)
        XCTAssertEqual(service.subscriptionStatus, .lifetime)
    }

    // MARK: - ML Model Gating on Entitlement Change (issue #4)

    func testLifetimeEntitlementEnablesMLFiltering() async {
        // Pro-only keyword-vs-AI toggle: make sure AI filtering is the one in
        // effect for this assertion, independent of whatever a prior test left
        // in the (real, shared) user preference.
        SharedDataManager.shared.preferKeywordFiltering = false

        let service = makeService()
        mockChecker.detailToReturn = EntitlementDetail(
            productID: SharedConstants.proLifetimeProductID,
            expirationDate: nil
        )

        await service.checkEntitlements()

        XCTAssertTrue(service.isProTier)
        // updateProTierStatus() calls MLModelValidator.validateAndSync() synchronously
        // right after setting isProTier, so a fresh lifetime purchase/restore should
        // already reflect ML availability without waiting for the next launch.
        XCTAssertTrue(SharedDataManager.shared.isMLModelEnabled,
                      "Lifetime entitlement should enable ML filtering (model is bundled in this test host)")
        XCTAssertEqual(SharedDataManager.shared.filterMethod, SharedConstants.filterMethodML,
                       "Lifetime Pro entitlement with AI filtering preferred should select the ML filter method")
    }

    func testCheckEntitlementsUpdatesSubscriptionStatus_None() async {
        let service = makeService()
        mockChecker.detailToReturn = nil

        await service.checkEntitlements()

        XCTAssertFalse(service.isProTier)
        XCTAssertEqual(service.subscriptionStatus, .none)
    }

    func testSubscriptionStatusResetsOnExpiry() async {
        let service = makeService()
        let renewalDate = Date().addingTimeInterval(365 * 24 * 60 * 60)
        mockChecker.detailToReturn = EntitlementDetail(
            productID: SharedConstants.proAnnualProductID,
            expirationDate: renewalDate
        )
        await service.checkEntitlements()
        XCTAssertEqual(service.subscriptionStatus, .annual(renewalDate: renewalDate))

        // Simulate expiry
        mockChecker.detailToReturn = nil
        await service.checkEntitlements()
        XCTAssertEqual(service.subscriptionStatus, .none)
        XCTAssertFalse(service.isProTier)
    }

    // MARK: - Error Handling (Story 2.8)

    func testPurchaseAlreadyOwned() async {
        let service = makeService()
        // Set user as already Pro
        mockChecker.detailToReturn = EntitlementDetail(
            productID: SharedConstants.proLifetimeProductID,
            expirationDate: nil
        )
        await service.checkEntitlements()
        XCTAssertTrue(service.isProTier)

        // Attempt purchase — should return .alreadyOwned without calling App Store
        let outcome = await service.purchase(productID: SharedConstants.proAnnualProductID)
        XCTAssertEqual(outcome, .alreadyOwned)
    }

    func testPurchaseOutcomeAlreadyOwnedCase() {
        let alreadyOwned = StoreKitService.PurchaseOutcome.alreadyOwned
        let networkError = StoreKitService.PurchaseOutcome.networkError
        let failed = StoreKitService.PurchaseOutcome.failed
        let success = StoreKitService.PurchaseOutcome.success

        XCTAssertNotEqual(alreadyOwned, failed)
        XCTAssertNotEqual(alreadyOwned, success)
        XCTAssertNotEqual(alreadyOwned, networkError)
        XCTAssertNotEqual(networkError, failed)
    }

    func testErrorMessageConstants() {
        XCTAssertFalse(StoreKitService.networkErrorMessage.isEmpty)
        XCTAssertFalse(StoreKitService.alreadyOwnedMessage.isEmpty)
        XCTAssertTrue(StoreKitService.networkErrorMessage.contains("internet"))
        XCTAssertTrue(StoreKitService.alreadyOwnedMessage.contains("Pro"))
    }

    func testPurchaseFailsForUnknownProduct() async {
        let service = makeService()
        // No products loaded, so any ID is unknown
        let outcome = await service.purchase(productID: "com.fake.product")
        XCTAssertEqual(outcome, .failed)
        // Verify purchase performer was NOT called (product not found guard fires first)
        XCTAssertFalse(mockPurchaser.purchaseCalled)
    }

    func testLoadProductsNetworkError() async {
        let service = makeService()
        // Configure fetcher to throw a StoreKitError.networkError
        mockFetcher.shouldThrow = false // disable generic throw
        mockFetcher.productsToReturn = [] // won't be used since we override
        // We need the fetcher to throw a StoreKitError — extend the mock
        mockFetcher.errorToThrow = StoreKitError.networkError(URLError(.notConnectedToInternet))

        await service.loadProducts()

        XCTAssertFalse(service.isLoading)
        XCTAssertEqual(service.errorMessage, StoreKitService.networkErrorMessage)
    }

    func testLoadProductsGenericError() async {
        mockFetcher.shouldThrow = true
        let service = makeService()

        await service.loadProducts()

        XCTAssertFalse(service.isLoading)
        XCTAssertEqual(service.errorMessage, StoreKitService.loadErrorMessage)
    }

    func testPendingMessageConstant() {
        XCTAssertFalse(StoreKitService.pendingMessage.isEmpty)
        XCTAssertTrue(StoreKitService.pendingMessage.contains("pending"))
    }

    // MARK: - View Helper Tests

    func testCachedDisplayData() {
        let service = makeService()
        let testCache: [String: [String: String]] = [
            SharedConstants.proAnnualProductID: [
                "displayName": "Annual",
                "description": "Desc",
                "displayPrice": "$10"
            ]
        ]
        testDefaults.set(testCache, forKey: StoreKitService.cacheKey)
        
        let data = service.cachedDisplayData(for: SharedConstants.proAnnualProductID)
        XCTAssertEqual(data?.displayName, "Annual")
        XCTAssertEqual(data?.displayPrice, "$10")
    }
}
