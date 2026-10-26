<div align="center">

<img src="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=700&size=18&color=FF9900&center=true&vCenter=true&width=320&height=40&repeat=false&pause=1000&lines=Political+texts%2C+filtered." alt="Political texts, filtered." />

<pre>
 _                      
|_| _  __|_o _ ._       
|_|(/_(_ |_|(_)| |      
                        
 _     _                
| \ __|_| _  __|_o _ ._ 
|_/(/_| |(/_(_ |_|(_)| |
</pre>

</div>

<p align="center">
  <strong>ElectionDeflection: a privacy-first iOS app that filters political text messages using on-device keyword matching and Core ML. No accounts, no analytics, no tracking.</strong>
</p>

<p align="center">
  Message filtering runs on-device with no network requests. The only network use is Apple's StoreKit and the optional, user-initiated "submit example text" feature.
</p>

<p align="center">
  <a href="https://apps.apple.com/us/app/electiondeflection/id6670375536"><img src="https://img.shields.io/badge/App_Store-Download-0D96F6?style=flat-square&logo=apple&logoColor=white" alt="Download on the App Store"></a>
  <img src="https://img.shields.io/badge/iOS-16.0%2B-blue?style=flat-square&logo=apple&logoColor=white" alt="iOS 16.0+">
  <a href="https://github.com/mattmillerai/ElectionDeflection/blob/main/LICENSE"><img src="https://img.shields.io/github/license/mattmillerai/ElectionDeflection?style=flat-square" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/Swift-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/privacy-on--device-2ea44f?style=flat-square" alt="Privacy: on-device">
</p>

---

## Features

**Free Tier — Keyword Filtering**
- Filters political SMS/MMS using pattern matching against a curated keyword list
- Works on any iPhone running iOS 16.0 or later
- No account required, no data collected

**Pro Tier — AI-Powered Filtering**
- Core ML model trained to identify political messaging patterns
- Catches texts that keyword filtering misses
- All inference runs on-device — no network requests
- $9.99/year or $29.99 one-time purchase

## Privacy Architecture

Message filtering makes **zero network requests**. All filtering happens locally on your device:

- **No data collection** — we don't collect your messages, usage data, or telemetry
- **No analytics** — no Firebase, Amplitude, or any tracking SDK
- **On-device ML** — the Core ML model is bundled with the app, not downloaded from a server
- **Open source** — inspect the code yourself to verify these claims

The message filter extension itself has no networking code whatsoever. The app's only network activity is (1) Apple's StoreKit, when loading In-App Purchase pricing and processing purchases, and (2) the optional, user-initiated "submit example text" feature, which sends only text you paste and submit yourself over HTTPS to `electiondeflection.com/api/submit` to help improve the AI model. Nothing is ever sent automatically, and your incoming messages are never shared.

For a detailed technical explanation, see [PRIVACY.md](PRIVACY.md). Our formal [Privacy Policy](PRIVACY_POLICY.md) is also available.

## How It Works

ElectionDeflection uses Apple's [ILMessageFilterExtension](https://developer.apple.com/documentation/identitylookup/ilmessagefilterextension) API to filter incoming SMS and MMS messages. When a message arrives:

1. iOS routes it through the filter extension
2. The extension checks the message against keyword patterns (Free) or ML classification (Pro)
3. Political messages are moved to the Junk folder
4. No message content is stored, logged, or transmitted

## Building from Source

**Requirements:**
- Xcode 26.0+ (App Store Connect requires uploads built with Xcode 26 / the iOS 26 SDK or later)
- iOS 16.0+ deployment target
- Apple Developer Program membership (for code signing and MessageFilterExtension)

**Steps:**
1. Clone the repository
2. Open `ElectionDeflection.xcodeproj` in Xcode
3. Select your development team in Signing & Capabilities
4. Update `Shared/SharedConstants.swift` with your own identifiers:
   - `appGroupIdentifier` — your App Group ID (must match Signing & Capabilities)
   - `annualProductID` / `lifetimeProductID` — your IAP product IDs from App Store Connect
5. Create `ElectionDeflection/Secrets.plist` from the template: `cp ElectionDeflection/Secrets.plist.example ElectionDeflection/Secrets.plist` (the build expects it to exist; the placeholder value just disables text submissions)
6. Build and run on a device (message filtering requires a real device to test)

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

[Download ElectionDeflection on the App Store](https://apps.apple.com/us/app/electiondeflection/id6670375536)

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
