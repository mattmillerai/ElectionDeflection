# Sign-off pass: Duo stories 11.2, 11.3, 11.7 and review prompt 10.1/10.2

A ready-to-run checklist for Matt's Mac (laptop-a45c06) to sign off the stories that are waiting for review. It covers simulator checks that are still open plus a short confirmation re-run of what the Dev Agent Records already report. Nothing here changes app code, signing, App Store Connect, CI, or secrets.

| Story | What it shipped | Where | Story file status | `sprint-status.yaml` |
|---|---|---|---|---|
| 11.2 Adaptive home screen | `AdaptiveLayout.swift`, `MainAppView` scroll + 1/2 columns, `AdaptiveLayoutTests` | PR #17 | review | done |
| 11.3 State through fold/unfold/rotation | comments + `testSubmissionScreensDoNotPersistTypedText` | PR #21 | review | done |
| 11.7 Setup instructions fit Duo | `OnboardingView` layout, iOS 27 step test | PR #19 | review | done |
| 10.1 Review request timing | `ReviewRequestManager`, `MainAppView` hooks, `StoreKitService.recordPurchase()` | commit `0016e1d` (2026-03-08, no PR) | in-progress | review |
| 10.2 Review request tests | `ReviewRequestManagerTests` (15 test functions; the story says 14) | commit `0016e1d` | review | review |

> **Status mismatch to fix after sign-off:** the three Duo story files still say `Status: review` while `sprint-status.yaml` already says `done`; 10.1's file says `in-progress`. After this pass, set both to whatever Matt signs off (that's a docs-only change).

**Estimated time:** about 90 minutes for the simulator pass (10 min setup and build, 15 min 11.2, 20 min 11.3, 15 min 11.7, 25 min 10.1/10.2). The optional on-phone section adds 15 to 20 minutes.

**Already verified by the Dev Agent Records (re-run only as a quick confirmation):** 11.2 rows 1-5 in Free plus Pro on outer portrait and inner landscape; 11.3 every screen through 9 fold/rotate steps and "a fold does not change `scenePhase`"; 11.7 every page on rows 1-5, both entry points, AX5 on rows 1 and 3, Light and Dark. Matt drove Device Hub for parts of 11.2 and 11.7; the 11.3 matrix was run by the agent alone.

**Still open (the real work of this pass):**

| Story | Open item | Source |
|---|---|---|
| 11.2 | Light/Dark appearance on the home screen; VoiceOver reading order (AC 5); iOS 16 no-regression pass | 11.2 Completion Notes, "Not run" |
| 11.2 | Largest accessibility text on rows 1 and 3 of the Duo (only done on iPhone 17 Pro) | 11.2 Dev Notes matrix |
| 11.3 | AX5 text and Light appearance not re-run for this story; Split View resize not available on Duo simulator | 11.3 Known gaps (3), (4) |
| 11.3 | Matt has not personally watched the state matrix (it was run by the agent with synthetic input) | 11.3 Debug Log |
| 11.7 | iOS 16 pass; Settings path steps 3-5 (no Messages app in the simulator) | 11.7 Known gaps |
| 11.1 | Baseline rows 2-4 and the iOS 26-SDK letterbox look were never captured (informational now that 11.2/11.7 are in) | 11.1 Task 4 |
| 10.1/10.2 | 10.2 AC: "Simulator testing validates timing logic" and "manual testing on a real device confirms the system alert" — neither is recorded anywhere | 10.2 story file |

---

## 1. Prerequisites on the Mac

### Xcode and the iPhone Duo simulator

- Required: **Xcode 27.1** with the **iOS 27.1 simulator runtime**; the iPhone Duo device type ships with it. Story 11.1 recorded on 2026-10-27 that the Mac had Xcode 27.1 (27A9275) as its only Xcode, runtimes iOS 26.2 and iOS 27.1, and device type `com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`.
- Fold, half-open, open and rotate controls are in Xcode 27.1's **Device Hub** (per Apple's "Prepare your app for iPhone Duo" page and the 11.2/11.3/11.7 records). `simctl` cannot fold or unfold the device (11.1, 11.2 records); powering a display with `simctl io … screenConfig … power` does **not** fold it and crashed SpringBoard once (11.2 record). Don't use it.

Check what is installed:

```bash
xcodebuild -version                                   # expect Xcode 27.1
xcrun simctl list runtimes                            # expect an iOS 27.1 line (and iOS 26.x)
xcrun simctl list devicetypes | grep -i duo           # expect iPhone Duo
xcrun simctl list devices available | grep -i duo     # an existing iPhone Duo device + its UDID
xcrun simctl list devices available | grep "iPhone 17 Pro"
```

If something is missing:

- **Xcode 27.1:** install from the Mac App Store or developer.apple.com/download/applications, then `sudo xcode-select -s /Applications/Xcode.app` if it isn't the selected one (`xcode-select -p` shows the current one).
- **iOS 27.1 runtime:** Xcode > Settings > Components (verify the pane name in Xcode 27.1), or from Terminal `xcodebuild -downloadPlatform iOS`.
- **No iPhone Duo device but the device type exists:** create one, using the runtime identifier printed by `xcrun simctl list runtimes`:

  ```bash
  xcrun simctl create "iPhone Duo" com.apple.CoreSimulator.SimDeviceType.iPhone-Duo <iOS-27.1-runtime-identifier>
  ```

- **iOS 16 runtime (optional, for the "no regression on iOS 16" checks):** check whether Xcode 27.1 offers an iOS 16.x simulator runtime under Components. If it doesn't, record "iOS 16 pass not possible on this Xcode; CI builds at the iOS 16 deployment target" in the sign-off table. Don't install a second Xcode just for this.

### Clean working copy (don't touch the local changes)

`~/Documents/GitHub/ElectionDeflection-dev` has uncommitted changes in `README.md`, `docs/workers/site-worker.js` and `scripts/sync-to-public.sh`. **Never stash, reset, checkout over or discard them.** Use a separate worktree from `origin/main`:

```bash
cd ~/Documents/GitHub/ElectionDeflection-dev && git fetch origin && git worktree add ../ElectionDeflection-dev-signoff origin/main
cd ../ElectionDeflection-dev-signoff
cp ElectionDeflection/Secrets.plist.example ElectionDeflection/Secrets.plist   # placeholder only, same as CI does
```

`Secrets.plist` is gitignored but is a build input; the example file contains no real key (CI does exactly this copy). Don't copy the real `Secrets.plist` in. With the placeholder, don't submit text from Text Submission (nothing in this pass needs a submit).

When finished: `cd ~/Documents/GitHub/ElectionDeflection-dev && git worktree remove ../ElectionDeflection-dev-signoff` (add `--force` only if it complains about the untracked placeholder `Secrets.plist`; that file is the only thing it would delete).

Screenshots go **outside the repo** so they can't be committed:

```bash
export OUT=~/Desktop/ED-signoff && mkdir -p "$OUT"/{11-2,11-3,11-7,10-x}
```

---

## 2. Commands

Set the device IDs once (copy the UUIDs from `xcrun simctl list devices available`):

```bash
export BUNDLE=com.millermedia.ElectionDeflection
export PRO17=<iPhone 17 Pro UDID>
export DUO=<iPhone Duo UDID>
```

### Unit tests (no signing needed for the simulator)

```bash
# iPhone 17 Pro (compact-width baseline; this is the CONTRIBUTING.md command plus -project/-configuration)
xcodebuild test -project ElectionDeflection.xcodeproj -scheme ElectionDeflection -configuration Debug \
  -destination "platform=iOS Simulator,id=$PRO17" -quiet

# iPhone Duo, iOS 27.1
xcodebuild test -project ElectionDeflection.xcodeproj -scheme ElectionDeflection -configuration Debug \
  -destination "platform=iOS Simulator,id=$DUO" -quiet
```

Expected: exit 0 and the full suite passing (255 tests at Story 11.3; a later count is fine if every test passes). The ones this pass cares about: `AdaptiveLayoutTests` (11.2), `SharedDataManagerTests/testSubmissionScreensDoNotPersistTypedText` (11.3), `SharedDataManagerTests/testIOS27StepsResolveToIOS26Path` and `testStepTitlesAreNumberedConsecutivelyForEachOSVersion` (11.7), all of `ReviewRequestManagerTests` (10.2). To run just those:

```bash
xcodebuild test -project ElectionDeflection.xcodeproj -scheme ElectionDeflection -configuration Debug \
  -destination "platform=iOS Simulator,id=$DUO" \
  -only-testing:ElectionDeflectionTests/AdaptiveLayoutTests \
  -only-testing:ElectionDeflectionTests/ReviewRequestManagerTests \
  -only-testing:ElectionDeflectionTests/SharedDataManagerTests/testSubmissionScreensDoNotPersistTypedText \
  -only-testing:ElectionDeflectionTests/SharedDataManagerTests/testIOS27StepsResolveToIOS26Path \
  -only-testing:ElectionDeflectionTests/SharedDataManagerTests/testStepTitlesAreNumberedConsecutivelyForEachOSVersion
```

If `xcodebuild` asks for a development team or provisioning profile for a **simulator** build, stop and note it; don't change signing settings.

### Build, install, launch

```bash
xcodebuild build -project ElectionDeflection.xcodeproj -scheme ElectionDeflection -configuration Debug \
  -destination "platform=iOS Simulator,id=$DUO" -derivedDataPath build/signoff -quiet
APP=build/signoff/Build/Products/Debug-iphonesimulator/ElectionDeflection.app

xcrun simctl boot "$DUO" 2>/dev/null; open -a Simulator
xcrun simctl install "$DUO" "$APP"
xcrun simctl launch "$DUO" "$BUNDLE"
xcrun simctl terminate "$DUO" "$BUNDLE"      # when you need a cold launch
xcrun simctl uninstall "$DUO" "$BUNDLE"      # fresh install (first-run onboarding)
```

(`build/` is inside the worktree; it is removed with the worktree. Repeat with `$PRO17` for the iPhone 17 Pro.)

**Pro state** needs the scheme's local StoreKit configuration (`ElectionDeflection/ElectionDeflection.storekit`), which only applies when the app is **run from Xcode** (Product > Run with the Duo as the destination). A purchase there is a local test transaction, not a real account and no money. Don't tap Restore and don't use a real Apple ID. To go back to Free, delete the test transaction in Xcode's StoreKit transaction manager (Debug > StoreKit > Manage Transactions; verify the menu path in Xcode 27.1) and relaunch.

### Screenshots

```bash
xcrun simctl status_bar "$DUO" override --time 9:41         # optional, steady status bar
xcrun simctl io "$DUO" screenshot "$OUT/11-2/row1-outer-portrait-free.png"
```

The Duo has two displays. The Dev Agent Records captured a specific display with:

```bash
xcrun simctl io "$DUO" enumerate                                  # lists displays and their UUIDs
xcrun simctl io "$DUO" screenshot --display=<display UUID> "$OUT/…png"
```

Display UUIDs change after a simulator reboot; re-run `enumerate`. If `--display` isn't accepted on this Xcode, take the screenshot with the Simulator window (File > Save Screen, or ⌘S) and note it.

Light/Dark and text size:

```bash
xcrun simctl ui "$DUO" appearance light        # or dark
xcrun simctl ui "$DUO" content_size accessibility-extra-extra-extra-large   # AX5
xcrun simctl ui "$DUO" content_size large      # back to default
```

### Fold, unfold, rotate

- **Fold / half-open / open:** Device Hub's pose buttons (closed = outer display, half-open or open = inner display). Verify the exact controls in Device Hub; there is no `simctl` command for this.
- **Rotate:** Device Hub's rotate button turns one quarter per click (11.3 record). Simulator.app's Device > Rotate Left / Rotate Right (⌘← / ⌘→) is the normal Simulator rotation; verify in the Simulator menu whether it also applies to the Duo.
- Rows used below (from CONTRIBUTING.md):

| Row | Display / orientation | Points | Size class (h × v) |
|---|---|---|---|
| 1 | Outer, portrait | 466×678 | compact × regular |
| 2 | Outer, landscape | 678×466 | compact × compact |
| 3 | Inner, portrait | 669×951 | regular × regular |
| 4 | Inner, landscape | 951×669 | regular × regular |
| 5 | Fold / unfold mid-task | — | switches 1-2 ⇄ 3-4 |

Note from 11.3: on the outer display one of the four orientations is portrait-upside-down, which iPhone apps don't support, so the app stays landscape there. That's expected.

### Skipping onboarding (simulator only)

Either tap through onboarding once, or (as the 11.2 record did) write the App Group flags with the app terminated:

```bash
GROUP=$(xcrun simctl get_app_container "$DUO" "$BUNDLE" group.com.millermedia.electiondeflection)
xcrun simctl spawn "$DUO" defaults write "$GROUP/Library/Preferences/group.com.millermedia.electiondeflection" hasCompletedOnboarding -bool YES
```

If `get_app_container` doesn't accept the group identifier, tap through onboarding instead.

---

## 3. Per-story checklists

File names: `rowN-<display>-<orientation>-<screen>.png`, e.g. `row3-inner-portrait-home-free.png`. Save under `$OUT/<story>/`.

### 11.2 Adaptive home screen (PR #17)

Build installed on both the iPhone 17 Pro and the Duo; onboarding completed; Free state unless noted.

| # | AC | Steps | Expected | Screenshot |
|---|---|---|---|---|
| 2.1 | AC 1 | iPhone 17 Pro, portrait, home | Same as before Duo work: gear, icon, title, education card, Upgrade button, contribute link, privacy footer at the bottom | `$OUT/11-2/pro17-portrait-home-free.png` |
| 2.2 | AC 1, AC 2 | Duo row 1 (outer portrait) | One column, same order; privacy footer wraps onto 2 lines (approved change, 2026-10-27) instead of truncating | `row1-outer-portrait-home-free.png` |
| 2.3 | AC 2 | Duo row 2 (outer landscape) | One column (compact class even at 678 pt); gear inside the safe area; scrolls down to contribute link and footer; nothing clipped | `row2-outer-landscape-home-free.png` (+ one scrolled to the bottom) |
| 2.4 | AC 3 | Duo row 3 (inner portrait) | Two columns: icon + title + education card │ Upgrade card, vertically centered; footer full width; nothing truncated | `row3-inner-portrait-home-free.png` |
| 2.5 | AC 3 | Duo row 4 (inner landscape) | Two columns, each capped at about 640 pt; footer full width | `row4-inner-landscape-home-free.png` |
| 2.6 | AC 4 | Row 5: with the app open, fold and unfold twice | Layout switches live between 1 and 2 columns; no relaunch, no return to onboarding, gear reachable after each switch | `row5-…` (optional) |
| 2.7 | AC 1, 3 | Pro: Run from Xcode, buy the annual plan in the local StoreKit sheet, then rows 1 and 4 | Pro navy background, Pro icon, "Pro — Annual" card; one column on row 1, two on row 4; strings unchanged | `row1-…-home-pro.png`, `row4-…-home-pro.png` |
| 2.8 | AC 2 (**open**) | AX5 text size on rows 1 and 3 | Everything wraps, content scrolls, nothing overlaps, gear stays inside the safe area | `row1-…-home-ax5.png`, `row3-…-home-ax5.png` |
| 2.9 | Dev Notes (**open**) | Light and Dark on rows 1 and 3 | Same layout in both (the home screen uses fixed brand colors, so expect identical images) | `row1-…-home-light.png` etc. |
| 2.10 | AC 5 (**open**) | VoiceOver order: Xcode > Open Developer Tool > Accessibility Inspector, target the Duo simulator, step through elements on row 3 | Order: header (Settings) → left column (icon, title, education card) → right column (Upgrade / Pro card) → contribute link → footer. Labels "Settings" and "Upgrade to Pro. AI catches texts that keywords miss." unchanged | note in the table |
| 2.11 | AC 1 (**open, optional**) | iOS 16 simulator home, portrait | Unchanged from today | `ios16-portrait-home.png` or "runtime not available" |

### 11.3 State through fold, unfold and rotation (PR #21)

For each screen: enter the state, then run the same cycle as the record: start inner landscape → fold (row 1) → rotate (row 2) → unfold (row 3) → rotate (row 4) → fold → half-open → open. Take a screenshot after the last step.

| # | AC | Screen and state | Expected after every step | Screenshot |
|---|---|---|---|---|
| 3.1 | AC 1 | Settings sheet: toggle "Use Keyword Filtering" on, scroll a little | Sheet stays open, toggle stays on, roughly the same scroll position. Turn it back off afterwards | `settings-after-cycle.png` |
| 3.2 | AC 1, 2 | Test the Filter (from Settings): type a political sample (e.g. "Donate now to elect our candidate for Senate before the deadline"), tap Test message | Typed text, result card and Recent Tests row kept; scroll may shift a few dozen points on the first unfold but never resets to the top | `test-the-filter-after-cycle.png` |
| 3.3 | AC 1, 3 | Text Submission from Settings: type 30+ characters, **do not submit** | Text and character counter kept; close the sheet without submitting | `text-submission-settings-after-cycle.png` |
| 3.4 | AC 1 | Text Submission from home: same | Text kept | `text-submission-home-after-cycle.png` |
| 3.5 | AC 1 | Setup steps from Settings (Setup Instructions): swipe to page 4 | Page 4 and its dot stay selected | `setup-from-settings-p4-after-cycle.png` |
| 3.6 | AC 1 | First run: uninstall, reinstall, launch, Next ×4 to page 4 | Page 4 kept, no flash, no jump to page 0 | `setup-first-run-p4-after-cycle.png` |
| 3.7 | AC 1 | Pro cover, view only (from Settings or v2 welcome → Learn About Pro). Don't purchase or restore | Cover stays open. Known, out of scope: on outer landscape the top of the Pro cover and the v2 welcome title are clipped (Story 11.5, held until after Nov 3) | `pro-cover-after-cycle.png` |
| 3.8 | AC 4 | Optional log check: `xcrun simctl spawn "$DUO" log stream --level info --predicate 'subsystem == "com.millermedia.ElectionDeflection"'` while folding with the home screen open, after putting the app in the eligible state from 10.4 and letting that first prompt fire, then setting `lastReviewRequestDate` back 121 days | No "Requesting App Store review" line and no review or upgrade prompt caused by a fold. (The record proved "no `scenePhase` change on fold" with a temporary `print`; this pass doesn't add code, so this is the closest no-code check) | note |
| 3.9 | AC 1 (**open**) | Repeat 3.2 and 3.3 at AX5 text size and in Light appearance | Same as above | optional |
| 3.10 | AC 1 | Split View narrow/wide | Not available for the Duo simulator (record says so); mark N/A, Story 11.8 | — |

### 11.7 Setup instructions fit Duo (PR #19)

Run both entry points: first run (fresh install) and Settings > Setup Instructions. Pages: 0 welcome, 1-6 steps, 7 "Almost Done!".

| # | AC | Steps | Expected | Screenshot |
|---|---|---|---|---|
| 7.1 | AC 1 | Row 1, every page | Nothing clipped on the left edge; text wraps; welcome page scrolls to "View Source Code" clear of the dots; Next/Done narrower (about 340 pt) and centered (approved 2026-10-27) | `row1-outer-portrait-p0.png` … `p7` (at least p0, p4, p7) |
| 7.2 | AC 1 | Row 2, every page | One column; titles not truncated; screenshot at least about 160 pt; page scrolls; content ends above the dots; Next/Done and "Back to Step 1" inside the safe area | `row2-outer-landscape-p0/p4/p7.png` |
| 7.3 | AC 2 | Rows 3 and 4, step pages | Text left, screenshot right; screenshot fitted, not stretched; Next/Done capped at 640 pt (full width on inner portrait); welcome and Almost Done! are single blocks | `row3-…-p4.png`, `row4-…-p4.png` |
| 7.4 | AC 2 | On page 4: fold, unfold, rotate | Page 4 and its dot stay selected; layout switches live | — (covered by 3.5/3.6) |
| 7.5 | AC 3 | AX5 on rows 1 and 3 | All text wraps (hyphenation allowed), no overlap, every page scrolls | `row1-…-p4-ax5.png`, `row3-…-p4-ax5.png` |
| 7.6 | AC 5 | First run: finish → Get Started → home. From Settings: Setup Instructions → Done | Get Started lands on home; Done returns to Settings; reopening starts on Welcome again | — |
| 7.7 | AC 1 | iPhone 17 Pro portrait, pages 0-7 | Same as before; pages 3-5 sit about ⅓ pt lower because of `.largeTitle` (approved 2026-10-27) | `pro17-portrait-p0…p7.png` (optional) |
| 7.8 | AC 4 | In the Duo simulator's Settings app: Settings → Apps | Steps 1-2 text matches ("Open Settings", "Scroll down and tap on 'Apps'"). Steps 3-5 (Messages → Unknown Senders → …) **can't be walked**: the simulator has no Messages app. Mark "simulator N/A, device check" | `settings-apps.png` |
| 7.9 | AC 1 (**open, optional**) | iOS 16 simulator, pages 0, 4, 7 | Unchanged | or "runtime not available" |

### 10.1 / 10.2 Review prompt timing

**What the code does** (`ElectionDeflection/Services/ReviewRequestManager.swift`, `MainAppView.swift`, `Shared/SharedConstants.swift`):

- Every time `MainAppView` sees `scenePhase` become `.active`: `recordLaunch()` (adds 1 to `appLaunchCount`, sets `firstLaunchDate` once), then `evaluateReviewRequest()`. Going `.inactive`: `recordResignActive()` sets `lastActiveDate = now`.
- `evaluateReviewRequest()` waits **2 seconds**, then skips if `showingProUpgrade`, `showingSettings` or `showingTextSubmission` is true; otherwise calls `requestReviewIfEligible()`.
- `requestReviewIfEligible()`: no if a request was made in the last **120 days** (`lastReviewRequestDate`); no if `appLaunchCount < 5`; yes if **any** of: 7+ days since `firstLaunchDate`, 3+ days since `proPurchaseDate`, 14+ days since `lastActiveDate`. On yes it sets `lastReviewRequestDate = now`, logs `Requesting App Store review` (os_log, subsystem `com.millermedia.ElectionDeflection`, category `ReviewRequest`, level info) and calls `SKStoreReviewController.requestReview(in:)` on the foreground-active window scene.
- `StoreKitService` calls `recordPurchase()` (`proPurchaseDate = now`) after a successful purchase.
- All of these keys live in the app's **standard** `UserDefaults` (not the App Group): `appLaunchCount`, `firstLaunchDate`, `lastActiveDate`, `proPurchaseDate`, `lastReviewRequestDate`.
- **There are no debug hooks** (no launch arguments, environment variables, `#if DEBUG` paths or hidden buttons for review timing). The only ways in are editing those defaults on the simulator with the app terminated, and watching the log line.

**How StoreKit behaves:** Apple's docs say that in **development** (a build run from Xcode, including the simulator) the rating view is **always** shown when requested, and the Submit button is disabled; in **TestFlight** the call does nothing; in the App Store build the system decides, at most 3 times in 365 days. So on the simulator a dialog appearing proves our logic asked for it; it says nothing about how often real users will see it.

**Differences from the 10.1 AC worth deciding on (not fixed here):**

1. The AC says `RequestReviewAction` (SwiftUI); the code uses `SKStoreReviewController.requestReview(in:)` (comment explains why). It works, but Apple has deprecated it in newer SDKs in favor of `AppStore.requestReview(in:)` / `RequestReviewAction`.
2. The 5-launch minimum applies to **all three** triggers (stricter than the AC for post-purchase and returning user). It does satisfy "never within the first 3 launches".
3. **Returning user can only fire on a cold launch.** On a warm resume, iOS goes `background → inactive → active`; the `.inactive` step runs `recordResignActive()` and resets `lastActiveDate` to now just before the `.active` check, so "14+ days inactive" is never true. On a cold launch only `.active` is seen (11.3 log), so it works there. Checks 10.8 and 10.9 confirm this on the simulator.
4. `launchCount` counts every `.active`, including returning from Control Center or a system alert (noted in 11.3; a fold does **not** count, per 11.3).
5. The "no interruption" guard knows only `MainAppView`'s own sheets, not `ContentView`'s v2-welcome or Pro covers (noted in 11.3; masked by the thresholds).
6. "Prompt history" is just `lastReviewRequestDate`.

**Setup for the simulator checks** (app installed with `simctl` or run from Xcode; onboarding completed so `MainAppView` is on screen):

```bash
DATA=$(xcrun simctl get_app_container "$DUO" "$BUNDLE" data)
PREFS="$DATA/Library/Preferences/$BUNDLE"          # the app's standard UserDefaults plist, without .plist
ago() { date -u -v-"$1"d '+%Y-%m-%d %H:%M:%S +0000'; }   # macOS date: N days ago

# Always terminate before editing, then cold-launch:
xcrun simctl terminate "$DUO" "$BUNDLE"
xcrun simctl spawn "$DUO" defaults read "$PREFS"            # show current values

# Watch for the request in a second Terminal tab:
xcrun simctl spawn "$DUO" log stream --level info \
  --predicate 'subsystem == "com.millermedia.ElectionDeflection" AND category == "ReviewRequest"'
```

Write values with `xcrun simctl spawn "$DUO" defaults write "$PREFS" <key> -int N` or `-date "$(ago 8)"`, remove with `defaults delete "$PREFS" <key>`. (This mirrors how the 11.2/11.7 records edited App Group defaults on the simulator. If the app doesn't pick up an edit, check that it was terminated first; if `-date` is rejected, record that and fall back to the unit tests.)

| # | AC | Setup (app terminated) | Action | Expected | Evidence |
|---|---|---|---|---|---|
| 10.1 | 10.2 tests | — | Run `ReviewRequestManagerTests` (section 2) | All 15 pass | test output |
| 10.2 | launch count | Fresh install, finish onboarding | `defaults read`; then terminate + launch twice; read again | `appLaunchCount` goes up by 1 per cold launch; `firstLaunchDate` set once and unchanged | `defaults read` output |
| 10.3 | min launches | `appLaunchCount` 2, `firstLaunchDate` = `ago 30`, delete `lastReviewRequestDate` | Cold launch, wait 5 s | Count becomes 3; **no dialog**, no log line | `$OUT/10-x/few-launches.png` |
| 10.4 | post-install trigger | `appLaunchCount` 4, `firstLaunchDate` = `ago 8`, delete `lastReviewRequestDate`, `proPurchaseDate`, `lastActiveDate` | Cold launch, wait 3 s | Count 5; log `Requesting App Store review`; development rating dialog appears (Submit disabled); `lastReviewRequestDate` ≈ now | `post-install-dialog.png` |
| 10.5 | cooldown | Right after 10.4 | Dismiss, terminate, cold launch | No dialog, no log line, `lastReviewRequestDate` unchanged | `cooldown.png` |
| 10.6 | cooldown expiry | `lastReviewRequestDate` = `ago 121` | Cold launch | Dialog and log line again | `cooldown-expired.png` |
| 10.7 | too recent | `appLaunchCount` 10, `firstLaunchDate` = `ago 3`, delete the other three dates | Cold launch | No dialog | — |
| 10.8 | returning user (cold) | `appLaunchCount` 10, `firstLaunchDate` = `ago 1`, `lastActiveDate` = `ago 15`, delete `lastReviewRequestDate` | Cold launch | Dialog (returning-user trigger) | `returning-cold.png` |
| 10.9 | returning user, warm (finding 3) | `appLaunchCount` 10, `firstLaunchDate` = `ago 1`, delete `lastReviewRequestDate` and `proPurchaseDate` | Cold launch, wait 3 s (no dialog expected). Press Home (⇧⌘H). While it is in the background, set `lastActiveDate` = `ago 15`. Reopen the app from the Home screen (not `simctl launch`), wait 3 s, then `defaults read` | Per finding 3: **no dialog**, and `lastActiveDate` ≈ now (the `.inactive` before `.active` overwrote it). A dialog here means finding 3 is wrong; note which | `defaults read` output |
| 10.10 | post-purchase | Run from Xcode with the local StoreKit config; buy annual (test transaction); confirm `proPurchaseDate` is set; then terminate, set `proPurchaseDate` = `ago 4`, `appLaunchCount` 10, `firstLaunchDate` = `ago 1`, delete `lastReviewRequestDate` and `lastActiveDate`; run again from Xcode | — | Dialog and log line (post-purchase trigger) | `post-purchase.png` |
| 10.11 | no interruption | Eligible state as in 10.4 | Cold launch and tap the Settings gear within 2 seconds | No dialog; `lastReviewRequestDate` **not** set (the guard skips, it doesn't consume the request) | `guard-settings.png` |
| 10.12 | onboarding | Fresh install, `appLaunchCount` irrelevant | Stay on onboarding pages for 5 s | No dialog (`MainAppView` isn't on screen during first-run onboarding) | — |

Clean up afterwards: `xcrun simctl uninstall "$DUO" "$BUNDLE"`.

---

## 4. On-phone checks (optional, Decision D3)

D3: verification is simulator-based; a real device is optional and nothing claims real-device testing unless it was done. Matt has no iPhone Duo until December 2026, so Duo-hardware items stay known gaps. Running the app on a phone means a **development-signed build from Xcode** (Matt's own action and approval; nothing here touches TestFlight or App Store Connect).

| # | Check | Steps | Expected |
|---|---|---|---|
| P1 | 10.2 "real device confirms the system alert" | Defaults can't be edited on a device from the Mac and there are no debug hooks, so this only works on an iPhone where a development build (Run from Xcode) has naturally reached a trigger (5+ launches and 7+ days since first launch). Otherwise mark "not run; simulator 10.4 covers the logic" | Development rating dialog appears with Submit disabled. It never appears in TestFlight (Apple), so don't test there |
| P2 | 11.7 steps 3-5 (D8) | On an iPhone with iOS 27.x (any model): Settings → Apps → Messages → Unknown Senders → Screen Unknown Senders → Text Message Filter | Wording and screens match steps 3-5 and the `ios26_*` images. If not, open a follow-up; no copy change without this check |
| P3 | Filter still works on iOS 27.x | Enable ElectionDeflection under Text Message Filter, send a political test text from an unknown number | Lands in Spam/Filtered (filter extension can't run in the simulator) |
| P4 | Duo hardware (Dec 2026) | Fold/unfold with Settings, Test the Filter and Text Submission open; watch for a review prompt or a double launch count | Same as 11.3 on the simulator; real hinge timing is the gap |

---

## 5. Sign-off table

Fill in Pass / Fail / N/A and a short note (screenshot name, observed value, or reason).

| Story | Check | Pass/Fail | Notes |
|---|---|---|---|
| all | Unit tests on iPhone 17 Pro | | |
| all | Unit tests on iPhone Duo (iOS 27.1) | | |
| 11.2 | 2.1 iPhone 17 Pro home unchanged | | |
| 11.2 | 2.2 row 1 outer portrait | | |
| 11.2 | 2.3 row 2 outer landscape scrolls | | |
| 11.2 | 2.4 row 3 inner portrait two columns | | |
| 11.2 | 2.5 row 4 inner landscape two columns | | |
| 11.2 | 2.6 fold/unfold live switch | | |
| 11.2 | 2.7 Pro state rows 1 and 4 | | |
| 11.2 | 2.8 AX5 rows 1 and 3 | | |
| 11.2 | 2.9 Light/Dark | | |
| 11.2 | 2.10 VoiceOver order | | |
| 11.2 | 2.11 iOS 16 | | |
| 11.3 | 3.1 Settings sheet | | |
| 11.3 | 3.2 Test the Filter | | |
| 11.3 | 3.3 Text Submission (Settings) | | |
| 11.3 | 3.4 Text Submission (home) | | |
| 11.3 | 3.5 Setup from Settings p4 | | |
| 11.3 | 3.6 First-run setup p4 | | |
| 11.3 | 3.7 Pro cover (view only) | | |
| 11.3 | 3.8 No prompt on fold (log) | | |
| 11.3 | 3.9 AX5 / Light re-run | | |
| 11.3 | 3.10 Split View | N/A | Not offered for Duo simulator; Story 11.8 |
| 11.7 | 7.1 row 1 all pages | | |
| 11.7 | 7.2 row 2 all pages | | |
| 11.7 | 7.3 rows 3-4 side by side | | |
| 11.7 | 7.4 page kept through fold | | |
| 11.7 | 7.5 AX5 rows 1 and 3 | | |
| 11.7 | 7.6 both entry points | | |
| 11.7 | 7.7 iPhone 17 Pro pages | | |
| 11.7 | 7.8 Settings path steps 1-2 (sim) | | |
| 11.7 | 7.9 iOS 16 | | |
| 10.2 | 10.1 ReviewRequestManagerTests | | |
| 10.1 | 10.2 launch count | | |
| 10.1 | 10.3 min launches | | |
| 10.1 | 10.4 post-install trigger | | |
| 10.1 | 10.5 cooldown | | |
| 10.1 | 10.6 cooldown expiry | | |
| 10.1 | 10.7 too recent | | |
| 10.1 | 10.8 returning user, cold | | |
| 10.1 | 10.9 returning user, warm (finding 3) | | |
| 10.1 | 10.10 post-purchase | | |
| 10.1 | 10.11 no prompt over Settings | | |
| 10.1 | 10.12 none during onboarding | | |
| 10.1 | Decide: findings 1-6 (accept / follow-up story) | | |
| optional | P1 device review dialog | | |
| optional | P2 iOS 27 Settings path steps 3-5 | | |
| optional | P3 filter on iOS 27 device | | |
| optional | P4 Duo hardware | | Known gap until Dec 2026 |

**Signed off by:** ____________ **Date:** ____________ **Xcode / runtime:** ____________

## Sources

- Story files `_bmad-output/implementation-artifacts/11-2-…`, `11-3-…`, `11-7-…`, `10-1-…`, `10-2-…` and their Dev Agent Records; `11-1-…` for the toolchain check.
- `CONTRIBUTING.md` (Duo size-class table, test command, filter extension can't run in the simulator); `docs/DUO_GOAL_HANDOFFS.md`; Epic 11 decisions D3 and D8 in `_bmad-output/planning-artifacts/epics.md`.
- Apple: [SKStoreReviewController.requestReview](https://developer.apple.com/documentation/storekit/skstorereviewcontroller/requestreview()) ("always displayed" in development, "no effect" in TestFlight); [Requesting App Store reviews](https://developer.apple.com/documentation/storekit/requesting-app-store-reviews); [Prepare your app for iPhone Duo](https://developer.apple.com/iphone-duo/prepare/).
