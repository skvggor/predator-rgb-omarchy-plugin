#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="skvggor.predator-rgb"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
HOOK_TARGET="$HOME/.config/omarchy/hooks/theme-set.d/omarchy-predator-rgb"
INSTALL_BIN="$SCRIPT_DIR/bin/omarchy-install-predator-rgb"

echo "=== predator-rgb uninstaller ==="

# --- Remove kernel module (needs root) ---
echo ""
echo "[1/4] Removing kernel module..."
"$INSTALL_BIN" --uninstall
echo "[1/4] Kernel module removed"

# --- Remove hook ---
echo ""
if [[ -L "$HOOK_TARGET" || -e "$HOOK_TARGET" ]]; then
  rm -f "$HOOK_TARGET"
  echo "[2/4] Removed hook"
else
  echo "[2/4] Hook not present"
fi

# --- Remove plugin files ---
if [[ ${1:-} == "--purge" && -d "$PLUGIN_DIR" ]]; then
  rm -rf "$PLUGIN_DIR"
  echo "[3/4] Removed plugin files"
else
  echo "[3/4] Plugin files left at $PLUGIN_DIR (use --purge to remove)"
fi

# --- Disable plugin ---
omarchy plugin disable "$PLUGIN_ID" 2>/dev/null || true
omarchy-shell shell rescanPlugins 2>/dev/null || true
echo "[4/4] Plugin disabled"

echo ""
echo "=== Done ==="
