import SwiftUI

struct MainAppView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var storeService = StoreKitService.shared
    @State private var showingProUpgrade = false
    @State private var showingSettings = false
    @State private var isMLAvailable = true
    @State private var showingTextSubmission = false

    var body: some View {
        ZStack {
            (storeService.isProTier ? Color.proNavy : Color.brandNavy)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 24) {
                // Settings gear icon
                HStack {
                    Spacer()
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Settings")
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // App icon
                Image(storeService.isProTier ? "app_icon_no_background_pro" : "app_icon_no_background")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .accessibilityLabel("ElectionDeflection app icon")

                // Title
                Text("ElectionDeflection")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .accessibilityAddTraits(.isHeader)

                // Education card
                Text("Political texts are moved to the **Spam** folder in Messages. Open Messages and look for the Spam folder to review them.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(20)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .accessibilityLabel("Political texts are moved to the Spam folder in Messages.")

                // ML degradation notice (only for Pro tier users who paid for AI filtering)
                if storeService.isProTier && !isMLAvailable {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("ML filtering temporarily unavailable — using keyword filtering")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("ML filtering temporarily unavailable. Using keyword filtering.")
                }

                // Pro status or Upgrade card
                if storeService.isProTier {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.brandGold)
                        Text(storeService.subscriptionStatus.displayLabel)
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Pro tier active. \(storeService.subscriptionStatus.displayLabel)")
                } else {
                    Button {
                        showingProUpgrade = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "brain.head.profile.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Upgrade to Pro")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("AI catches texts that keywords miss")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(20)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.orange, Color.red]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)
                    }
                    .padding(.horizontal, 20)
                    .accessibilityLabel("Upgrade to Pro. AI catches texts that keywords miss.")
                }

                Spacer()

                // Contribute link
                Button {
                    showingTextSubmission = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "envelope.badge.person.crop")
                            .font(.footnote)
                        Text("Help Improve Filtering")
                            .font(.footnote)
                    }
                    .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 8)
                .accessibilityLabel("Help improve filtering by contributing a text")

                // Privacy message
                Text("Zero data collection — all filtering happens on your device")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
        .fullScreenCover(isPresented: $showingProUpgrade) {
            ProUpgradeView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingTextSubmission) {
            TextSubmissionView()
                .modifier(OpaqueSheetBackground(isProTier: storeService.isProTier))
        }
        .onAppear {
            refreshData()
            validateMLModel()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                refreshData()
                validateMLModel()
                ReviewRequestManager.shared.recordLaunch()
                evaluateReviewRequest()
            } else if newPhase == .inactive {
                ReviewRequestManager.shared.recordResignActive()
            }
        }
        // Pro status can change mid-session (purchase / restore) without a
        // foreground transition. Recompute ML availability so the degradation
        // banner doesn't linger right after upgrade.
        .onChange(of: storeService.isProTier) { _ in
            validateMLModel()
        }
    }


    private func refreshData() {
        SharedDataManager.shared.seedDefaultFilterDataIfNeeded()
        isMLAvailable = SharedDataManager.shared.isMLModelEnabled
        evaluateUpgradePrompt()
    }

    private func evaluateReviewRequest() {
        // Small delay to let the UI settle before showing system alert
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard !showingProUpgrade, !showingSettings, !showingTextSubmission else { return }
            _ = ReviewRequestManager.shared.requestReviewIfEligible()
        }
    }

    private func evaluateUpgradePrompt() {
        let manager = SharedDataManager.shared
        guard !storeService.isProTier,
              !manager.hasSeenUpgradePrompt,
              let completedDate = manager.onboardingCompletedDate else { return }
        let daysSinceOnboarding = Calendar.current.dateComponents([.day], from: completedDate, to: Date()).day ?? 0
        if daysSinceOnboarding >= SharedConstants.upgradePromptDelayDays {
            manager.hasSeenUpgradePrompt = true
            UpgradeNotificationManager.cancelPendingNotification()
            showingProUpgrade = true
        }
    }

    /// Validates ML model availability off the main thread, then updates UI state.
    /// Uses MLModelValidator.validateAndSync() which gates ML on Pro tier.
    private func validateMLModel() {
        Task {
            await Task.detached(priority: .userInitiated) {
                MLModelValidator.validateAndSync()
            }.value

            isMLAvailable = SharedDataManager.shared.isMLModelEnabled
        }
    }
}
