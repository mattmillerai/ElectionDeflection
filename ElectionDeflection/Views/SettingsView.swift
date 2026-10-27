import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var storeService = StoreKitService.shared

    @State private var isFilterEnabled: Bool
    @State private var filterMethod: String
    @State private var preferKeyword: Bool
    @State private var showingSetupInstructions = false
    @State private var showingProUpgrade = false
    @State private var showManageSubscription = false
    @State private var isProIconActive = AppIconManager.isProIconActive
    @State private var isChangingIcon = false
    @State private var iconChangeError = false
    @State private var showingTextSubmission = false
    @State private var showingAuditLog = false

    init() {
        _isFilterEnabled = State(initialValue: SharedDataManager.shared.isFilterEnabled)
        _filterMethod = State(initialValue: SharedDataManager.shared.filterMethod)
        _preferKeyword = State(initialValue: SharedDataManager.shared.preferKeywordFiltering)
    }

    var body: some View {
        ZStack {
            (storeService.isProTier ? Color.proNavy : Color.brandNavy)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close")
                    Spacer()
                    Text("Settings")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    // Balance the close button
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 24) {
                        // Filtering section
                        settingsSection(title: "Filtering") {
                            VStack(spacing: 0) {
                                // Toggle row
                                HStack {
                                    Text("Filter Enabled")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Toggle("", isOn: $isFilterEnabled)
                                        .labelsHidden()
                                        .tint(storeService.isProTier ? .brandGold : .green)
                                        .onChange(of: isFilterEnabled) { newValue in
                                            SharedDataManager.shared.isFilterEnabled = newValue
                                        }
                                }
                                .padding(16)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Filter enabled, \(isFilterEnabled ? "on" : "off")")

                                Divider()
                                    .background(Color.white.opacity(0.15))

                                // Filter method row
                                HStack {
                                    Text("Filter Method")
                                        .foregroundColor(.white)
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Image(systemName: filterMethod == SharedConstants.filterMethodML ? "brain" : "text.magnifyingglass")
                                        Text(filterMethod == SharedConstants.filterMethodML ? "AI" : "Keywords")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.6))
                                }
                                .padding(16)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Filter method: \(filterMethod == SharedConstants.filterMethodML ? "AI" : "Keywords")")

                                // Pro-only: opt into keyword filtering instead of AI
                                if storeService.isProTier {
                                    Divider()
                                        .background(Color.white.opacity(0.15))

                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Use Keyword Filtering")
                                                .foregroundColor(.white)
                                            Text("AI is recommended. Keyword matching is simpler but less accurate. Takes effect shortly after changing.")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.5))
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        Spacer()
                                        Toggle("", isOn: $preferKeyword)
                                            .labelsHidden()
                                            .tint(.brandGold)
                                            .onChange(of: preferKeyword) { newValue in
                                                SharedDataManager.shared.preferKeywordFiltering = newValue
                                                MLModelValidator.validateAndSync()
                                                filterMethod = SharedDataManager.shared.filterMethod
                                            }
                                    }
                                    .padding(16)
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("Use keyword filtering instead of AI, \(preferKeyword ? "on" : "off")")
                                }

                                Divider()
                                    .background(Color.white.opacity(0.15))

                                // Audit row — test the filter and review past checks
                                Button {
                                    showingAuditLog = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "checkmark.shield")
                                            .foregroundColor(.brandGold)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Test the Filter")
                                                .foregroundColor(.white)
                                            Text("See how the filter classifies a message")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    .padding(16)
                                }
                                .accessibilityLabel("Test the Filter. See how the filter classifies a message.")
                            }
                        }

                        // Account section
                        settingsSection(title: "Account") {
                            if storeService.isProTier {
                                VStack(spacing: 0) {
                                    HStack {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.brandGold)
                                        Text(storeService.subscriptionStatus.displayLabel)
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .padding(16)
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("Pro tier active. \(storeService.subscriptionStatus.displayLabel)")

                                    if case .annual = storeService.subscriptionStatus {
                                        Divider()
                                            .background(Color.white.opacity(0.15))

                                        Button {
                                            showManageSubscription = true
                                        } label: {
                                            HStack {
                                                Text("Manage Subscription")
                                                    .foregroundColor(.white)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(.white.opacity(0.4))
                                            }
                                            .padding(16)
                                        }
                                        .accessibilityLabel("Manage subscription")
                                    }

                                    Divider()
                                        .background(Color.white.opacity(0.15))

                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("App Icon")
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        HStack(spacing: 16) {
                                            iconOption(
                                                imageName: "app_icon_no_background",
                                                label: "Default",
                                                isSelected: !isProIconActive
                                            ) {
                                                setAppIcon(pro: false)
                                            }
                                            iconOption(
                                                imageName: "app_icon_no_background_pro",
                                                label: "Pro",
                                                isSelected: isProIconActive
                                            ) {
                                                setAppIcon(pro: true)
                                            }
                                        }

                                    }
                                    .padding(16)
                                    .accessibilityElement(children: .contain)
                                    .accessibilityLabel("App icon selector")
                                }
                            } else {
                                Button {
                                    showingProUpgrade = true
                                } label: {
                                    HStack {
                                        Text("Upgrade to Pro")
                                            .foregroundColor(.white)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    .padding(16)
                                }
                                .accessibilityLabel("Upgrade to Pro")
                            }
                        }

                        // Community section
                        settingsSection(title: "Community") {
                            Button {
                                showingTextSubmission = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "envelope.badge.person.crop")
                                        .foregroundColor(.brandGold)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Help Improve Filtering")
                                            .foregroundColor(.white)
                                        Text("Submit a political text you received")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .padding(16)
                            }
                            .accessibilityLabel("Help improve filtering. Submit a political text you received.")
                        }

                        // Support section
                        settingsSection(title: "Support") {
                            VStack(spacing: 0) {
                                Button {
                                    showingSetupInstructions = true
                                } label: {
                                    HStack {
                                        Text("Setup Instructions")
                                            .foregroundColor(.white)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    .padding(16)
                                }
                                .accessibilityLabel("View setup instructions")

                                Divider()
                                    .background(Color.white.opacity(0.15))

                                Link(destination: URL(string: "https://mattmiller.ai")!) {
                                    HStack {
                                        Text("Developer Website")
                                            .foregroundColor(.white)
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.footnote)
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    .padding(16)
                                }
                                .accessibilityLabel("Open developer website")
                            }
                        }

                        // About section
                        settingsSection(title: "About") {
                            HStack {
                                Text("Version")
                                    .foregroundColor(.white)
                                Spacer()
                                Text(appVersion)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(16)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Version \(appVersion)")
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .fullScreenCover(isPresented: $showingSetupInstructions) {
            OnboardingView()
        }
        .fullScreenCover(isPresented: $showingProUpgrade) {
            ProUpgradeView()
        }
        .sheet(isPresented: $showingTextSubmission) {
            TextSubmissionView()
                .modifier(OpaqueSheetBackground(isProTier: storeService.isProTier))
        }
        .sheet(isPresented: $showingAuditLog) {
            AuditLogView()
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscription)
        .alert("Unable to Change Icon", isPresented: $iconChangeError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The app icon couldn't be changed. Please try again.")
        }
        .onAppear {
            isProIconActive = AppIconManager.isProIconActive
        }
    }

    // MARK: - Helpers

    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 4)

            content()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
        }
        .padding(.horizontal, 20)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private func setAppIcon(pro: Bool) {
        guard !isChangingIcon else { return }
        isChangingIcon = true
        AppIconManager.setIcon(pro: pro) { success in
            isProIconActive = AppIconManager.isProIconActive
            isChangingIcon = false
            if !success {
                iconChangeError = true
            }
        }
    }

    private func iconOption(imageName: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.brandGold : Color.clear, lineWidth: 2)
                    )
                Text(label)
                    .font(.caption)
                    .foregroundColor(isSelected ? .brandGold : .white.opacity(0.5))
            }
        }
        .disabled(isChangingIcon)
        .opacity(isChangingIcon ? 0.5 : 1)
        .accessibilityLabel("\(label) icon\(isSelected ? ", selected" : "")")
    }
}
