#!/bin/bash
# UI test suite for buddy-status card rendering.
#
# Runs test-ui-renderer.py against pinned fixtures in isolated HOME dirs
# and asserts that the output contains expected patterns.
#
# Groups:
#   1. Data gathering       — renderer handles evolved/wild/missing states
#   2. Card rendering       — box chars, stat bars, rarity flair
#   3. Rarity flair mapping — one per tier
#   4. Age display          — Just hatched / N hours / N days
#   5. Name spacing         — multi-char vs single-char

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RENDERER="$SCRIPT_DIR/test-ui-renderer.py"
PASS=0
FAIL=0
FAILED_TESTS=()

# ── Helpers ────────────────────────────────────────────────────────

# Create an isolated HOME with fixture files. Sets $TEST_HOME.
# Usage: fixture_setup <soul_json> <meta_json>
# Pass empty string to skip creating either file.
fixture_setup() {
    local soul_json="$1"
    local meta_json="$2"
    TEST_HOME=$(mktemp -d "/tmp/buddy-ui-home.XXXXXX")
    mkdir -p "$TEST_HOME/.claude/backups"
    if [ -n "$soul_json" ]; then
        echo "$soul_json" > "$TEST_HOME/.claude.json"
    fi
    if [ -n "$meta_json" ]; then
        echo "$meta_json" > "$TEST_HOME/.claude/backups/buddy-patch-meta.json"
    fi
}

fixture_teardown() {
    rm -rf "$TEST_HOME"
}

render() {
    HOME="$TEST_HOME" python3 "$RENDERER"
}

render_json() {
    HOME="$TEST_HOME" python3 "$RENDERER" --json
}

assert_contains() {
    local description="$1"
    local pattern="$2"
    local output="$3"
    if printf '%s' "$output" | grep -q -F -- "$pattern"; then
        echo "  [PASS] $description"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $description"
        echo "         expected to find: $pattern"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("$description")
    fi
}

assert_not_contains() {
    local description="$1"
    local pattern="$2"
    local output="$3"
    if printf '%s' "$output" | grep -q -F -- "$pattern"; then
        echo "  [FAIL] $description"
        echo "         expected NOT to find: $pattern"
        FAIL=$((FAIL + 1))
        FAILED_TESTS+=("$description")
    else
        echo "  [PASS] $description"
        PASS=$((PASS + 1))
    fi
}

# ── Fixtures ────────────────────────────────────────────────────────

# Recent hatch for "days old" test: 3 days ago in milliseconds
THREE_DAYS_AGO_MS=$(python3 -c "import time; print(int((time.time() - 3*86400) * 1000))")
TEN_HOURS_AGO_MS=$(python3 -c "import time; print(int((time.time() - 10*3600) * 1000))")
JUST_HATCHED_MS=$(python3 -c "import time; print(int(time.time() * 1000))")

EVOLVED_SOUL='{"companion":{"name":"Smaug","personality":"grumpy but loyal","hatchedAt":'$THREE_DAYS_AGO_MS'}}'
EVOLVED_META='{"version":"2.1.90","binary_path":"/tmp/fake","species":"dragon","rarity":"legendary","shiny":true,"emoji":"🐉","stats":{"debugging":85,"patience":20,"chaos":99,"wisdom":70,"snark":55}}'

WILD_SOUL='{"companion":{"name":"Newt","personality":"shy and curious","hatchedAt":'$TEN_HOURS_AGO_MS'}}'

echo
echo "  UI Test Suite"
echo "  ═════════════"
echo

# ────────────────────────────────────────────────────────────────────
# Group 1: Data gathering
# ────────────────────────────────────────────────────────────────────
echo "  --- Group 1: Data Gathering ---"

# Test 1.1: Evolved state recognized
fixture_setup "$EVOLVED_SOUL" "$EVOLVED_META"
STATE=$(render_json)
assert_contains "Evolved state: 'evolved' flag is true" '"evolved": true' "$STATE"
fixture_teardown

# Test 1.2: Wild state (soul but no meta)
fixture_setup "$WILD_SOUL" ""
STATE=$(render_json)
assert_contains "Wild state: 'evolved' flag is false" '"evolved": false' "$STATE"
fixture_teardown

# Test 1.3: Missing state (no files)
fixture_setup "" ""
STATE=$(render_json)
assert_contains "Missing state: empty soul dict" '"soul": {}' "$STATE"
fixture_teardown

echo

# ────────────────────────────────────────────────────────────────────
# Group 2: Card rendering
# ────────────────────────────────────────────────────────────────────
echo "  --- Group 2: Card Rendering ---"

# Test 2.1: Evolved card has box-drawing characters
fixture_setup "$EVOLVED_SOUL" "$EVOLVED_META"
OUTPUT=$(render)
assert_contains "Evolved card has top-left box corner" "╔" "$OUTPUT"

# Test 2.2: Rarity flair appears
assert_contains "Legendary flair star appears" "★ LEGENDARY" "$OUTPUT"

# Test 2.3: Stat bars contain filled + empty blocks
assert_contains "Stat bar: full block char present" "█" "$OUTPUT"
assert_contains "Stat bar: empty block char present" "░" "$OUTPUT"

# Test 2.4: Specific stat bar for debugging=85 is 8 filled + 2 empty
assert_contains "debugging=85 renders as 8 filled + 2 empty blocks" "████████░░" "$OUTPUT"

# Test 2.5: Shiny flair appears when shiny=true
assert_contains "Shiny sparkle appears when shiny=true" "✨ SHINY" "$OUTPUT"

fixture_teardown

# Test 2.6: Wild card has mushroom prompt
fixture_setup "$WILD_SOUL" ""
OUTPUT=$(render)
assert_contains "Wild card prompts to feed mushroom" "psychedelic mushroom" "$OUTPUT"
fixture_teardown

# Test 2.7: Missing card shows hatch prompt
fixture_setup "" ""
OUTPUT=$(render)
assert_contains "Missing card shows hatch instruction" "Start Claude Code to hatch" "$OUTPUT"
fixture_teardown

echo

# ────────────────────────────────────────────────────────────────────
# Group 3: Rarity flair mapping
# ────────────────────────────────────────────────────────────────────
echo "  --- Group 3: Rarity Flair Mapping ---"

# Helper to build a meta JSON for a specific rarity
build_meta() {
    local rarity="$1"
    printf '{"version":"1","binary_path":"/tmp/x","species":"cat","rarity":"%s","shiny":false,"emoji":"🐱"}' "$rarity"
}

for RARITY_PAIR in "legendary:★ LEGENDARY" "epic:◆ EPIC" "rare:● RARE" "uncommon:○ UNCOMMON" "common:· COMMON"; do
    RARITY="${RARITY_PAIR%%:*}"
    EXPECTED="${RARITY_PAIR##*:}"
    fixture_setup "$EVOLVED_SOUL" "$(build_meta "$RARITY")"
    OUTPUT=$(render)
    assert_contains "Rarity flair: $RARITY renders as '$EXPECTED'" "$EXPECTED" "$OUTPUT"
    fixture_teardown
done

echo

# ────────────────────────────────────────────────────────────────────
# Group 4: Age display
# ────────────────────────────────────────────────────────────────────
echo "  --- Group 4: Age Display ---"

# Test 4.1: Just hatched (< 1 hour)
SOUL_JUST='{"companion":{"name":"Egg","personality":"new","hatchedAt":'$JUST_HATCHED_MS'}}'
fixture_setup "$SOUL_JUST" ""
OUTPUT=$(render)
assert_contains "Age display: 'Just hatched!' for < 1 hour" "Just hatched!" "$OUTPUT"
fixture_teardown

# Test 4.2: Hours old (< 1 day)
SOUL_HOURS='{"companion":{"name":"Tiny","personality":"new","hatchedAt":'$TEN_HOURS_AGO_MS'}}'
fixture_setup "$SOUL_HOURS" ""
OUTPUT=$(render)
assert_contains "Age display: '10 hours old' for 10h-old buddy" "10 hours old" "$OUTPUT"
fixture_teardown

# Test 4.3: Days old (1+ days)
SOUL_DAYS='{"companion":{"name":"Old","personality":"wise","hatchedAt":'$THREE_DAYS_AGO_MS'}}'
fixture_setup "$SOUL_DAYS" ""
OUTPUT=$(render)
assert_contains "Age display: '3 days old' for 3-day-old buddy" "3 days old" "$OUTPUT"
fixture_teardown

echo

# ────────────────────────────────────────────────────────────────────
# Group 5: Name spacing + fallback states
# ────────────────────────────────────────────────────────────────────
echo "  --- Group 5: Name Spacing & Fallbacks ---"

# Test 5.1: Multi-char name is spaced out
fixture_setup "$EVOLVED_SOUL" "$EVOLVED_META"
OUTPUT=$(render)
assert_contains "Name spacing: 'Smaug' → 'S M A U G'" "S M A U G" "$OUTPUT"
fixture_teardown

# Test 5.2: Single-char name stays unchanged
SINGLE='{"companion":{"name":"X","personality":"mysterious","hatchedAt":'$JUST_HATCHED_MS'}}'
fixture_setup "$SINGLE" "$(build_meta common)"
OUTPUT=$(render)
# Single char should appear as "X" (uppercase) without extra spacing
assert_contains "Single-char name renders as 'X'" "X" "$OUTPUT"
# Should NOT contain spaced multi-char variant
assert_not_contains "Single-char name not spaced" "X X" "$OUTPUT"
fixture_teardown

# Test 5.3: Missing stats falls back to message
META_NO_STATS='{"version":"1","binary_path":"/tmp/x","species":"cat","rarity":"epic","shiny":false,"emoji":"🐱"}'
fixture_setup "$EVOLVED_SOUL" "$META_NO_STATS"
OUTPUT=$(render)
assert_contains "Missing stats shows fallback message" "No stats assigned yet" "$OUTPUT"
fixture_teardown

echo
echo "  ═════════════"
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
