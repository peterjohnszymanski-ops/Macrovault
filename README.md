# MacroVault

A private, **local-first** proof-of-progress app. Fast daily nutrition + body logging that feeds a private, searchable **Progress Vault** so you can see what actually works over time.

> Thesis: not a calorie tracker with extras — a proof-of-progress app where the daily logger exists to feed the Vault.
> Two non-negotiables: **(1) Trend, not truth** — headline weight is always a smoothed trend, never a raw daily number. **(2) Fast logging beats fancy** — repeating a usual meal is one tap from home.

---

## Status

Phase 1 (MVP) codebase. No accounts, no cloud, no AI. Everything is on-device and encrypted at rest.

## Prerequisites (one-time, on your Mac)

This repo is complete Dart/Flutter source but needs the toolchain to build/run:

1. **Install Flutter** (includes Dart):
   ```bash
   git clone https://github.com/flutter/flutter.git -b stable ~/flutter
   echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc && source ~/.zshrc
   flutter --version
   ```
2. **Install Xcode** (required to run on iOS) from the App Store, then:
   ```bash
   sudo xcodebuild -license accept
   xcodebuild -runFirstLaunch
   ```
   > Xcode needs ~15 GB free. Free up disk first if needed.
3. **CocoaPods** (iOS native deps):
   ```bash
   sudo gem install cocoapods
   ```

## First run

From inside `macrovault/`:

```bash
# Generate the iOS/Android platform folders around this lib/ (does NOT overwrite lib/ or pubspec.yaml)
flutter create --org com.macrovault --project-name macrovault .

flutter pub get
flutter run            # on a simulator or connected device
```

Other useful commands:

```bash
flutter analyze        # static analysis — should pass clean
flutter test           # unit tests (domain logic)
```

> **Why sqflite_sqlcipher instead of Drift?** The PRD specified Drift, but Drift requires a `build_runner` codegen step. To keep this repo runnable as-written (no generated files), we use `sqflite_sqlcipher` with hand-written DAOs. Same SQLCipher encryption guarantee.

## Architecture

```
lib/
  core/        theme, formatters, constants, result types, app shell + router
  models/      immutable data classes (Food, FoodEntry, Goal, WeightEntry, ...)
  data/        encrypted database + DAOs (one DAO per aggregate)
  domain/      pure business logic: target calc, trend smoothing, weekly metrics
  services/    food API (OFF/USDA), key/encryption, photo storage (EXIF strip), export
  state/       Riverpod providers wiring data + domain into the UI
  features/    one folder per screen area
    onboarding/ dashboard/ logging/ weight/ measurements/ photos/
    weekly_review/ vault/ settings/ common/
```

### Key design decisions

- **Trend engine** (`domain/trend.dart`): weight headline is an exponentially-weighted moving average (EWMA, default α=0.1). A single fat-finger weigh-in barely moves it.
- **Nutrition snapshots**: `FoodEntry` stores `snapshotKcal`/`snapshotMacros` at log time, so editing a `Food` never rewrites history.
- **Photo privacy** (`services/photo_storage.dart`): images are decoded and re-encoded on import (EXIF/GPS stripped), then stored in the app's encrypted documents dir — never the camera roll. No health metrics are ever embedded in image bytes.
- **Vault lock**: biometric/PIN gate (`local_auth`) separate from the diary; re-locks on background.
- **Encryption**: the SQLCipher key is generated once and stored in the iOS Keychain via `flutter_secure_storage`.
- **Export**: `services/export_service.dart` builds a ZIP (JSON + CSV + photos) with an explicit pre-export privacy warning; metrics are never silently embedded in exported images.

## Data model

See `lib/data/database.dart` for the schema. Core tables: `users`, `goals`, `foods`, `food_entries`,
`meal_templates`, `recipes`, `recipe_ingredients`, `weight_entries`, `measurement_entries`,
`water_logs`, `exercise_logs`, `progress_photos`, `vault_items`, `progress_capsules`,
`weekly_reviews`, `reminders`.

## Fast-logging features (MyNetDiary parity)

The daily logger is tuned to feel like what heavy trackers expect:

- **Recency/frequency ranking** — a food you've logged floats to the top of search.
- **Remembers your last portion** — re-logging pre-fills the amount you actually used, not "1".
- **Meal-aware recents** — open Breakfast and your usual breakfast foods surface first.
- **Favorites** — star foods to pin them above everything.
- **Barcode scan**, **custom foods**, **recipes**, **saved meals / usuals** (one-tap).
- **Quick Add** — log raw calories/macros with no food record.
- **Log by servings or grams** — toggle per food.
- **Copy a day** — powers the No-Shame Reset "copy my last logged day".

### Food photo AI (opt-in)

"Snap a meal → AI estimates the foods → you confirm before anything saves." Because MacroVault is
local-first, this is **off by default**: it only runs after you enable it in **More → Food photo AI**
and provide a **vision proxy URL**. The app never holds an API key — your proxy calls the vision
model server-side. See `lib/services/vision_food_service.dart` for the proxy request/response
contract. A photo leaves the device only on this path, only with consent, and results always go
through a confirm step.

## Out of scope for Phase 1

Cloud sync/backup, accounts, social/sharing, family/coach modes, wearables, grocery/meal-plan
generators, gamified badges, exercise→calorie crediting. AI weekly summaries / Plateau Detective /
Protein Rescue remain `TODO(phase2)`.
