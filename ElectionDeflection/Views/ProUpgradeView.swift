import SwiftUI
import StoreKit

struct ProUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var storeService = StoreKitService.shared

    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showingPendingMessage = false
    @State private var isRestoring = false
    @State private var showingSuccess = false
    @State private var isRestore = false
    @State private var successAnimating = false

    var body: some View {
        ZStack {
            (storeService.isProTier ? Color.proNavy : Color.brandNavy)
                .edgesIgnoringSafeArea(.all)

            if showingSuccess {
                successScreen
            } else {
            VStack(spacing: 16) {
                    // Close button
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 44, height: 44)
                        }
                        .disabled(isPurchasing || isRestoring)
                        .opacity((isPurchasing || isRestoring) ? 0.3 : 1)
                        .accessibilityLabel("Close")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // Header
                    VStack(spacing: 4) {
                        Image(systemName: "brain.head.profile.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.orange)

                        Text("Upgrade to Pro")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Unlock on-device AI filtering")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .accessibilityElement(children: .combine)

                    // Feature comparison
                    comparisonCard

                    // Pricing cards
                    if storeService.isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding(20)
                    } else if !storeService.products.isEmpty {
                        if let annual = storeService.annualProduct {
                            pricingCard(
                                title: "Annual",
                                subtitle: "Renews yearly",
                                price: annual.displayPrice + "/year",
                                product: annual
                            )
                        }
                        if let lifetime = storeService.lifetimeProduct {
                            pricingCard(
                                title: "Lifetime",
                                subtitle: "One-time purchase",
                                price: lifetime.displayPrice,
                                product: lifetime
                            )
                        }
                    } else {
                        cachedPricingFallback
                    }

                    // Status messages
                    if isPurchasing {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text("Processing purchase...")
                                .foregroundColor(.white)
                        }
                    }

                    if let error = purchaseError {
                        HStack {
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.red)
                            Spacer()
                            Button {
                                withAnimation { purchaseError = nil }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .accessibilityLabel("Dismiss error")
                        }
                        .padding(.horizontal, 20)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Error: \(error)")
                    }

                    if showingPendingMessage {
                        Text(StoreKitService.pendingMessage)
                            .font(.subheadline)
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 20)
                    }

                    // Restore Purchase
                    Button {
                        Task { await restorePurchases() }
                    } label: {
                        if isRestoring {
                            ProgressView().tint(.white)
                        } else {
                            Text("Restore Purchase")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .underline()
                        }
                    }
                    .disabled(isRestoring || isPurchasing)

                    Spacer(minLength: 0)

                    // Subscription terms + legal links
                    VStack(spacing: 6) {
                        if let annual = storeService.annualProduct {
                            Text("ElectionDeflection Pro Annual Subscription: \(annual.displayPrice)/year. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Your Apple ID account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions in your App Store account settings.")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.45))
                                .multilineTextAlignment(.center)
                        }

                        HStack(spacing: 4) {
                            Link(destination: URL(string: "https://electiondeflection.com/privacy-policy")!) {
                                Text("Privacy Policy")
                                    .underline()
                            }
                            Text("&")
                            Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                                Text("Terms of Use (EULA)")
                                    .underline()
                            }
                        }
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.5))

                        Text("Zero data collection — all filtering happens on your device")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
            } // else (not showingSuccess)
        }
    }

    // MARK: - Success Screen

    private var successScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 64))
                .foregroundColor(.brandGold)
                .scaleEffect(successAnimating ? 1.0 : 0.5)
                .opacity(successAnimating ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: successAnimating)

            Text(isRestore ? "Welcome back to Pro!" : "Welcome to Pro!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .opacity(successAnimating ? 1.0 : 0.0)
                .offset(y: successAnimating ? 0 : 10)
                .animation(.easeOut(duration: 0.4).delay(0.2), value: successAnimating)

            VStack(spacing: 8) {
                Text("AI-powered filtering is now active on your device.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))

                Text("Your filter now uses machine learning to catch texts that keywords alone might miss.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .opacity(successAnimating ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.4).delay(0.35), value: successAnimating)

            if !isRestore {
                Text("Tip: Set a Pro app icon in Settings")
                    .font(.caption)
                    .foregroundColor(.brandGold.opacity(0.7))
                    .opacity(successAnimating ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.4).delay(0.5), value: successAnimating)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Got it")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.brandGold, Color.orange]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .opacity(successAnimating ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.4).delay(0.5), value: successAnimating)
            .accessibilityLabel("Got it, dismiss")
        }
        .accessibilityElement(children: .contain)
        .onAppear { successAnimating = true }
    }

    // MARK: - Comparison Card

    private let comparisonColumnWidth: CGFloat = 64

    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Column headers
            HStack {
                Spacer()
                HStack(spacing: 16) {
                    Text("Free")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: comparisonColumnWidth)
                    Text("Pro")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                        .frame(width: comparisonColumnWidth)
                }
            }

            comparisonRow(feature: "Keyword filtering", free: true, pro: true)
            comparisonRow(feature: "AI-powered filtering", free: false, pro: true)
            comparisonTextRow(feature: "Accuracy", freeText: "Basic", proText: "96.7%")
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }

    private func comparisonRow(feature: String, free: Bool, pro: Bool) -> some View {
        HStack {
            Text(feature)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            HStack(spacing: 16) {
                Image(systemName: free ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(free ? .green : .white.opacity(0.3))
                    .frame(width: comparisonColumnWidth)
                Image(systemName: pro ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(pro ? .green : .white.opacity(0.3))
                    .frame(width: comparisonColumnWidth)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(feature): \(free ? "included" : "not included") in Free, \(pro ? "included" : "not included") in Pro")
    }

    private func comparisonTextRow(feature: String, freeText: String, proText: String) -> some View {
        HStack {
            Text(feature)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            HStack(spacing: 16) {
                Text(freeText)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: comparisonColumnWidth)
                Text(proText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .frame(width: comparisonColumnWidth)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(feature): \(freeText) in Free, \(proText) in Pro")
    }

    // MARK: - Pricing Card

    private func pricingCard(title: String, subtitle: String, price: String, product: Product) -> some View {
        Button {
            Task { await purchase(product) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Text(price)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.orange, Color.red]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .padding(.horizontal, 20)
        }
        .disabled(isPurchasing)
        .accessibilityLabel("Purchase \(title) for \(price)")
    }

    // MARK: - Cached Pricing Fallback

    private var cachedPricingFallback: some View {
        Group {
            if let annualCache = storeService.cachedDisplayData(for: SharedConstants.proAnnualProductID),
               let lifetimeCache = storeService.cachedDisplayData(for: SharedConstants.proLifetimeProductID) {
                // Show cached prices but disable purchasing (need live Product objects)
                VStack(spacing: 16) {
                    cachedPriceRow(title: "Annual", price: annualCache.displayPrice + "/year")
                    cachedPriceRow(title: "Lifetime", price: lifetimeCache.displayPrice)

                    Text("Pricing shown from cache. Tap retry to load latest prices.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 20)
                }

                Button {
                    Task { await storeService.loadProducts() }
                } label: {
                    Text("Retry Loading Prices")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .underline()
                }
            } else if let errorMsg = storeService.errorMessage {
                VStack(spacing: 12) {
                    Text(errorMsg)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))

                    Button {
                        Task { await storeService.loadProducts() }
                    } label: {
                        Text("Retry")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Text("Pricing unavailable")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))

                    Button {
                        Task { await storeService.loadProducts() }
                    } label: {
                        Text("Load Prices")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }

    private func cachedPriceRow(title: String, price: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Text(price)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(20)
        .background(Color.white.opacity(0.15))
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }

    // MARK: - Purchase

    private func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        showingPendingMessage = false

        let outcome = await storeService.purchase(productID: product.id)
        switch outcome {
        case .success:
            isRestore = false
            withAnimation { showingSuccess = true }
        case .pending:
            showingPendingMessage = true
        case .cancelled:
            break
        case .unverified:
            purchaseError = StoreKitService.unverifiedMessage
        case .alreadyOwned:
            purchaseError = StoreKitService.alreadyOwnedMessage
        case .networkError:
            purchaseError = StoreKitService.networkErrorMessage
        case .failed:
            purchaseError = StoreKitService.purchaseFailedMessage
        }

        isPurchasing = false
    }

    // MARK: - Restore

    private func restorePurchases() async {
        isRestoring = true
        purchaseError = nil

        let outcome = await storeService.restorePurchases()
        switch outcome {
        case .restored:
            isRestore = true
            withAnimation { showingSuccess = true }
        case .noPurchaseFound:
            purchaseError = StoreKitService.restoreNoPurchaseMessage
        case .failed:
            purchaseError = StoreKitService.restoreFailedMessage
        }

        isRestoring = false
    }
}
