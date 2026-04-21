#!/usr/bin/env bash
# Build + install + launch AndySwissKnife on the iOS Simulator.
# Usage: ./scripts/run.sh [device-name]   (default: iPhone 17)

set -euo pipefail

DEVICE="${1:-iPhone 17}"
SCHEME="AndySwissKnife"
PROJECT="AndySwissKnife.xcodeproj"
BUNDLE_ID="com.andyzhang.AndySwissKnife"
CONFIG="Debug"
DESTINATION="platform=iOS Simulator,name=${DEVICE}"

cd "$(dirname "$0")/.."

echo "Building for Simulator (${DEVICE})..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO \
  -quiet \
  build

APP_PATH=$(xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "$DESTINATION" \
  -showBuildSettings 2>/dev/null \
  | awk -F ' = ' '/ TARGET_BUILD_DIR / {gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2; exit}')
APP="${APP_PATH}/${SCHEME}.app"

if [ ! -d "$APP" ]; then
  echo "Cannot find built app at $APP"
  exit 1
fi

echo "Booting ${DEVICE}..."
xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator
xcrun simctl bootstatus "$DEVICE" -b >/dev/null

echo "Installing..."
xcrun simctl install booted "$APP"

echo "Launching ${BUNDLE_ID}..."
xcrun simctl launch booted "$BUNDLE_ID" >/dev/null

echo "Running on ${DEVICE}."
