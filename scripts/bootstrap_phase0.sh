#!/usr/bin/env bash
# ============================================================================
# CourseCraft — Phase 0 bootstrap
# Runs AFTER Flutter + Android SDK are installed. Scaffolds the Flutter app
# in this directory and adds all dependencies. Idempotent-ish; safe to re-run.
# ============================================================================
set -euo pipefail

PROJ_DIR="/home/adithyan/Documents/Tracker_for_paru"
export PATH="$HOME/development/flutter/bin:$PATH"
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/emulator:$PATH"

cd "$PROJ_DIR"

echo "==> flutter version"
flutter --version

# Point Flutter at the Android SDK and accept licenses (non-interactive)
flutter config --android-sdk "$ANDROID_HOME" >/dev/null
yes | flutter doctor --android-licenses >/dev/null 2>&1 || true

# Create the Flutter app in-place. Idea.md/Plan.md/supabase/ are preserved;
# flutter create only adds the app skeleton (lib/, android/, ios/, pubspec.yaml).
echo "==> flutter create (org dev.coursecraft, app name coursecraft)"
flutter create . \
  --org dev.coursecraft \
  --project-name coursecraft \
  --platforms=android,ios \
  --description "CourseCraft academic tracker coaching toward a 9.5 SGPA"

echo "==> adding dependencies"
flutter pub add \
  flutter_riverpod \
  riverpod_annotation \
  go_router \
  supabase_flutter \
  freezed_annotation \
  json_annotation \
  fl_chart \
  flutter_local_notifications \
  timezone \
  permission_handler \
  image_picker \
  path_provider \
  path \
  intl \
  table_calendar \
  flutter_form_builder \
  form_builder_validators

echo "==> adding dev dependencies (codegen + lints)"
flutter pub add --dev \
  build_runner \
  riverpod_generator \
  riverpod_lint \
  custom_lint \
  freezed \
  json_serializable

echo "==> flutter pub get"
flutter pub get

echo "==> DONE. Next: drop in lib/ scaffold (theme, router, supabase service, app shell)."
echo "    Then: flutter run on an emulator."
