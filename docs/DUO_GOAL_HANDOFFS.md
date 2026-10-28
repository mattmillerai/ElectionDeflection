# Duo handoffs: Claude Code `/goal` prompts

One goal per story. Paste the text inside each block after `/goal `. Run them in order; each one is one branch and one PR against `main`. 11.1 first, then 11.2. After 11.2 merges, 11.3, 11.4, 11.6 and 11.7 can run in any order (11.3 comes after 11.2 because it verifies that layout).

Story files live in `_bmad-output/implementation-artifacts/`. The decisions (D1 to D10) live in `_bmad-output/planning-artifacts/epics.md`, Epic 11.

## Rules that apply to every goal

- Start from an up-to-date `main`. Branch name `feat/duo-<story-id>`. Open a draft PR with `gh pr create --draft`. Never merge, never push to `main`, never force-push.
- Work only inside the story's scope. No string, price, product, paywall, or Pro-logic change (paywall layout is story 11.5, held until after Nov 3).
- No iOS 27.1 only APIs. The deployment target stays iOS 16.0. CI and TestFlight stay on Xcode 26.
- Do not touch App Store Connect, signing, uploads, secrets, or the `ASC_*` variables. Do not decrypt training data. No App Store submission.
- Manifest check: new Swift files must be registered in `ElectionDeflection.xcodeproj/project.pbxproj` for the right targets.
- Verification command: `xcodebuild test -scheme ElectionDeflection -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`. Screenshot checks need a Duo simulator (outer 466x678 pt, inner 669x951 pt) on a Mac with Xcode; where that is not available, say so in the PR instead of claiming the check passed.

## Goal 1: Story 11.1, Duo toolchain readiness baseline

```
Complete BMAD story 11.1 in _bmad-output/implementation-artifacts/11-1-duo-toolchain-readiness-baseline.md. Done means: every acceptance criterion in that file is met or explicitly marked as needing a Mac simulator run; the audit results and layout rules are written into CONTRIBUTING.md as the story specifies; no Swift file or workflow file changed; the story's Tasks checkboxes and Dev Agent Record are filled in; sprint-status.yaml shows 11-1 as review; and a draft PR against main is open on branch feat/duo-11-1. Stop and report if any acceptance criterion would require changing code or CI.
```

## Goal 2: Story 11.2, adaptive home screen on both displays

```
Complete BMAD story 11.2 in _bmad-output/implementation-artifacts/11-2-adaptive-home-screen-both-displays.md. Done means: Views/AdaptiveLayout.swift, the AdaptiveStack and readableWidth() helpers exist and are registered in the project; MainAppView scrolls and uses one adaptive layout (two columns only when regular width and wide enough, single column otherwise, contribute link and privacy footer full width); ElectionDeflectionTests/AdaptiveLayoutTests.swift covers the pure layout function; the xcodebuild test command passes; the compact-width layout is unchanged from today; no strings, colors, or Pro logic changed; the Tasks checkboxes and Dev Agent Record are filled in; sprint-status.yaml shows 11-2 as review; and a draft PR against main is open on branch feat/duo-11-2 with before and after screenshots for the outer and inner displays, or a note that the simulator check still needs a Mac. Do not touch ProUpgradeView.
```

## Goal 3: Story 11.3, state preservation on fold, unfold and rotation

```
Complete BMAD story 11.3 in _bmad-output/implementation-artifacts/11-3-state-preservation-fold-unfold-rotation.md, after story 11.2 is merged. Done means: the source-scan test testSubmissionScreensDoNotPersistTypedText exists and passes; the xcodebuild test command passes; the ScenePhaseLaunchPolicy fix is added only if a fold or rotation is shown to change scenePhase (otherwise record in the story that it was not needed and why); every acceptance criterion is met or marked as needing a Mac simulator run; the Tasks checkboxes and Dev Agent Record are filled in; sprint-status.yaml shows 11-3 as review; and a draft PR against main is open on branch feat/duo-11-3. Typed text must never be written to disk.
```

## Goal 4: Story 11.4, wide canvas for Test the Filter and Settings

```
Complete BMAD story 11.4 in _bmad-output/implementation-artifacts/11-4-wide-canvas-test-the-filter-and-settings.md, after story 11.2 is merged. Done means: Test the Filter uses two columns when wide with all state kept on AuditLogView; Settings uses a capped, centered width through readableWidth() with no NavigationSplitView; the single-column layout is unchanged on compact width; the xcodebuild test command passes; the observed sheet sizes on the inner display are recorded in the story, or marked as needing a Mac simulator run; no strings or filter logic changed; the Tasks checkboxes and Dev Agent Record are filled in; sprint-status.yaml shows 11-4 as review; and a draft PR against main is open on branch feat/duo-11-4.
```

## Goal 5: Story 11.6, share extension on the wide screen

```
Complete BMAD story 11.6 in _bmad-output/implementation-artifacts/11-6-share-extension-wide-screen.md, after story 11.2 is merged. Done means: UIScreen.main is gone from OCRService.createThumbnail, which takes a scale parameter (default 2) that ShareExtensionView fills from displayScale; the share extension has an adaptive side-by-side layout; AdaptiveLayout.swift is registered in the Share extension target and not the Filter extension target; thumbnail-scale unit tests are added and the xcodebuild test command passes; how the host presents the extension on Duo is marked unverified unless it was checked on a simulator; no OCR or classification behavior changed; the Tasks checkboxes and Dev Agent Record are filled in; sprint-status.yaml shows 11-6 as review; and a draft PR against main is open on branch feat/duo-11-6.
```

## Goal 6: Story 11.7, setup instructions fit Duo

```
Complete BMAD story 11.7 in _bmad-output/implementation-artifacts/11-7-setup-instructions-fit-duo.md, after story 11.2 is merged. Done means: the setup steps scroll and go side by side when wide; step titles scale with Dynamic Type; the .edgesIgnoringSafeArea(.all) on the whole OnboardingView is replaced so the Next button stays inside the safe area, with before and after screenshots or a note that the simulator check still needs a Mac; the OS-version step tests now include iOS 27, and a >= 27 branch exists only if the iOS 27.1 Settings path really differs (verify first, per decision D8, and otherwise leave the instruction text unchanged); the xcodebuild test command passes; no other strings changed; the Tasks checkboxes and Dev Agent Record are filled in; sprint-status.yaml shows 11-7 as review; and a draft PR against main is open on branch feat/duo-11-7.
```

## Not ready yet

- 11.5 paywall and welcome layout: after Nov 3, and needs Matt's yes.
- 11.8 split-view scenes and accessibility, 11.9 Duo test plan, 11.10 App Store assets: story files not written yet.
