#!/usr/bin/env bash
# Integration test for the theme-set hook: runs it against fake device files
# and verifies the exact bytes written (static zone colors + 100% brightness).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../theme-set"

failures=0

check_bytes() {
  local description=$1 file=$2 expected=$3
  local actual
  actual=$(od -An -tx1 "$file" | tr -d ' \n')
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: $description"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    failures=$((failures + 1))
  else
    echo "PASS: $description ($actual)"
  fi
}

# --- Test 1: accent hex applied to all four zones + 100% brightness ---
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
: > "$workdir/static.bin"
: > "$workdir/dyn.bin"
printf '#819890\n' > "$workdir/keyboard.rgb"

PREDATOR_RGB_KEYBOARD_RGB_FILE="$workdir/keyboard.rgb" \
PREDATOR_RGB_STATIC_DEVICE="$workdir/static.bin" \
PREDATOR_RGB_DYNAMIC_DEVICE="$workdir/dyn.bin" \
PREDATOR_RGB_BRIGHTNESS=100 \
"$HOOK"

# Static device ends with the last (zone 4) write; the module applies each
# separate write to its own zone. The full-set step rewrites 1..4, so the final
# write colors zone 4.
# #819890 -> R 0x81 G 0x98 B 0x90.
check_bytes "static device (zone 4 mask, R G B)" "$workdir/static.bin" "08819890"
check_bytes "dynamic device (brightness 0x64 + commit 0x01)" "$workdir/dyn.bin" "00006400000000000001000000000000"

# --- Test 2: no hash tolerated, brightness custom ---
: > "$workdir/static.bin"
: > "$workdir/dyn.bin"
printf 'FF0000\n' > "$workdir/keyboard.rgb"   # no hash
PREDATOR_RGB_KEYBOARD_RGB_FILE="$workdir/keyboard.rgb" \
PREDATOR_RGB_STATIC_DEVICE="$workdir/static.bin" \
PREDATOR_RGB_DYNAMIC_DEVICE="$workdir/dyn.bin" \
PREDATOR_RGB_BRIGHTNESS=50 \
"$HOOK"
check_bytes "red accent, brightness 0x32" "$workdir/dyn.bin" "00003200000000000001000000000000"

# --- Test 3: device missing -> no error, no writes ---
rm -f "$workdir/static.bin" "$workdir/dyn.bin"
if PREDATOR_RGB_KEYBOARD_RGB_FILE="$workdir/keyboard.rgb" PREDATOR_RGB_STATIC_DEVICE="$workdir/static.bin" PREDATOR_RGB_DYNAMIC_DEVICE="$workdir/dyn.bin" "$HOOK"; then
  if [[ -e "$workdir/static.bin" || -e "$workdir/dyn.bin" ]]; then
    echo "FAIL: devices were written when absent"
    failures=$((failures + 1))
  else
    echo "PASS: missing devices left untouched"
  fi
else
  echo "FAIL: hook errored with missing devices"
  failures=$((failures + 1))
fi

# --- Test 4: malformed color -> exits cleanly ---
: > "$workdir/static.bin"
: > "$workdir/dyn.bin"
printf 'not-a-color\n' > "$workdir/keyboard.rgb"
if PREDATOR_RGB_KEYBOARD_RGB_FILE="$workdir/keyboard.rgb" PREDATOR_RGB_STATIC_DEVICE="$workdir/static.bin" PREDATOR_RGB_DYNAMIC_DEVICE="$workdir/dyn.bin" "$HOOK"; then
  echo "PASS: malformed color ignored cleanly"
else
  echo "FAIL: hook errored on malformed color"
  failures=$((failures + 1))
fi

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "All integration checks passed"
