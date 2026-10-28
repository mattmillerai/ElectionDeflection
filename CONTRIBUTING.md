# Contributing to ElectionDeflection

Thanks for your interest in contributing to ElectionDeflection! This guide will help you get started.

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally
3. Follow the build instructions in [README.md](README.md)

**Requirements:**
- Xcode 26.0+ (required for App Store Connect uploads)
- iOS 16.0+ deployment target
- Apple Developer Program membership (for code signing and MessageFilterExtension testing)

## Development Setup

1. Open `ElectionDeflection.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Update `Shared/SharedConstants.swift` with your own identifiers:
   - `appGroupIdentifier` — your App Group ID
   - `annualProductID` / `lifetimeProductID` — your IAP product IDs from App Store Connect
4. Create `ElectionDeflection/Secrets.plist` from the template (the build expects it to exist; the placeholder value just disables text submissions):
   ```
   cp ElectionDeflection/Secrets.plist.example ElectionDeflection/Secrets.plist
   ```
5. Build and run on a physical device (message filtering requires a real device)

The SMS filter extension cannot be tested in the iOS Simulator. You need a physical device to test message filtering.

## How to Contribute

### Bug Reports

Found a bug? Please [open an issue](https://github.com/mattmillerai/ElectionDeflection/issues/new?template=bug_report.md) using the bug report template.

### Feature Requests

Have an idea? [Open a feature request](https://github.com/mattmillerai/ElectionDeflection/issues/new?template=feature_request.md) and describe your use case.

### Pull Requests

1. Fork the repository and create a branch from `main`
2. Make your changes
3. Add or update tests as needed
4. Ensure all tests pass
5. Submit a pull request with a clear description of your changes

## Code Style

- Follow existing Swift conventions and patterns in the codebase
- Use descriptive variable and function names
- Keep functions focused and concise
- Add comments only where the logic isn't self-evident

### Adaptive layout and iPhone Duo

- **iOS 16 floor.** The deployment target stays iOS 16.0 and CI builds with Xcode 26. Any symbol newer than iOS 16 needs `#available` plus an `#if` compile-time guard so the Xcode 26 build still compiles. Don't adopt the iOS 27.1-only `ArrangementView`, `ReservedRegion`, or `toolbarVerticalEdge`.
- **Lay out by available space.** Use `@Environment(\.horizontalSizeClass)` and the measured width (`GeometryReader`, `ViewThatFits`). Never branch on `UIDevice.current.orientation`, `userInterfaceIdiom`, `UIScreen.main`, or fixed device sizes.
- **Keep state across fold and rotate.** Switch layouts with `AnyLayout` (`HStackLayout` / `VStackLayout`) or `ViewThatFits`, not `if wide { A } else { B }` around views that hold state.
- **Never persist typed text** to survive a fold or resize (no `@SceneStorage`, `@AppStorage`, `UserDefaults`, or files).

| Duo display | Points | Size class (h × v) |
|---|---|---|
| Outer, portrait | 466×678 | compact × regular |
| Outer, landscape | 678×466 | compact × compact |
| Inner (half-open or open) | 669×951 / 951×669 | regular × regular |

Hinge angle does not change size classes. Background: Epic 11 in `_bmad-output/planning-artifacts/epics.md` (dev repo only).

### Project Structure

```
ElectionDeflection/           # Main app target
  Views/                      # SwiftUI views
  Services/                   # StoreKit, Keychain, notifications
  Extensions/                 # Color helpers
ElectionDeflectionFilter/     # ILMessageFilterExtension target
Shared/                       # Code shared between both targets
ElectionDeflectionTests/      # Unit tests
```

## Testing

All tests must pass before submitting a pull request. Run the test suite with:

```bash
xcodebuild test -scheme ElectionDeflection \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

- New features should include tests
- Bug fixes should include a test that reproduces the bug
- Do not remove or weaken existing tests

## Privacy Principles

ElectionDeflection has strict privacy requirements. **All contributions must follow these rules:**

1. **No networking in the extension or shared targets.** The filter extension and `Shared/` folder must contain zero networking code. This is enforced by automated guardrail tests.

2. **No analytics or tracking SDKs.** No Firebase, Amplitude, or any tracking framework. Also enforced by guardrail tests.

3. **No message content in logs.** SMS/MMS body text must never appear in any log statement. Use `privacy: .private` for any potentially sensitive data.

4. **No data collection.** All filtering happens on-device. Nothing is transmitted to any server.

5. **No server URLs or API keys in SharedConstants.** Enforced by guardrail tests.

These rules are automatically checked by tests in `ElectionDeflectionTests/SharedDataManagerTests.swift`. If your PR introduces networking code, analytics imports, or message content logging, the tests will fail.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).

## Questions?

Open an issue on [GitHub](https://github.com/mattmillerai/ElectionDeflection/issues) and we'll help you out.
