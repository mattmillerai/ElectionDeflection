import SwiftUI

struct OnboardingStep {
    let title: String
    let description: String
    let imageName: String?

    /// Builds the onboarding steps for a given iOS major version. Mirrors the
    /// #available(iOS 26) / #available(iOS 18) / older branching used at runtime,
    /// extracted so it can be exercised directly in tests.
    static func steps(forOSMajorVersion major: Int) -> [OnboardingStep] {
        var result: [OnboardingStep] = []

        // Step 1: Open Settings (all versions)
        result.append(OnboardingStep(
            title: "Step 1: Open Settings",
            description: "Open the Settings app on your iPhone. You can do this by tapping the Settings icon on your home screen.",
            imageName: "settings_icon_pdf"
        ))

        if major >= 26 {
            // iOS 26+ path: Settings > Apps > Messages > Text Message Filter > ElectionDeflection
            result.append(OnboardingStep(
                title: "Step 2: Go to Apps",
                description: "Scroll down and tap on 'Apps'.",
                imageName: "ios26_settings_apps"
            ))
            result.append(OnboardingStep(
                title: "Step 3: Go to Messages",
                description: "Scroll down and tap on 'Messages'.",
                imageName: "ios26_apps_messages"
            ))
            result.append(OnboardingStep(
                title: "Step 4: Turn On Screen Unknown Senders",
                description: "Under 'Unknown Senders', turn on 'Screen Unknown Senders' if it isn't already on (it's off by default). You may not be able to pick a text filter until it's on. Then tap on 'Text Message Filter'.",
                imageName: "ios26_messages_settings"
            ))
            result.append(OnboardingStep(
                title: "Step 5: Enable SMS Filtering",
                description: "Select 'ElectionDeflection' under Text Message Filter. If prompted, tap 'Use' to confirm.",
                imageName: "ios26_text_message_filter"
            ))
            result.append(OnboardingStep(
                title: "How It Works",
                description: "Once enabled, ElectionDeflection will filter political messages into the Spam folder. You can find filtered messages by tapping the filter menu in Messages. Don't worry, any political messages from your contacts won't be filtered.",
                imageName: "ios26_filter_menu"
            ))
        } else if major >= 18 {
            // iOS 18 path: Settings > Apps > Messages > Unknown & Spam > ElectionDeflection
            result.append(OnboardingStep(
                title: "Step 2: Go to Apps",
                description: "Scroll down and tap on 'Apps'.",
                imageName: "ios18_settings"
            ))
            result.append(OnboardingStep(
                title: "Step 3: Go to Messages",
                description: "Scroll down and tap on 'Messages'.",
                imageName: "ios18_apps"
            ))
            result.append(OnboardingStep(
                title: "Step 4: Turn On Filter Unknown Senders",
                description: "Tap on 'Unknown & Spam' in the Messages settings, then turn on 'Filter Unknown Senders' if it isn't already on. You may not be able to pick a text filter until it's on.",
                imageName: "unknown_spam_screenshot"
            ))
            result.append(OnboardingStep(
                title: "Step 5: Enable SMS Filtering",
                description: "Select 'ElectionDeflection' under SMS Filtering. If prompted, tap 'Enable' to confirm.",
                imageName: "sms_filtering_screenshot"
            ))
            result.append(OnboardingStep(
                title: "How It Works",
                description: "Once enabled, ElectionDeflection will filter political messages into the Spam folder. Don't worry, any political messages from your contacts won't be filtered.",
                imageName: "junk_folder_screenshot"
            ))
        } else {
            // iOS < 18 path: Settings > Messages > Unknown & Spam > ElectionDeflection
            result.append(OnboardingStep(
                title: "Step 2: Go to Messages Settings",
                description: "Scroll down and tap on 'Messages'.",
                imageName: "messages_screenshot"
            ))
            result.append(OnboardingStep(
                title: "Step 3: Turn On Filter Unknown Senders",
                description: "Tap on 'Unknown & Spam' in the Messages settings, then turn on 'Filter Unknown Senders' if it isn't already on. You may not be able to pick a text filter until it's on.",
                imageName: "unknown_spam_screenshot"
            ))
            result.append(OnboardingStep(
                title: "Step 4: Enable SMS Filtering",
                description: "Select 'ElectionDeflection' under SMS Filtering. If prompted, tap 'Enable' to confirm.",
                imageName: "sms_filtering_screenshot"
            ))
            result.append(OnboardingStep(
                title: "How It Works",
                description: "Once enabled, ElectionDeflection will filter political messages into the Spam folder. Don't worry, any political messages from your contacts won't be filtered.",
                imageName: "junk_folder_screenshot"
            ))
        }

        // Final screen (all versions)
        result.append(OnboardingStep(
            title: "Almost Done!",
            description: "Just one more step! Make sure to leave this app, go to the Settings app and enable ElectionDeflection to start filtering unwanted political messages. If any political texts slip through, please screenshot them and send them to me on IG (@mattmiller.ai) or X (@mattmiller_ai). If you need to revisit any instructions, you can swipe back through the steps.",
            imageName: nil
        ))

        return result
    }
}

struct OnboardingView: View {
    var onComplete: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var currentPage = 0

    private var steps: [OnboardingStep] {
        OnboardingStep.steps(forOSMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
    }

    // Total number of pages: welcome screen (0) + steps
    private var totalPages: Int { steps.count + 1 }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    // Initial Screen - App Icon with Background Color and Introductory Text
                    InitialIconView()
                        .tag(0)

                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        StepView(
                            title: step.title,
                            description: step.description,
                            imageName: step.imageName
                        )
                        .tag(index + 1)
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .background(Color.brandNavy.edgesIgnoringSafeArea(.all))

                // Navigation Button
                VStack(spacing: 12) {
                    let isLastPage = currentPage >= totalPages - 1

                    Button(action: {
                        if isLastPage {
                            SharedDataManager.shared.hasCompletedOnboarding = true
                            SharedDataManager.shared.hasSeenV2Welcome = true
                            if SharedDataManager.shared.onboardingCompletedDate == nil {
                                SharedDataManager.shared.onboardingCompletedDate = Date()
                                UpgradeNotificationManager.scheduleUpgradeNotification()
                            }
                            if let onComplete = onComplete {
                                onComplete()
                            } else {
                                dismiss()
                            }
                        } else {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                    }) {
                        Text(isLastPage ? (onComplete != nil ? "Get Started" : "Done") : "Next")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(gradient: Gradient(colors: [Color.orange, Color.red]),
                                               startPoint: .leading,
                                               endPoint: .trailing)
                            )
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)
                    }
                    .animation(.easeInOut(duration: 0.2), value: isLastPage)

                    Button(action: {
                        withAnimation {
                            currentPage = 1
                        }
                    }) {
                        Text("Back to Step 1")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .opacity(isLastPage ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isLastPage)
                    .allowsHitTesting(isLastPage)
                }
                .readableWidth()
                .padding(.horizontal, 20)
                // Tighter in compact height (landscape) so the page keeps more room;
                // always above the home indicator
                .padding(.top, verticalSizeClass == .compact ? 12 : 20)
                .padding(.bottom, max(verticalSizeClass == .compact ? 16 : 40, proxy.safeAreaInsets.bottom))
                .background(Color.brandNavy.edgesIgnoringSafeArea(.all))

            }
            // Pages and buttons respect the side safe areas (landscape); only the
            // navy backgrounds extend under them
            .edgesIgnoringSafeArea(.vertical)
        }
    }
}


// Initial Screen with App Icon, Background Color, and Introductory Text
struct InitialIconView: View {
    var body: some View {
        ZStack {
            // Background Color
            Color.brandNavy
                .edgesIgnoringSafeArea(.all) // Ensure the color covers the entire screen
            
            PageScrollView { _ in
                VStack(spacing: 20) {
                
                    // Icon in the Center
                    Image("app_icon_no_background")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .padding(.top, 40)

                    // Introductory Text
                    VStack(spacing: 20) {
                        Text("Welcome to ElectionDeflection")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white) // Set text color to white
                            .multilineTextAlignment(.center)
                            .padding(.top, 0)
                            .minimumScaleFactor(0.5)
                            .fixedSize(horizontal: false, vertical: true) // Wrap, never truncate; the page scrolls instead

                        Text("ElectionDeflection filters out political spam texts by using your phone's SMS filtering feature.")
                            .font(.body)
                            .foregroundColor(.white) // Set text color to white
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .lineLimit(nil) // Allow wrapping
                            .minimumScaleFactor(0.75) // Scale down text if necessary
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Your privacy is important to us. We do not save or transmit any of your data. You can review the full source code below.")
                            .font(.body)
                            .foregroundColor(.white) // Set text color to white
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .lineLimit(nil) // Allow wrapping
                            .minimumScaleFactor(0.65) // Scale down text if necessary
                            .fixedSize(horizontal: false, vertical: true)

                        if let url = URL(string: "https://github.com/MillerMedia/ElectionDeflection") {
                            Link(destination: url) {
                                HStack {
                                    Image(systemName: "chevron.left.slash.chevron.right") // SF Symbol for "code" or custom GitHub logo
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.white)
                                    Text("View Source Code")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .background(Color.black)
                                .cornerRadius(8)
                            }
                            .padding(.top, 20)
                        }
                    }
                    .padding()
                    .readableWidth()
                
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// Step View for Each Onboarding Step
struct StepView: View {
    let title: String
    let description: String
    let imageName: String?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ViewBuilder private var titleAndDescription: some View {
        Text(title)
            .font(.system(.largeTitle, design: .rounded).weight(.bold))  // 34 pt at the default size; scales with Dynamic Type
            .foregroundColor(.white) // Set text color to white
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true) // Wrap, never truncate; the page scrolls instead
            .padding(.top, 20)

        // Align description text directly below the title
        Text(description)
            .font(.body)
            .foregroundColor(.white) // Set text color to white
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal)
    }

    var body: some View {
        PageScrollView { page in
            let mode = AdaptiveLayout.mode(horizontalSizeClass: horizontalSizeClass, availableWidth: page.width)
            let columnMaxWidth = AdaptiveLayout.columnMaxWidth(for: mode)

            // Text and image side by side in two-column mode, stacked otherwise
            // Identity-preserving: do not turn into if/else around stateful views.
            // (The mode branches inside hold only stateless Text, Spacer and Image.)
            AdaptiveStack(mode: mode, spacing: 20, alignment: .center) {
                if mode == .twoColumn {
                    VStack(spacing: 20) {
                        titleAndDescription
                    }
                    .frame(maxWidth: columnMaxWidth)
                } else {
                    // Direct children of the stack, exactly as before Story 11.7
                    titleAndDescription
                }

                if mode == .singleColumn {
                    Spacer(minLength: 10) // Spacer to ensure consistent spacing
                }

                if let imageName = imageName {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            maxWidth: min(page.width, columnMaxWidth),
                            minHeight: min(160, page.height * 0.6), // On short pages scroll rather than shrink the image away
                            maxHeight: page.height * (mode == .twoColumn ? 0.7 : 0.6)
                        )
                        .padding(.top, 10)
                }

                if mode == .singleColumn {
                    Spacer() // Bottom spacer to push everything upwards consistently
                }
            }
            .padding()
            .frame(maxWidth: mode == .twoColumn ? .infinity : nil) // Center the columns side by side
        }
    }
}

/// A page of the setup pager: its content fills the page (spacers and images
/// size as they would without scrolling) and scrolls when it is taller, for
/// example on short windows or at large Dynamic Type sizes. A scrolling page
/// ends above the page dots so content never sits under them at rest.
private struct PageScrollView<Content: View>: View {
    @ViewBuilder let content: (CGSize) -> Content
    @State private var overflows = false

    /// The page dots sit about 27 pt above the bottom of the pager.
    private let pageDotsClearance: CGFloat = 44

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                content(geometry.size)
                    .fillPageHeight(geometry.size.height)
                    .background(GeometryReader { content in
                        Color.clear.preference(key: PageContentHeightKey.self, value: content.size.height)
                    })
            }
            .onPreferenceChange(PageContentHeightKey.self) { height in
                overflows = height > geometry.size.height + 0.5
            }
        }
        .padding(.bottom, overflows ? pageDotsClearance : 0)
    }
}

private struct PageContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Lays out its content as if it were exactly `minHeight` tall, so spacers and
/// flexible images size the same as outside a `ScrollView`, but grows taller
/// when the content needs more room so it can scroll. Content shorter than the
/// page (side-by-side columns) is centered vertically, clear of a top status bar.
private struct FillPageHeightLayout: Layout {
    let minHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let size = content.sizeThatFits(ProposedViewSize(width: proposal.width, height: minHeight))
        return CGSize(width: proposal.width ?? size.width, height: max(minHeight, size.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(width: bounds.width, height: minHeight))
    }
}

private extension View {
    func fillPageHeight(_ height: CGFloat) -> some View {
        FillPageHeightLayout(minHeight: height) { self }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .previewDisplayName("Review Mode (Done)")
        OnboardingView(onComplete: {})
            .previewDisplayName("Initial Onboarding (Get Started)")
    }
}
