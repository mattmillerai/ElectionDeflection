import XCTest
import StoreKit
import StoreKitTest
@testable import ElectionDeflection

/// End-to-end purchase-path tests that run against a real StoreKit test session backed by
/// ElectionDeflection.storekit (copied into this test bundle's resources). Unlike
/// StoreKitServiceTests, nothing is mocked: products, purchases, and entitlements all come
/// from StoreKit, so the individual -> Family upgrade and the purchase guards are exercised
/// the way the app uses them.
///
/// If a test session cannot be created or products do not load (e.g. an environment without
/// StoreKitTest support), each test is skipped with a message rather than failed.
@MainActor
final class StoreKitUpgradeSessionTests: XCTestCase {

    private var session: SKTestSession!
    private var service: StoreKitService!
    private var testDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()

        testDefaults = UserDefaults(suiteName: "StoreKitUpgradeSessionTests")!
        testDefaults.removePersistentDomain(forName: "StoreKitUpgradeSessionTests")
        // checkEntitlements() writes to the real SharedDataManager.shared.
        SharedDataManager.shared.isProTier = false

        do {
            session = try SKTestSession(configurationFileNamed: "ElectionDeflection")
        } catch {
            throw XCTSkip("SKTestSession could not be created from ElectionDeflection.storekit: \(error)")
        }
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()

        service = StoreKitService.makeForTesting(
            userDefaults: testDefaults,
            productFetcher: StoreKitProductFetcher(),
            storeSyncer: AppStoreSyncer(),
            entitlementChecker: StoreKitEntitlementChecker(),
            purchasePerformer: StoreKitPurchasePerformer()
        )
        await service.loadProducts()
        guard service.products.count == service.productIDs.count else {
            throw XCTSkip("StoreKit test session did not load all products (got \(service.products.count)): \(service.errorMessage ?? "no error")")
        }
    }

    override func tearDown() async throws {
        session?.clearTransactions()
        session = nil
        service = nil
        testDefaults?.removePersistentDomain(forName: "StoreKitUpgradeSessionTests")
        testDefaults = nil
        SharedDataManager.shared.isProTier = false
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Buys `productID` directly through StoreKit (bypassing the service's guards) to set up
    /// a starting state, then refreshes the service's entitlement.
    private func buyDirectly(_ productID: String) async throws {
        guard let product = service.products.first(where: { $0.id == productID }) else {
            throw XCTSkip("Product \(productID) not loaded")
        }
        let result = try await product.purchase()
        guard case .success(let verification) = result, case .verified(let transaction) = verification else {
            throw XCTSkip("Setup purchase of \(productID) did not complete in the test session: \(result)")
        }
        await transaction.finish()
        await service.checkEntitlements()
    }

    private func transactionCount() async -> Int {
        var count = 0
        for await _ in Transaction.all { count += 1 }
        return count
    }

    // MARK: - (a) Individual annual -> Family upgrade

    func testIndividualAnnualSubscriberCanUpgradeToFamily() async throws {
        try await buyDirectly(SharedConstants.proAnnualProductID)
        guard case .annual = service.subscriptionStatus else {
            return XCTFail("Expected .annual after buying individual annual, got \(service.subscriptionStatus)")
        }
        XCTAssertEqual(service.eligibility(for: SharedConstants.proFamilyAnnualProductID), .upgrade)

        let outcome = await service.purchase(productID: SharedConstants.proFamilyAnnualProductID)
        XCTAssertEqual(outcome, .success)

        XCTAssertTrue(service.isProTier)
        XCTAssertEqual(service.currentPlanProductID, SharedConstants.proFamilyAnnualProductID)
        guard case .familyAnnual = service.subscriptionStatus else {
            return XCTFail("Expected .familyAnnual after upgrade, got \(service.subscriptionStatus)")
        }

        // The raw StoreKit entitlement must also include an active Family subscription.
        var hasActiveFamily = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == SharedConstants.proFamilyAnnualProductID,
               transaction.revocationDate == nil {
                hasActiveFamily = true
            }
        }
        XCTAssertTrue(hasActiveFamily, "No active Family entitlement in Transaction.currentEntitlements")
    }

    // MARK: - (b) Family subscriber cannot buy individual annual

    func testFamilySubscriberIsBlockedFromIndividualAnnual() async throws {
        try await buyDirectly(SharedConstants.proFamilyAnnualProductID)
        guard case .familyAnnual = service.subscriptionStatus else {
            return XCTFail("Expected .familyAnnual, got \(service.subscriptionStatus)")
        }
        let before = await transactionCount()

        let outcome = await service.purchase(productID: SharedConstants.proAnnualProductID)

        XCTAssertEqual(outcome, .alreadyOwned)
        let after = await transactionCount()
        XCTAssertEqual(after, before, "A blocked downgrade must not create a transaction")
        guard case .familyAnnual = service.subscriptionStatus else {
            return XCTFail("Status should remain .familyAnnual, got \(service.subscriptionStatus)")
        }
    }

    // MARK: - (c) Lifetime owner cannot buy subscriptions

    func testLifetimeOwnerIsBlockedFromSubscriptions() async throws {
        try await buyDirectly(SharedConstants.proLifetimeProductID)
        XCTAssertEqual(service.subscriptionStatus, .lifetime)
        let before = await transactionCount()

        let annualOutcome = await service.purchase(productID: SharedConstants.proAnnualProductID)
        let familyOutcome = await service.purchase(productID: SharedConstants.proFamilyAnnualProductID)

        XCTAssertEqual(annualOutcome, .alreadyOwned)
        XCTAssertEqual(familyOutcome, .alreadyOwned)
        let after = await transactionCount()
        XCTAssertEqual(after, before, "Blocked purchases must not create transactions")
        XCTAssertEqual(service.subscriptionStatus, .lifetime)
    }
}
