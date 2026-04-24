#!/usr/bin/env bash
set -euo pipefail

# One-shot installer for NoMacMusic.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/masseater/no-mac-music/main/scripts/install.sh | bash
#
# Env overrides:
#   NOMACMUSIC_REPO  default: https://github.com/masseater/no-mac-music
#   NOMACMUSIC_REF   default: main
#   NOMACMUSIC_DEST  default: /Applications/NoMacMusic.app

REPO="${NOMACMUSIC_REPO:-https://github.com/masseater/no-mac-music}"
REF="${NOMACMUSIC_REF:-main}"
DEST="${NOMACMUSIC_DEST:-/Applications/NoMacMusic.app}"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "error: NoMacMusic runs on macOS only." >&2
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "error: Swift toolchain not found."
  echo "       Install Xcode Command Line Tools first: xcode-select --install" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "error: git not found. Install Xcode Command Line Tools: xcode-select --install" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> Cloning $REPO ($REF) into $TMP"
git clone --depth 1 --branch "$REF" "$REPO" "$TMP/repo"
cd "$TMP/repo"

echo "==> Building release bundle"
bash scripts/build-app.sh >/dev/null

APP_SRC="$TMP/repo/dist/NoMacMusic.app"
if [[ ! -d "$APP_SRC" ]]; then
  echo "error: build did not produce $APP_SRC" >&2
  exit 1
fi

# Best-effort: stop any running copy so we can replace it.
pkill -f "NoMacMusic.app/Contents/MacOS/NoMacMusic" 2>/dev/null || true

if [[ -d "$DEST" ]]; then
  echo "==> Removing existing $DEST"
  rm -rf "$DEST"
fi

echo "==> Installing to $DEST"
# /Applications is world-writable on personal Macs; fall back to sudo if not.
if cp -R "$APP_SRC" "$DEST" 2>/dev/null; then
  :
else
  echo "==> $DEST requires elevated permissions; retrying with sudo"
  sudo cp -R "$APP_SRC" "$DEST"
fi

echo "==> Launching"
open "$DEST"

cat <<'EOF'

NoMacMusic installed.

First run may prompt for:
  - Accessibility       (System Settings > Privacy & Security > Accessibility)
  - Input Monitoring    (System Settings > Privacy & Security > Input Monitoring)

Both must be ON for media keys to be intercepted before Music.app launches.
EOF
