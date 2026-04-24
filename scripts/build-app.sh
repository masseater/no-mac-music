#!/usr/bin/env bash
set -euo pipefail

# Build NoMacMusic as a proper .app bundle so LSUIElement (menu bar only)
# and bundle identifier work correctly, and so Accessibility / Apple Events
# permissions are attached to a stable identity.
#
# Env overrides:
#   NOMACMUSIC_VARIANT=release|dev  default: release

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG="${CONFIG:-release}"
VARIANT="${NOMACMUSIC_VARIANT:-release}"
EXECUTABLE_NAME="NoMacMusic"
case "$VARIANT" in
  release)
    APP_NAME="NoMacMusic"
    DISPLAY_NAME="NoMacMusic"
    BUNDLE_ID="com.masseater.NoMacMusic"
    ;;
  dev)
    APP_NAME="NoMacMusic Dev"
    DISPLAY_NAME="NoMacMusic Dev"
    BUNDLE_ID="com.masseater.NoMacMusic.dev"
    ;;
  *)
    echo "error: NOMACMUSIC_VARIANT must be 'release' or 'dev' (got '$VARIANT')" >&2
    exit 1
    ;;
esac
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$EXECUTABLE_NAME"
if [[ ! -x "$BIN_PATH" ]]; then
  echo "error: built binary not found at $BIN_PATH" >&2
  exit 1
fi

echo "==> assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/$EXECUTABLE_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleName -string "$DISPLAY_NAME" "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleDisplayName -string "$DISPLAY_NAME" "$CONTENTS_DIR/Info.plist"

# Ad-hoc sign with entitlements so TCC can track permissions per stable path.
codesign --force \
  --sign - \
  --entitlements "$ROOT_DIR/Resources/NoMacMusic.entitlements" \
  --options runtime \
  "$APP_DIR"

echo "==> built $APP_DIR"
echo "bundle id: $BUNDLE_ID"
echo "variant: $VARIANT"
echo "run with: open \"$APP_DIR\""
