#!/usr/bin/env bash
# One-time setup of the Flutter project on a machine with Flutter >= 3.22 installed.
set -euo pipefail
cd "$(dirname "$0")/../mobile"
# 1) create android/ ios/ platform folders without touching existing lib/ and pubspec.yaml
flutter create --project-name midad --org com.midad --platforms=android,ios .
# 2) dependencies + generated code (l10n + drift)
rm -f test/widget_test.dart   # default template test does not apply to MIDAD
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
# 3) launcher icons from the MIDAD mark
dart run flutter_launcher_icons
# 4) verify
flutter analyze
flutter test
echo "Phase 0 mobile bootstrap OK"
