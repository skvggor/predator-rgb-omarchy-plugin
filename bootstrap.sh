#!/usr/bin/env bash
set -euo pipefail

REPO="skvggor/predator-rgb-omarchy-plugin"
API_URL="https://api.github.com/repos/skvggor/predator-rgb-omarchy-plugin/releases/latest"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CURL_OPTS=(--fail --location --retry 3 --retry-delay 2
  --connect-timeout 10 --max-time 60 --max-filesize 10485760
  --silent --show-error)

echo "=== predator-rgb bootstrap ==="
echo ""
echo "This script downloads and verifies the latest release."
echo "After verification, it will ask for your password to install."
echo ""

VERSION="$(curl "${CURL_OPTS[@]}" "$API_URL" | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -1)"
if [[ -z "$VERSION" ]]; then
  echo "ERROR: could not determine latest release" >&2
  exit 1
fi

ARCHIVE_NAME="predator-rgb-$VERSION"
URL="https://github.com/$REPO/releases/download/v$VERSION/$ARCHIVE_NAME.tar.gz"

echo "Downloading $ARCHIVE_NAME from $URL"
curl "${CURL_OPTS[@]}" -o "$TMP_DIR/$ARCHIVE_NAME.tar.gz" "$URL"
curl "${CURL_OPTS[@]}" -o "$TMP_DIR/$ARCHIVE_NAME.tar.gz.sha256" "$URL.sha256"

# Verify archive checksum as published by the release
if ! (cd "$TMP_DIR" && sha256sum -c "$ARCHIVE_NAME.tar.gz.sha256" >/dev/null 2>&1); then
  echo "ERROR: checksum verification failed for $ARCHIVE_NAME" >&2
  exit 1
fi

echo "Checksum verified OK"

tar xzf "$TMP_DIR/$ARCHIVE_NAME.tar.gz" -C "$TMP_DIR"

echo ""
echo "Download and verification complete."
echo "Running installer..."
echo ""

exec "$TMP_DIR/$ARCHIVE_NAME/install.sh"