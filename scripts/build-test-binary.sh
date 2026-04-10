#!/bin/bash
# Build a synthetic Mach-O test binary for integration/functional/UI tests.
#
# The test binary embeds all patchable patterns (species array, rarity weights,
# shiny threshold, and art blocks) as runtime-accessed string constants. This
# way the Swift optimizer can't elide them and the patcher can find them via
# its anchor patterns.
#
# The binary accepts `--version` (required by verifyBinary() post-patch) and
# prints the test version to stdout.
#
# Usage: build-test-binary.sh [output-path]
#   default output: /tmp/buddy-test-binary/claude-test

set -euo pipefail

OUTPUT="${1:-/tmp/buddy-test-binary/claude-test}"
OUTPUT_DIR="$(dirname "$OUTPUT")"
SRC_DIR="/tmp/buddy-test-binary-src-$$"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$SRC_DIR"

# Cleanup source dir on exit
trap 'rm -rf "$SRC_DIR"' EXIT

# ── Write the Swift source ─────────────────────────────────────────
# All patchable patterns live in the @main struct so Swift can't elide them.
# The species array uses the v2.1.90+ variable map (knownVarMaps[0]).
# Art blocks for duck and goose are sized large enough to survive patching.
cat > "$SRC_DIR/main.swift" <<'SWIFT_SOURCE'
import Foundation

// ── Patchable Patterns (must be findable in binary via anchors) ─────

// Species array. Anchor = "GL_,ZL_,LL_,kL_,". Must match knownVarMaps[0].
let SPECIES_ARRAY = "[GL_,ZL_,LL_,kL_,vL_,hL_,yL_,NL_,VL_,SL_,CL_,EL_,xL_,mL_,IL_,uL_,pL_,bL_]"

// Rarity weights string — exact format the patcher expects.
let RARITY_WEIGHTS = "common:60,uncommon:25,rare:10,epic:4,legendary:1"

// Shiny threshold — exactly as it appears in the real binary.
let SHINY_THRESHOLD = "H()<0.01"

// Art block. Built as ONE contiguous string so boundary markers like
// `],[ZL_]:` land inside a single binary string literal. Swift puts each
// string literal in its own cstring slot, so split strings won't produce
// a findable boundary.
//
// Structure mimics the real binary:
//   {[GL_]:[[ ...duck art... ],[ZL_]:[[ ...goose art... ],[LL_]:[[ ... ]}
//
// Padding ensures patchArt() has room to write its new emoji block.
let ART_BLOCK = "{[GL_]:[[\"         \",\"         \",\"  ^___^  \",\"         \",\"         \",\"         \",\"         \",\"  ^___^  \",\"         \",\"         \",\"         \",\"         \",\"  ^___^  \",\"         \",\"                                                                              \"],[ZL_]:[[\"         \",\"         \",\"   >o<   \",\"         \",\"         \",\"         \",\"         \",\"   >o<   \",\"         \",\"         \",\"         \",\"         \",\"   >o<   \",\"         \",\"                                                                              \"],[LL_]:[[\"         \",\"         \",\"  (o_o)  \",\"         \",\"         \",\"         \",\"         \",\"  (o_o)  \",\"         \",\"         \",\"         \",\"         \",\"  (o_o)  \",\"         \",\"                                                                              \"],[kL_]:[[\"         \",\"         \",\"  =^.^=  \",\"         \",\"         \",\"         \",\"         \",\"  =^.^=  \",\"         \",\"         \",\"         \",\"         \",\"  =^.^=  \",\"         \",\"                                                                              \"]}"

// ── CLI handling ────────────────────────────────────────────────────

// Force strings into the binary by running logic that depends on them.
// Release-mode Swift will keep strings used in runtime branches.
@main
struct TestBinary {
    static func main() {
        let args = CommandLine.arguments

        // Touch every pattern so the optimizer can't elide them.
        var marker = 0
        marker &+= SPECIES_ARRAY.count
        marker &+= RARITY_WEIGHTS.count
        marker &+= SHINY_THRESHOLD.count
        marker &+= ART_BLOCK.count

        if args.contains("--version") {
            print("test-binary 1.0.0 (marker=\(marker))")
            exit(0)
        }

        if args.contains("--help") {
            print("Test binary for buddy-patcher integration tests.")
            print("Usage: claude-test [--version|--help|--dump-patterns]")
            exit(0)
        }

        if args.contains("--dump-patterns") {
            // Used by tests to confirm the strings are actually in the binary
            print(SPECIES_ARRAY)
            print(RARITY_WEIGHTS)
            print(SHINY_THRESHOLD)
            print(ART_BLOCK)
            exit(0)
        }

        // No-op default
        print("test-binary: no command (marker=\(marker))")
        exit(0)
    }
}
SWIFT_SOURCE

# ── Compile ────────────────────────────────────────────────────────
# -O for release optimization (closer to real Claude binary).
# -parse-as-library so @main works in a single file.
swiftc -O -parse-as-library -o "$OUTPUT" "$SRC_DIR/main.swift"

# Ad-hoc sign so the binary runs (same as real Claude binary).
codesign --force --sign - "$OUTPUT" 2>/dev/null || true

# ── Verify ────────────────────────────────────────────────────────
if ! "$OUTPUT" --version >/dev/null 2>&1; then
    echo "  [!] ERROR: Test binary failed --version check" >&2
    exit 1
fi

# Sanity check: all required patterns should be findable in the binary.
REQUIRED_PATTERNS=(
    "GL_,ZL_,LL_,kL_,"
    "common:60,uncommon:25,rare:10,epic:4,legendary:1"
    "H()<0.01"
    "[GL_]:[["
    "],[ZL_]:"
)
for pat in "${REQUIRED_PATTERNS[@]}"; do
    if ! grep -a -q -F "$pat" "$OUTPUT"; then
        echo "  [!] ERROR: Pattern not found in test binary: $pat" >&2
        exit 1
    fi
done

echo "  [+] Built test binary: $OUTPUT ($(wc -c < "$OUTPUT" | tr -d ' ') bytes)"
