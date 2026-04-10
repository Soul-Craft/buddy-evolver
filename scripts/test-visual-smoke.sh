#!/bin/bash
# Visual smoke test — manual pre-release check.
#
# Runs the buddy-status renderer against a pinned fixture and displays the
# output to the tester for visual inspection. Walks through a checklist and
# captures a screenshot (via `screencapture`) for PR evidence.
#
# Run before each release. Not part of test-all.sh (interactive).
#
# Usage: scripts/test-visual-smoke.sh
#   Outputs to test-results/visual-smoke-<timestamp>.log
#   Screenshot saved to test-results/screenshots/visual-smoke-<timestamp>.png

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RENDERER="$SCRIPT_DIR/test-ui-renderer.py"
RESULTS_DIR="$REPO_ROOT/test-results"
SCREENSHOTS_DIR="$RESULTS_DIR/screenshots"
TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
LOG_FILE="$RESULTS_DIR/visual-smoke-$TIMESTAMP.log"
SCREENSHOT_FILE="$SCREENSHOTS_DIR/visual-smoke-$TIMESTAMP.png"

mkdir -p "$RESULTS_DIR" "$SCREENSHOTS_DIR"

# ── Check prerequisites ────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
    echo "  [!] ERROR: python3 not found" >&2
    exit 1
fi

# ── Build fixture ──────────────────────────────────────────────────
FIXTURE_HOME=$(mktemp -d "/tmp/buddy-visual-smoke-home.XXXXXX")
trap 'rm -rf "$FIXTURE_HOME"' EXIT

mkdir -p "$FIXTURE_HOME/.claude/backups"

# Recent-ish hatch — ~6 hours ago
HATCHED_MS=$(python3 -c "import time; print(int((time.time() - 6*3600) * 1000))")

cat > "$FIXTURE_HOME/.claude.json" <<EOF
{
  "companion": {
    "name": "Aethos",
    "personality": "a fiery friend who loves debugging",
    "hatchedAt": $HATCHED_MS
  }
}
EOF

cat > "$FIXTURE_HOME/.claude/backups/buddy-patch-meta.json" <<'EOF'
{
  "version": "2.1.90",
  "binary_path": "/tmp/buddy-test-binary/claude-test",
  "binary_sha256": "smoke-test-fixture",
  "species": "dragon",
  "rarity": "legendary",
  "shiny": true,
  "emoji": "🔥",
  "name": "Aethos",
  "personality": "a fiery friend who loves debugging",
  "stats": {
    "debugging": 85,
    "patience": 30,
    "chaos": 72,
    "wisdom": 90,
    "snark": 65
  }
}
EOF

# ── Render the card ────────────────────────────────────────────────
clear
echo
echo "  ╔════════════════════════════════════╗"
echo "  ║   Buddy Visual Smoke Test          ║"
echo "  ║   Fixture: Evolved legendary       ║"
echo "  ╚════════════════════════════════════╝"
echo
echo "  Rendered buddy card (from fixture):"
echo "  ────────────────────────────────────"
echo

OUTPUT=$(HOME="$FIXTURE_HOME" python3 "$RENDERER")
echo "$OUTPUT"

# Log the rendered card
{
    echo "Visual Smoke Test Run — $TIMESTAMP"
    echo "============================================"
    echo
    echo "$OUTPUT"
    echo
} > "$LOG_FILE"

echo
echo "  ────────────────────────────────────"
echo

# ── Capture a screenshot (best effort) ─────────────────────────────
if command -v screencapture &>/dev/null; then
    echo "  [~] Capturing terminal screenshot in 3 seconds..."
    echo "      Make sure this terminal window is visible!"
    sleep 3
    if screencapture -m "$SCREENSHOT_FILE" 2>/dev/null; then
        echo "  [+] Screenshot saved: $SCREENSHOT_FILE"
    else
        echo "  [!] Screenshot capture failed (skip, non-fatal)"
    fi
else
    echo "  [!] screencapture not available — skipping screenshot"
fi

# ── Interactive checklist ──────────────────────────────────────────
echo
echo "  Visual Checklist"
echo "  ════════════════"
echo

CHECKS=(
    "Buddy card appeared with correct emoji (🔥)"
    "Name 'A E T H O S' is displayed with letter spacing"
    "Rarity flair shows '★ LEGENDARY ✨ SHINY'"
    "Species line shows 'dragon 🔥'"
    "Personality text in quotes: 'a fiery friend who loves debugging'"
    "Age shows '6 hours old' (approximately)"
    "All 5 stat bars render proportionally"
    "DEBUGGING bar is 8 full blocks + 2 empty (85)"
    "WISDOM bar is 9 full blocks + 1 empty (90)"
    "Footer shows /buddy-evolve and /buddy-reset hints"
)

PASS=0
FAIL=0
FAILED_ITEMS=()

for item in "${CHECKS[@]}"; do
    printf "  [?] %s\n      Pass? [y/N] " "$item"
    read -r answer
    case "$answer" in
        y|Y|yes|YES)
            echo "      [PASS]"
            PASS=$((PASS + 1))
            echo "    [PASS] $item" >> "$LOG_FILE"
            ;;
        *)
            echo "      [FAIL]"
            FAIL=$((FAIL + 1))
            FAILED_ITEMS+=("$item")
            echo "    [FAIL] $item" >> "$LOG_FILE"
            ;;
    esac
done

echo
echo "  ════════════════"
echo "  Visual Smoke Results: $PASS passed, $FAIL failed"
echo

{
    echo
    echo "============================================"
    echo "Results: $PASS passed, $FAIL failed"
} >> "$LOG_FILE"

if [ "$FAIL" -gt 0 ]; then
    echo "  Failed items:"
    for item in "${FAILED_ITEMS[@]}"; do
        echo "    - $item"
    done
    echo
    echo "  Log: $LOG_FILE"
    exit 1
fi

echo "  All visual checks passed."
echo "  Log: $LOG_FILE"
if [ -f "$SCREENSHOT_FILE" ]; then
    echo "  Screenshot: $SCREENSHOT_FILE"
fi
exit 0
