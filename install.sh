#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="skvggor.predator-rgb"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
HOOKS_DIR="$HOME/.config/omarchy/hooks/theme-set.d"
HOOK_TARGET="$HOOKS_DIR/omarchy-predator-rgb"

REQUIRED_FILES="manifest.json Model.js Service.qml Panel.qml theme-set"

echo "=== predator-rgb-omarchy-plugin installer ==="

for file in $REQUIRED_FILES; do
  if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
    echo "ERROR: Required file missing: $file" >&2
    exit 1
  fi
done

mkdir -p "$PLUGIN_DIR"
cp $REQUIRED_FILES "$PLUGIN_DIR/"
chmod +x "$PLUGIN_DIR/theme-set"
echo "[1/4] Plugin copied to $PLUGIN_DIR"

mkdir -p "$HOOKS_DIR"
if [[ -L "$HOOK_TARGET" || -e "$HOOK_TARGET" ]]; then
  rm -f "$HOOK_TARGET"
fi
ln -sf "$PLUGIN_DIR/theme-set" "$HOOK_TARGET"
echo "[2/4] Hook installed -> $HOOK_TARGET"

if ! omarchy-shell shell rescanPlugins; then
  echo "WARNING: Failed to rescan plugins (non-fatal)" >&2
fi
if ! omarchy plugin enable "$PLUGIN_ID"; then
  echo "WARNING: Failed to enable plugin (non-fatal)" >&2
fi
echo "[3/4] Plugin enabled in the bar"

if [[ -w /dev/acer-gkbbl-static-0 && -w /dev/acer-gkbbl-0 ]]; then
  "$PLUGIN_DIR/theme-set"
  echo "[4/4] Applied current theme to the keyboard"
else
  echo "[4/4] Keyboard devices not present; the hook will apply when the acer-gkbbl module loads."
fi

echo ""
echo "=== Installation complete ==="
echo "The keyboard backlight now follows the active Omarchy theme."
echo ""
echo "NOTE: to keep the facer module loaded across reboots (recommended), run ONCE:"
echo "  sudo $SCRIPT_DIR/setup-kernel-module.sh"
echo "To remove, run: $SCRIPT_DIR/uninstall.sh"
