#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="skvggor.predator-rgb"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
HOOK_TARGET="$HOME/.config/omarchy/hooks/theme-set.d/omarchy-predator-rgb"

echo "=== predator-rgb-omarchy-plugin uninstaller ==="

if [[ -L "$HOOK_TARGET" || -e "$HOOK_TARGET" ]]; then
  rm -f "$HOOK_TARGET"
  echo "[1/3] Removed hook"
else
  echo "[1/3] Hook not present"
fi

if [[ ${1:-} == "--purge" && -d "$PLUGIN_DIR" ]]; then
  rm -rf "$PLUGIN_DIR"
  echo "[2/3] Removed plugin files"
else
  echo "[2/3] Plugin files left at $PLUGIN_DIR (use --purge to remove)"
fi

omarchy plugin disable "$PLUGIN_ID" || true
omarchy-shell shell rescanPlugins || true
echo "[3/3] Plugin disabled in the bar"

echo ""
echo "=== Uninstall complete ==="
echo "(Optional) If you ran setup-kernel-module.sh, undo it with:"
echo "  sudo $SCRIPT_DIR/setup-kernel-module.sh --undo"
