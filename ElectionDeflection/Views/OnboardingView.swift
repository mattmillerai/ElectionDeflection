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
    @State private var currentPage = 0

    private var steps: [OnboardingStep] {
        OnboardingStep.steps(forOSMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
    }

    // Total number of pages: welcome screen (0) + steps
    private var totalPages: Int { steps.count + 1 }

    var body: some View {
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
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
            .background(Color.brandNavy.edgesIgnoringSafeArea(.bottom))

        }
        .edgesIgnoringSafeArea(.all)
    }
}


// Initial Screen with App Icon, Background Color, and Introductory Text
struct InitialIconView: View {
    var body: some View {
        ZStack {
            // Background Color
            Color.brandNavy
                .edgesIgnoringSafeArea(.all) // Ensure the color covers the entire screen
            
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

                    Text("ElectionDeflection filters out political spam texts by using your phone's SMS filtering feature.")
                        .font(.body)
                        .foregroundColor(.white) // Set text color to white
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .lineLimit(nil) // Allow wrapping
                        .minimumScaleFactor(0.75) // Scale down text if necessary

                    Text("Your privacy is important to us. We do not save or transmit any of your data. You can review the full source code below.")
                        .font(.body)
                        .foregroundColor(.white) // Set text color to white
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .lineLimit(nil) // Allow wrapping
                        .minimumScaleFactor(0.65) // Scale down text if necessary

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
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure VStack fills the entire ZStack
        }
    }
}

// Step View for Each Onboarding Step
struct StepView: View {
    let title: String
    let description: String
    let imageName: String?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                Text(title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))  // Custom system font
                    .foregroundColor(.white) // Set text color to white
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)

                // Align description text directly below the title
                Text(description)
                    .font(.body)
                    .foregroundColor(.white) // Set text color to white
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer(minLength: 10) // Spacer to ensure consistent spacing

                if let imageName = imageName {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            maxWidth: geometry.size.width * 1, // 100% of the screen width
                            maxHeight: geometry.size.height * 0.6 // 40% of the screen height
                        )
                        .padding(.top, 10)
                }

                Spacer() // Bottom spacer to push everything upwards consistently
            }
            .padding()
        }
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
