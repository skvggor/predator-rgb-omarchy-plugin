#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="skvggor.predator-rgb"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
HOOKS_DIR="$HOME/.config/omarchy/hooks/theme-set.d"
HOOK_TARGET="$HOOKS_DIR/omarchy-predator-rgb"
INSTALL_BIN="$SCRIPT_DIR/bin/omarchy-install-predator-rgb"
SYSFS_DIR="/sys/devices/platform/acer_rgb/four_zoned_kb"

REQUIRED_FILES=(manifest.json Model.js Service.qml Panel.qml theme-set)

echo "=== predator-rgb installer ==="
echo ""

# --- Pre-flight: kernel headers (auto-install if missing) ---
echo "[1/4] Checking kernel headers..."
if ! "$INSTALL_BIN" --check; then
  echo "Kernel headers not found. Installing linux-headers..."
  if command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm linux-headers
  else
    echo "ERROR: Cannot auto-install kernel headers. Please install linux-headers manually." >&2
    exit 1
  fi
  echo "[1/4] Kernel headers installed"
else
  echo "[1/4] Kernel headers OK"
fi

# --- Install kernel module (needs root, uses polkit popup) ---
echo ""
echo "[2/4] Installing kernel module..."
"$INSTALL_BIN" --install
echo "[2/4] Kernel module installed"

# --- User-space: copy plugin files ---
echo ""
echo "[3/4] Installing plugin..."

for file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
    echo "ERROR: Required file missing: $file" >&2
    exit 1
  fi
done

mkdir -p "$PLUGIN_DIR"
cp "${REQUIRED_FILES[@]}" "$PLUGIN_DIR/"
chmod +x "$PLUGIN_DIR/theme-set"
echo "[3/4] Plugin copied to $PLUGIN_DIR"

# --- Enable plugin ---
echo ""
echo "[4/4] Enabling plugin..."

mkdir -p "$HOOKS_DIR"
if [[ -L "$HOOK_TARGET" || -e "$HOOK_TARGET" ]]; then
  rm -f "$HOOK_TARGET"
fi
ln -sf "$PLUGIN_DIR/theme-set" "$HOOK_TARGET"

omarchy-shell shell rescanPlugins 2>/dev/null || true
omarchy plugin enable "$PLUGIN_ID" 2>/dev/null || true
echo "[4/4] Hook installed and plugin enabled"

# --- Apply current theme ---
echo ""
if [[ -d "$SYSFS_DIR" && -w "$SYSFS_DIR/per_zone_mode" ]]; then
  "$PLUGIN_DIR/theme-set"
  echo "Applied current theme to keyboard + back logo"
else
  echo "Sysfs not writable yet. Log out/in (or reboot) for group changes, then theme will apply automatically."
fi

echo ""
echo "=== Done ==="
echo "Keyboard backlight now follows the active Omarchy theme."
echo "To uninstall: $SCRIPT_DIR/uninstall.sh"
