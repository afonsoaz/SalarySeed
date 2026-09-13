#!/bin/bash
# Build, install and launch SalarySeed on a booted simulator.
#
# WHY THIS EXISTS. There are two SalarySeed DerivedData folders on this machine,
# one of them abandoned since July, and `find ~/Library/.../SalarySeed-*/... | head -1`
# picks whichever the filesystem happens to return first. It picked the stale one
# during v1.2a and put a July build on the simulator, so a screenshot taken to
# verify a fix was a screenshot of the app without it. Nothing errored; the tab
# bar just quietly had the old tabs in it.
#
# `xcodebuild -showBuildSettings` is the only thing that knows which folder this
# scheme actually builds into. Ask it, every time.
set -euo pipefail

DEVICE="${1:-iPhone 17}"
BUNDLE=com.afonsoazevedo.salaryseed

xcodebuild -scheme SalarySeed -destination "platform=iOS Simulator,name=$DEVICE" build \
  | grep -E "^\*\* BUILD|error:" || true

APP_DIR=$(xcodebuild -scheme SalarySeed -destination "platform=iOS Simulator,name=$DEVICE" \
  -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR = /{print $2; exit}')
APP="$APP_DIR/SalarySeed.app"
[ -d "$APP" ] || { echo "no app at $APP"; exit 1; }

echo "installing $(date -r "$APP/SalarySeed" '+%Y-%m-%d %H:%M')  $APP"
xcrun simctl terminate booted "$BUNDLE" 2>/dev/null || true
xcrun simctl install booted "$APP"
xcrun simctl launch booted "$BUNDLE"
