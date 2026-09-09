#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="skvggor.predator-rgb"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
HOOK_TARGET="$HOME/.config/omarchy/hooks/theme-set.d/omarchy-predator-rgb"
MODULE_DIR="$SCRIPT_DIR/kernel-module"
SYSFS_DIR="/sys/devices/platform/acer_rgb/four_zoned_kb"

echo "=== predator-rgb full reset ==="
echo "This will remove everything installed by this plugin."
echo ""

if [[ ${1:-} != "--yes" ]]; then
  read -r -p "Continue? [y/N] " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
  fi
fi

echo "[1/7] Unloading kernel module..."
modprobe -r acer_rgb 2>/dev/null || true

echo "[2/7] Removing boot config and udev rules..."
rm -f /etc/modules-load.d/acer_rgb.conf
rm -f /etc/udev/rules.d/90-acer-rgb.rules
rm -f /usr/libexec/acer-rgb-set-perms
udevadm control --reload-rules 2>/dev/null || true

echo "[3/7] Removing module files..."
if [[ -d "$MODULE_DIR" ]]; then
  cd "$MODULE_DIR"
  make uninstall 2>/dev/null || true
  cd "$SCRIPT_DIR"
fi
depmod -a 2>/dev/null || true

echo "[4/7] Removing acer_rgb group (if exists)..."
if getent group acer_rgb >/dev/null 2>&1; then
  # Remove any users from the group first, then delete it
  sudo gpasswd -d "$USER" acer_rgb 2>/dev/null || true
  sudo groupdel acer_rgb 2>/dev/null || true
fi

echo "[5/7] Removing hook..."
rm -f "$HOOK_TARGET"

echo "[6/7] Removing plugin files..."
rm -rf "$PLUGIN_DIR"

echo "[7/7] Disabling plugin in bar..."
omarchy plugin disable "$PLUGIN_ID" 2>/dev/null || true
omarchy-shell shell rescanPlugins 2>/dev/null || true

echo ""
echo "=== Reset complete ==="
echo "Everything removed. To reinstall:"
echo "  $SCRIPT_DIR/install.sh"
echo "  or: $SCRIPT_DIR/bin/omarchy-install-predator-rgb --install"
