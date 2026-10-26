# ElectionDeflection

A privacy-first iOS app that filters political text messages using on-device keyword matching and Core ML — with zero data collection.

## Features

**Free Tier — Keyword Filtering**
- Filters political SMS/MMS using pattern matching against a curated keyword list
- Works on all iOS devices (iOS 11+)
- No account required, no data collected

**Pro Tier — AI-Powered Filtering**
- Core ML model trained to identify political messaging patterns
- Catches texts that keyword filtering misses
- All inference runs on-device — no network requests
- $9.99/year or $29.99 one-time purchase

## Privacy Architecture

ElectionDeflection makes **zero network requests** during normal operation. All filtering happens locally on your device:

- **No data collection** — we don't collect message content, usage data, or telemetry
- **No analytics** — no Firebase, Amplitude, or any tracking SDK
- **On-device ML** — the Core ML model is bundled with the app, not downloaded from a server
- **Open source** — inspect the code yourself to verify these claims

The only network activity is Apple's StoreKit when loading In-App Purchase pricing. The message filter extension itself has no networking code whatsoever.

For a detailed technical explanation, see [PRIVACY.md](PRIVACY.md). Our formal [Privacy Policy](PRIVACY_POLICY.md) is also available.

## How It Works

ElectionDeflection uses Apple's [ILMessageFilterExtension](https://developer.apple.com/documentation/identitylookup/ilmessagefilterextension) API to filter incoming SMS and MMS messages. When a message arrives:

1. iOS routes it through the filter extension
2. The extension checks the message against keyword patterns (Free) or ML classification (Pro)
3. Political messages are moved to the Junk folder
4. No message content is stored, logged, or transmitted

## Building from Source

**Requirements:**
- Xcode 16.0+
- iOS 18.0+ deployment target
- Apple Developer Program membership (for code signing and MessageFilterExtension)

**Steps:**
1. Clone the repository
2. Open `ElectionDeflection.xcodeproj` in Xcode
3. Select your development team in Signing & Capabilities
4. Update `Shared/SharedConstants.swift` with your own identifiers:
   - `appGroupIdentifier` — your App Group ID (must match Signing & Capabilities)
   - `annualProductID` / `lifetimeProductID` — your IAP product IDs from App Store Connect
5. Build and run on a device (message filtering requires a real device to test)

**Note:** The SMS filter extension cannot be tested in the iOS Simulator. You need a physical device to test message filtering. In-App Purchases require your own product IDs configured in App Store Connect.

## Project Structure

```
ElectionDeflection/           # Main app target
  Views/                      # SwiftUI views (onboarding, settings, upgrade)
  Services/                   # StoreKit, notifications, app icon management
  Extensions/                 # Color helpers
ElectionDeflectionFilter/     # ILMessageFilterExtension target
Shared/                       # Code shared between both targets
  SharedDataManager.swift     # App Groups UserDefaults manager
  SharedConstants.swift       # Shared constants and keys
  DefaultFilterData.swift     # Bundled keyword lists
ElectionDeflectionTests/      # Unit tests
```

## App Store

<!-- TODO: Add App Store link when published -->
Coming soon to the App Store.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
