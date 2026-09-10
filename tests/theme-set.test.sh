#!/usr/bin/env bash
# Integration test for the theme-set hook: runs it against fake acer_rgb sysfs
# and verifies the exact format written (per_zone_mode: RRGGBB,RRGGBB,RRGGBB,RRGGBB,100)
# and (back_logo: RRGGBB,100,enable).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../theme-set"

failures=0

check_content() {
  local description=$1 file=$2 expected=$3
  local actual
  actual=$(cat "$file" 2>/dev/null || echo "")
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: $description"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    failures=$((failures + 1))
  else
    echo "PASS: $description ($actual)"
  fi
}

# --- Test 1: accent hex applied to all four zones at 100% brightness ---
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

# Create fake acer_rgb sysfs structure
mkdir -p "$workdir/sys/devices/platform/acer_rgb/four_zoned_kb"
touch "$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/per_zone_mode"
touch "$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/back_logo"

printf '#819890\n' > "$workdir/keyboard.rgb"

PREDATOR_RGB_KEYBOARD_RGB_FILE="$workdir/keyboard.rgb" \
ACER_RGB_SYSFS="$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/per_zone_mode" \
BACK_LOGO_SYSFS="$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/back_logo" \
PREDATOR_RGB_BACK_LOGO=true \
"$HOOK"

check_content "all zones set to #819890 at 100% brightness" \
  "$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/per_zone_mode" \
  "819890,819890,819890,819890,100"

check_content "back logo set to #819890 at 100% brightness enabled" \
  "$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/back_logo" \
  "819890,100,1"

# --- Test 2: no hash tolerated ---
: > "$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/per_zone_mode"
: > "$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/back_logo"
printf 'FF0000\n' > "$workdir/keyboard.rgb"
PREDATOR_RGB_KEYBOARD_RGB_FILE="$workdir/keyboard.rgb" \
ACER_RGB_SYSFS="$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/per_zone_mode" \
BACK_LOGO_SYSFS="$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/back_logo" \
PREDATOR_RGB_BACK_LOGO=true \
"$HOOK"
check_content "red accent at 100% brightness" \
  "$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/per_zone_mode" \
  "FF0000,FF0000,FF0000,FF0000,100"
check_content "back logo red at 100% brightness enabled" \
  "$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/back_logo" \
  "FF0000,100,1"

# --- Test 3: back logo always enabled ---
: > "$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/per_zone_mode"
: > "$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/back_logo"
printf '00FF00\n' > "$workdir/keyboard.rgb"
PREDATOR_RGB_KEYBOARD_RGB_FILE="$workdir/keyboard.rgb" \
ACER_RGB_SYSFS="$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/per_zone_mode" \
BACK_LOGO_SYSFS="$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/back_logo" \
"$HOOK"
check_content "green accent at 100% brightness" \
  "$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/per_zone_mode" \
  "00FF00,00FF00,00FF00,00FF00,100"
check_content "back logo always enabled" \
  "$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/back_logo" \
  "00FF00,100,1"

# --- Test 4: sysfs missing -> no error, no writes ---
rm -rf "$workdir/sys"
if PREDATOR_RGB_KEYBOARD_RGB_FILE="$workdir/keyboard.rgb" \
   ACER_RGB_SYSFS="$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/per_zone_mode" \
   BACK_LOGO_SYSFS="$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/back_logo" \
   "$HOOK"; then
  if [[ -e "$workdir/sys" ]]; then
    echo "FAIL: sysfs was created when absent"
    failures=$((failures + 1))
  else
    echo "PASS: missing sysfs left untouched"
  fi
else
  echo "FAIL: hook errored with missing sysfs"
  failures=$((failures + 1))
fi

# --- Test 5: malformed color -> exits cleanly ---
mkdir -p "$workdir/sys/devices/platform/acer_rgb/four_zoned_kb"
: > "$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/per_zone_mode"
: > "$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/back_logo"
printf 'not-a-color\n' > "$workdir/keyboard.rgb"
if PREDATOR_RGB_KEYBOARD_RGB_FILE="$workdir/keyboard.rgb" \
   ACER_RGB_SYSFS="$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/per_zone_mode" \
   BACK_LOGO_SYSFS="$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/back_logo" \
   "$HOOK"; then
  echo "PASS: malformed color ignored cleanly"
else
  echo "FAIL: hook errored on malformed color"
  failures=$((failures + 1))
fi

# --- Test 6: back logo always enabled regardless of env ---
: > "$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/per_zone_mode"
: > "$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/back_logo"
printf '0000FF\n' > "$workdir/keyboard.rgb"
PREDATOR_RGB_KEYBOARD_RGB_FILE="$workdir/keyboard.rgb" \
ACER_RGB_SYSFS="$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/per_zone_mode" \
BACK_LOGO_SYSFS="$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/back_logo" \
"$HOOK" >/dev/null 2>&1 || true
check_content "back logo always enabled" \
  "$workdir/sys/devices/platform/acer_rgb/four_zoned_kb/back_logo" \
  "0000FF,100,1"

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "All integration checks passed"
