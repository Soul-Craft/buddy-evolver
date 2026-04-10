#!/bin/bash
# Functional test suite for buddy-patcher.
#
# Verifies the patched binary is correct at the byte and format level:
#   - Patches landed where expected (grep for expected bytes)
#   - Original patterns are gone
#   - Mach-O structure is still valid
#   - Binary still runs (--version exits 0)
#   - Codesign passes
#   - Metadata JSON is well-formed and matches reality
#
# Groups:
#   1. Mach-O validity
#   2. Patch data verification
#   3. Backup integrity
#   4. Codesign validity
#   5. Metadata JSON
#   6. Re-patch correctness

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$SCRIPT_DIR/BuddyPatcher/.build/release/buddy-patcher"
BUILD_TEST_BINARY="$SCRIPT_DIR/build-test-binary.sh"
PASS=0
FAIL=0
FAILED_TESTS=()

# ── Helpers ────────────────────────────────────────────────────────

assert_pass() {
    local description="$1"
    local result="$2"
    if [ "$result" -eq 0 ]; then
        echo "  [PASS] $description"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $description"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("$description")
    fi
}

# Search the binary for a literal byte pattern (grep -a handles binary as text).
binary_contains() {
    grep -a -q -F "$1" "$2"
}

# Build if needed
if [ ! -f "$BIN" ]; then
    echo "  Building buddy-patcher (release)..."
    swift build -c release --package-path "$SCRIPT_DIR/BuddyPatcher" 2>&1 | tail -3
fi

echo
echo "  Functional Test Suite"
echo "  ═════════════════════"
echo

# Set up: one shared patched binary for most tests
TEST_HOME=$(mktemp -d "/tmp/buddy-functional-home.XXXXXX")
TEST_BIN_DIR=$(mktemp -d "/tmp/buddy-functional-bin.XXXXXX")
TEST_BINARY="$TEST_BIN_DIR/claude-test"
TEST_BACKUP_DIR="$TEST_HOME/.claude/backups"

"$BUILD_TEST_BINARY" "$TEST_BINARY" >/dev/null 2>&1

# Apply a full-patch evolution for the group of tests that share patched state
BUDDY_HOME="$TEST_HOME" "$BIN" --binary "$TEST_BINARY" \
    --species cat --rarity legendary --shiny --emoji "🔥" >/dev/null 2>&1

cleanup() {
    rm -rf "$TEST_HOME" "$TEST_BIN_DIR"
}
trap cleanup EXIT

# ────────────────────────────────────────────────────────────────────
# Group 1: Mach-O validity
# ────────────────────────────────────────────────────────────────────
echo "  --- Group 1: Mach-O Validity ---"

# Test 1.1: `file` reports Mach-O
file "$TEST_BINARY" | grep -q "Mach-O"
assert_pass "Patched binary is reported as Mach-O by file(1)" $?

# Test 1.2: Patched binary runs --version and exits 0
"$TEST_BINARY" --version >/dev/null 2>&1
assert_pass "Patched binary --version exits 0" $?

echo

# ────────────────────────────────────────────────────────────────────
# Group 2: Patch data verification
# ────────────────────────────────────────────────────────────────────
echo "  --- Group 2: Patch Data Verification ---"

# Test 2.1: Cat variable (kL_) is present (species patch landed)
binary_contains "kL_" "$TEST_BINARY"
assert_pass "Target species variable (kL_) present in patched binary" $?

# Test 2.2: Legendary rarity weight is set to 1 — others zeroed
binary_contains "common:00,uncommon:00,rare:00,epic:0,legendary:1" "$TEST_BINARY"
assert_pass "Legendary rarity weights pattern present" $?

# Test 2.3: Shiny threshold changed to H()<1.01
binary_contains "H()<1.01" "$TEST_BINARY"
assert_pass "Shiny threshold set to H()<1.01" $?

# Test 2.4: Original rarity pattern is gone
if binary_contains "common:60,uncommon:25" "$TEST_BINARY"; then
    assert_pass "Original rarity pattern removed after patch" 1
else
    assert_pass "Original rarity pattern removed after patch" 0
fi

# Test 2.5: Original shiny threshold is gone
if binary_contains "H()<0.01" "$TEST_BINARY"; then
    assert_pass "Original shiny threshold removed after patch" 1
else
    assert_pass "Original shiny threshold removed after patch" 0
fi

echo

# ────────────────────────────────────────────────────────────────────
# Group 3: Backup integrity
# ────────────────────────────────────────────────────────────────────
echo "  --- Group 3: Backup Integrity ---"

# Test 3.1: Backup SHA-256 matches stored hash
STORED_HASH=$(tr -d '[:space:]' < "$TEST_BACKUP_DIR/binary-sha256.txt")
BACKUP_HASH=$(shasum -a 256 "$TEST_BINARY.original-backup" | awk '{print $1}')
[ "$STORED_HASH" = "$BACKUP_HASH" ]
assert_pass "Backup SHA-256 matches stored hash" $?

# Test 3.2: Backup is a valid Mach-O
file "$TEST_BINARY.original-backup" | grep -q "Mach-O"
assert_pass "Backup file is a valid Mach-O binary" $?

# Test 3.3: Backup differs from patched (bytes actually changed)
if [ "$BACKUP_HASH" = "$(shasum -a 256 "$TEST_BINARY" | awk '{print $1}')" ]; then
    assert_pass "Patched binary differs from backup" 1
else
    assert_pass "Patched binary differs from backup" 0
fi

# Test 3.4: Backup still has original rarity pattern
binary_contains "common:60,uncommon:25,rare:10" "$TEST_BINARY.original-backup"
assert_pass "Backup still contains original rarity pattern" $?

echo

# ────────────────────────────────────────────────────────────────────
# Group 4: Codesign validity
# ────────────────────────────────────────────────────────────────────
echo "  --- Group 4: Codesign Validity ---"

# Test 4.1: Patched binary passes codesign verification
codesign -v "$TEST_BINARY" 2>&1
assert_pass "Patched binary passes codesign -v" $?

# Test 4.2: Backup file is still ad-hoc signed (test binary build step signs it)
codesign -v "$TEST_BINARY.original-backup" 2>&1
assert_pass "Backup binary passes codesign -v" $?

# Test 4.3: Restore a new copy, verify restored binary passes codesign
TEST_BIN_DIR2=$(mktemp -d "/tmp/buddy-functional-bin2.XXXXXX")
TEST_BINARY2="$TEST_BIN_DIR2/claude-test"
"$BUILD_TEST_BINARY" "$TEST_BINARY2" >/dev/null 2>&1
TEST_HOME2=$(mktemp -d "/tmp/buddy-functional-home2.XXXXXX")
BUDDY_HOME="$TEST_HOME2" "$BIN" --binary "$TEST_BINARY2" --species dragon >/dev/null 2>&1
BUDDY_HOME="$TEST_HOME2" "$BIN" --binary "$TEST_BINARY2" --restore >/dev/null 2>&1
codesign -v "$TEST_BINARY2" 2>&1
assert_pass "Restored binary passes codesign -v" $?
rm -rf "$TEST_BIN_DIR2" "$TEST_HOME2"

echo

# ────────────────────────────────────────────────────────────────────
# Group 5: Metadata JSON
# ────────────────────────────────────────────────────────────────────
echo "  --- Group 5: Metadata JSON ---"

META_FILE="$TEST_BACKUP_DIR/buddy-patch-meta.json"

# Test 5.1: Metadata file is valid JSON
python3 -c "import json; json.load(open('$META_FILE'))" 2>/dev/null
assert_pass "Metadata file is valid JSON" $?

# Test 5.2: Metadata has required fields
python3 -c "
import json, sys
meta = json.load(open('$META_FILE'))
required = ['version', 'binary_path', 'binary_sha256', 'species', 'rarity', 'shiny', 'emoji']
missing = [k for k in required if k not in meta]
sys.exit(1 if missing else 0)
"
assert_pass "Metadata has all required fields" $?

# Test 5.3: Metadata species field matches CLI arg
SPECIES=$(python3 -c "import json; print(json.load(open('$META_FILE'))['species'])")
[ "$SPECIES" = "cat" ]
assert_pass "Metadata species field matches --species cat" $?

echo

# ────────────────────────────────────────────────────────────────────
# Group 6: Re-patch correctness
# ────────────────────────────────────────────────────────────────────
echo "  --- Group 6: Re-Patch Correctness ---"

# Test 6.1: File size unchanged from original
ORIG_SIZE=$(wc -c < "$TEST_BINARY.original-backup" | tr -d ' ')
PATCHED_SIZE=$(wc -c < "$TEST_BINARY" | tr -d ' ')
[ "$ORIG_SIZE" = "$PATCHED_SIZE" ]
assert_pass "Patched binary size matches original (byte invariant)" $?

# Test 6.2: Restore via fresh cycle + re-patch to a different rarity
TEST_BIN_DIR3=$(mktemp -d "/tmp/buddy-functional-bin3.XXXXXX")
TEST_BINARY3="$TEST_BIN_DIR3/claude-test"
TEST_HOME3=$(mktemp -d "/tmp/buddy-functional-home3.XXXXXX")
"$BUILD_TEST_BINARY" "$TEST_BINARY3" >/dev/null 2>&1
BUDDY_HOME="$TEST_HOME3" "$BIN" --binary "$TEST_BINARY3" --rarity common >/dev/null 2>&1
# patchRarity() preserves digit-count per weight: 60→01, 25→00, 10→00, 4→0, 1→0
binary_contains "common:01,uncommon:00,rare:00,epic:0,legendary:0" "$TEST_BINARY3"
assert_pass "Re-patched rarity has correct weight pattern (digit-count preserved)" $?
rm -rf "$TEST_BIN_DIR3" "$TEST_HOME3"

echo
echo "  ═════════════════════"
echo "  Results: $PASS passed, $FAIL failed"
echo
if [ "$FAIL" -gt 0 ]; then
    echo "  Failed tests:"
    for t in "${FAILED_TESTS[@]}"; do
        echo "    - $t"
    done
    exit 1
fi
exit 0
