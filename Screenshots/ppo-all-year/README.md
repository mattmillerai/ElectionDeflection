# PPO screenshots — treatment A, “Block unwanted texts all year”

Chosen App Store Product Page Optimization treatment for ElectionDeflection. Matt picked treatment A, and these are the treatment A assets kept in the repo. Variants B and C were also drafted and submitted; see the live test status below.

The product-page test is managed in App Store Connect against the live 2.1.6 listing. This PR only holds the A assets in the dev repo. Merging only adds these marketing assets to the repo; it does not release anything or change App Store Connect.

## Live App Store Connect test (status)

- Experiment `8e2bfa83-9ea1-4698-bfee-a7104f91c8af`, "All-year screenshots vs current (Nov 2026)", en-US, iPhone 6.9-inch.
- Apple approved it and the test started on Nov 21, 2026 with all three treatments (A, B and C) that had been submitted for review, sharing 50% of traffic (about 17% each); the original product page keeps the other 50%. It runs until Feb 19, 2027.
- Apple does not allow removing treatments from a started test, so B and C could not be dropped. An A-only test at 50% would require stopping this test (irreversible) and a new review; that has not been done.
- When reading results, compare treatment A against the original page. B and C assets are not kept in this directory (they are in this branch's git history, commit 50ec36a).

## Live listing (checked 20 Nov 2026)

- App Store: [ElectionDeflection](https://apps.apple.com/us/app/electiondeflection/id6670375536) (id `6670375536`)
- Version 2.1.6. Subtitle: “Privacy-First Text Filter.”
- The live product page is **Designed for iPhone / Only for iPhone**. This set is **iPhone 6.9″ only** (1320×2868, portrait, RGB PNG, no alpha). No 13″ iPad size was produced.
- Current store screenshots are the five raw 6.9″ app captures (`Screenshots/scene-1` … `scene-5`) with no marketing typography.

## Treatment A — Year-round lead

Leads with “Block unwanted texts all year,” then immediately names election and political texts so it cannot be read as a general SMS or scam blocker.

| # | File | Headline | Subhead | Source UI |
|---|------|----------|---------|-----------|
| 1 | `01-all-year_6.9-iphone-1320x2868.png` | Block unwanted texts all year | Election and political texts, moved to your Spam folder | `Screenshots/scene-2_free-tier-home_6.9-iphone17promax.png` |
| 2 | `02-political-texts-all-year_6.9-iphone-1320x2868.png` | Political texts show up all year | Campaign messages don't stop after Election Day | `Screenshots/scene-1_onboarding-welcome_6.9-iphone17promax.png` |
| 3 | `03-moved-to-spam_6.9-iphone-1320x2868.png` | Moved to Spam, automatically | Uses Apple's built-in message filtering | `Screenshots/processed/ios26_filter_menu.png` |
| 4 | `04-turn-it-on_6.9-iphone-1320x2868.png` | Turn it on in Settings | Choose ElectionDeflection as your Text Message Filter | `Screenshots/IMG_7035.PNG` |
| 5 | `05-private-on-device_6.9-iphone-1320x2868.png` | Private. On your device. | No accounts, no tracking — and the code is open source | `Screenshots/scene-4_pro-settings_6.9-iphone17promax.png` |

Brand chrome is navy `#304789`, gold `#D4A843`, the app icon, and Geist typography. App UI in every frame is a real capture from this repo. The in-app Pro comparison screen (scene-3) was not used, because it still shows a “99%+” accuracy row.

## Claims kept modest

Used only claims the live listing or repo already supports (on-device filtering, Spam folder, Apple’s message filtering, keyword vs Pro AI, no accounts / no tracking, open source, political / election texts).

Intentionally avoided:

- Accuracy percentages (no 96.7%, no 99%+)
- Scam-blocking or general “blocks all spam” promises
- “Catches every…”, “no setup hassle”, “learns patterns”, “best protection during election season”

Personal Messages threads were not used. The filter-menu crop is the in-repo processed shot with contacts already blurred.

## Contact sheet

`contact-sheet.png` shows the five treatment A screenshots.

## Regenerating

From this directory, with the dev repo available (parent of `Screenshots/`):

```bash
python3 build_ppo_screenshots.py
```

Requires Pillow, fonttools, and the system Geist variable font (used to instantiate headline weights). Output is overwritten in `variant-a/` and `contact-sheet.png`.
