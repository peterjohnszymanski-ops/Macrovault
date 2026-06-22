#!/usr/bin/env bash
#
# MacroVault — one-shot local setup (personal use only).
#
# Generates the native iOS/Android project around lib/, patches the permission
# keys the app needs, installs deps, and launches the iOS simulator.
#
# Safe to re-run: every step is idempotent.
#
# Usage:
#   cd ~/Projects/macrovault
#   ./setup.sh            # set up and run on a simulator
#   ./setup.sh --no-run   # set up only, don't launch
#
set -euo pipefail

RUN=1
[[ "${1:-}" == "--no-run" ]] && RUN=0

ORG="com.macrovault"
NAME="macrovault"
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

say()  { printf "\n\033[1;32m▸ %s\033[0m\n" "$1"; }
warn() { printf "\n\033[1;33m! %s\033[0m\n" "$1"; }
die()  { printf "\n\033[1;31m✗ %s\033[0m\n" "$1"; exit 1; }

[[ -d lib && -f pubspec.yaml ]] || die "Run this from the macrovault/ folder (lib/ and pubspec.yaml must be here)."

# ---------------------------------------------------------------------------
# 1. Flutter
# ---------------------------------------------------------------------------
if ! command -v flutter >/dev/null 2>&1; then
  warn "Flutter not found — cloning the stable channel to ~/flutter (~1 GB)."
  if [[ ! -d "$HOME/flutter" ]]; then
    git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$HOME/flutter"
  fi
  export PATH="$PATH:$HOME/flutter/bin"
  if ! grep -q 'flutter/bin' "$HOME/.zshrc" 2>/dev/null; then
    echo 'export PATH="$PATH:$HOME/flutter/bin"' >> "$HOME/.zshrc"
    warn "Added Flutter to PATH in ~/.zshrc — open a new terminal later to pick it up."
  fi
fi
say "Flutter: $(flutter --version | head -1)"

# ---------------------------------------------------------------------------
# 2. Xcode (required for iOS) — checked, not auto-installed
# ---------------------------------------------------------------------------
if ! xcode-select -p >/dev/null 2>&1 || ! command -v xcodebuild >/dev/null 2>&1; then
  die "Xcode is required for iOS. Install it from the App Store, then run:
       sudo xcodebuild -license accept && xcodebuild -runFirstLaunch
     and re-run ./setup.sh.  (Xcode needs ~15 GB free.)"
fi
say "Xcode: $(xcodebuild -version | head -1)"

if ! command -v pod >/dev/null 2>&1; then
  warn "CocoaPods not found. Install with:  sudo gem install cocoapods   (or: brew install cocoapods)"
  warn "Continuing — the first iOS build will need it."
fi

# ---------------------------------------------------------------------------
# 3. Generate native platform folders around lib/ (won't touch lib/ or pubspec)
# ---------------------------------------------------------------------------
say "Generating ios/ and android/ (preserves your lib/)…"
flutter create --org "$ORG" --project-name "$NAME" --platforms=ios,android .

# ---------------------------------------------------------------------------
# 4. Patch iOS permission keys (camera / photos / Face ID) + deploy target
# ---------------------------------------------------------------------------
PLIST="ios/Runner/Info.plist"
set_plist() { # key, value
  /usr/libexec/PlistBuddy -c "Set :$1 $2" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :$1 string $2" "$PLIST"
}
if [[ -f "$PLIST" ]]; then
  say "Patching Info.plist usage descriptions…"
  set_plist NSCameraUsageDescription      "MacroVault uses the camera to scan barcodes and take progress photos."
  set_plist NSPhotoLibraryUsageDescription "MacroVault can import progress photos. Imported photos are copied privately and stripped of location data."
  set_plist NSFaceIDUsageDescription      "MacroVault uses Face ID to lock your private Progress Vault."
fi

PODFILE="ios/Podfile"
if [[ -f "$PODFILE" ]]; then
  if grep -qE "^\s*#?\s*platform :ios" "$PODFILE"; then
    sed -i '' -E "s/^[[:space:]]*#?[[:space:]]*platform :ios.*/platform :ios, '13.0'/" "$PODFILE"
  else
    printf "platform :ios, '13.0'\n%s" "$(cat "$PODFILE")" > "$PODFILE"
  fi
  say "Set iOS deployment target → 13.0"
fi

# ---------------------------------------------------------------------------
# 5. Android: local_auth needs FlutterFragmentActivity (best-effort)
# ---------------------------------------------------------------------------
MAIN_KT="$(find android/app/src/main -name MainActivity.kt 2>/dev/null | head -1 || true)"
if [[ -n "$MAIN_KT" ]] && grep -q "FlutterActivity" "$MAIN_KT"; then
  say "Patching Android MainActivity for local_auth…"
  sed -i '' 's/io.flutter.embedding.android.FlutterActivity/io.flutter.embedding.android.FlutterFragmentActivity/' "$MAIN_KT"
  sed -i '' 's/: FlutterActivity()/: FlutterFragmentActivity()/' "$MAIN_KT"
fi

# ---------------------------------------------------------------------------
# 6. Dependencies
# ---------------------------------------------------------------------------
say "Resolving Dart/Flutter packages…"
flutter pub get

say "Static analysis (warnings are fine for a first run):"
flutter analyze || warn "Analyzer reported issues — review above; they won't block running."

# ---------------------------------------------------------------------------
# 7. Run
# ---------------------------------------------------------------------------
if [[ "$RUN" -eq 1 ]]; then
  say "Booting an iOS Simulator and launching MacroVault…"
  open -a Simulator || true
  sleep 4
  flutter run
else
  say "Setup complete. To launch:  flutter run"
fi

cat <<'NOTE'

──────────────────────────────────────────────────────────────────────────────
Personal-use notes
• AI features (food-photo recognition, weekly review, photo body-fat) call
  Anthropic directly with a key you enter in More → Food photo AI. Fine for
  personal use; it never leaves your device except to Anthropic.
• Branded food search uses the free Open Food Facts database (crowd-sourced).
• To run on your iPhone (not just the simulator): open ios/Runner.xcworkspace
  in Xcode once, set a Team (your free Apple ID works), then `flutter run`.
──────────────────────────────────────────────────────────────────────────────
NOTE
