#!/usr/bin/env bash
# omarchy:summary=Keep the facer (acer-gkbbl) kernel module loaded across reboots for the Predator RGB keyboard
#
# One-time root setup for the acer-gkbbl module. The stock acer_wmi driver
# claims the same WMI GUID as facer and, when auto-loaded after boot, unbinds
# the device and stops the keyboard RGB from working. This writes a blacklist
# so facer stays the sole driver.
#
# Run once with sudo (reversible with --undo):
#   sudo ./setup-kernel-module.sh
#   sudo ./setup-kernel-module.sh --undo   # remove the blacklist again

set -euo pipefail

BLACKLIST_FILE="/etc/modprobe.d/acer-predator-rgb.conf"
FACER_MODULE="${FACER_MODULE:-/opt/turbo-fan/src/facer.ko}"

if [[ ${UID:-$(id -u)} -ne 0 ]]; then
  echo "This command must be run as root: sudo $0" >&2
  exit 1
fi

if [[ ${1:-} == "--undo" ]]; then
  if [[ -f "$BLACKLIST_FILE" ]]; then
    rm -f "$BLACKLIST_FILE"
    echo "Removed $BLACKLIST_FILE"
    echo "The stock acer_wmi driver will be restored on the next reboot."
  else
    echo "No blacklist present; nothing to undo."
  fi
  exit 0
fi

echo "=== predator-rgb kernel module setup ==="

if lsmod | grep -q '^facer '; then
  echo "[1/2] facer already loaded"
else
  echo "[1/2] Loading facer..."
  rmmod acer_wmi 2>/dev/null || true
  modprobe wmi sparse-keymap video 2>/dev/null || true
  if [[ -f "$FACER_MODULE" ]]; then
    insmod "$FACER_MODULE"
    echo "[1/2] facer loaded from $FACER_MODULE"
  else
    echo "[1/2] WARNING: $FACER_MODULE not found; install the facer module first." >&2
  fi
fi

if [[ -f "$BLACKLIST_FILE" ]]; then
  echo "[2/2] blacklist already present"
else
  cat > "$BLACKLIST_FILE" <<'EOF'
# Blacklist the stock acer_wmi driver so it cannot steal the WMI GUID from
# facer (which the acer-gkbbl RGB nodes depend on).
# Created by predator-rgb-omarchy-plugin; removed with: sudo setup-kernel-module.sh --undo
blacklist acer_wmi
EOF
  echo "[2/2] blacklist written to $BLACKLIST_FILE"
fi

echo ""
echo "=== Setup complete ==="
echo "The facer module will now survive reboots (driver conflict with acer_wmi is avoided)."
echo "To undo, run: sudo $0 --undo"
