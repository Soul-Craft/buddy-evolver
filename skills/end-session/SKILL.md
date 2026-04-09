---
name: end-session
description: Use when ending a dev session on Buddy Evolver. Use when the user says "end session", "wrap up", "done for now", "finish up", "session done", or "close out".
---

# End Session — Automated Dev Wrap-Up

Detect what changed during the session and automatically run the appropriate checks. No manual steps — just run everything and report.

## Step 1: Detect what changed

```bash
echo "=== Unstaged Changes ==="
git diff --name-only 2>/dev/null
echo "=== Staged Changes ==="
git diff --cached --name-only 2>/dev/null
echo "=== Untracked Files ==="
git ls-files --others --exclude-standard 2>/dev/null
```

Categorize all changed files into these groups (a file can match multiple):
- **swift_changed**: any path matching `scripts/BuddyPatcher/Sources/**` or `scripts/BuddyPatcher/Tests/**`
- **skills_changed**: any path matching `skills/**`
- **hooks_changed**: any path matching `hooks/**`
- **config_changed**: any path matching `.claude/settings.json`, `CLAUDE.md`, `.claude-plugin/**`
- **agents_changed**: any path matching `agents/**` or `.claude-plugin/agents/**`

Note which groups have changes — these determine which checks run below.

## Step 2: Run checks (automatic, based on changes)

Run ALL applicable checks. Do not ask the user — just run them.

### 2a. Swift tests (if swift_changed)

Run the full test suite:

```bash
cd "${CLAUDE_PLUGIN_ROOT}/scripts/BuddyPatcher" && swift test 2>&1
```

Parse the output for pass/fail counts and time elapsed. Note any failures with test names and assertion messages.

### 2b. Security review (if swift_changed)

Invoke the `security-reviewer` agent on the changed Swift files. Provide it with the specific files that changed and ask it to check for:
- Missing input validation
- Byte-length invariant violations
- Non-atomic writes
- Unsafe process execution

### 2c. Token review (if skills_changed OR config_changed OR agents_changed)

Run a quick token inventory (Phase 1 only — no full audit):

```bash
cd "${CLAUDE_PLUGIN_ROOT}"
echo "=== Always Loaded ==="
for f in CLAUDE.md .claude-plugin/plugin.json .claude-plugin/marketplace.json .claude/settings.json; do
  if [ -f "$f" ]; then
    chars=$(wc -c < "$f" | tr -d ' ')
    tokens=$((chars / 4))
    printf "  %-45s ~%s tokens\n" "$f" "$tokens"
  fi
done
echo "=== Modified Skills ==="
for f in skills/*/SKILL.md; do
  if [ -f "$f" ]; then
    chars=$(wc -c < "$f" | tr -d ' ')
    tokens=$((chars / 4))
    printf "  %-45s ~%s tokens\n" "$f" "$tokens"
  fi
done
```

Flag any single file over ~1500 tokens or if always-loaded total exceeds ~3000 tokens. Suggest `/token-review --apply` if there are optimization opportunities.

### 2d. Compatibility check (if swift_changed AND patcher is compiled)

```bash
PATCHER="${CLAUDE_PLUGIN_ROOT}/scripts/BuddyPatcher/.build/release/buddy-patcher"
if [ -f "$PATCHER" ]; then
  "${CLAUDE_PLUGIN_ROOT}/scripts/run-buddy-patcher.sh" \
    --dry-run --species dragon --rarity legendary --shiny \
    --emoji "🐲" --name "Test" --personality "Test" 2>&1
fi
```

Check for `[DRY RUN]` (good) and `[!] WARNING` (bad) lines.

### 2e. Cache cleanup (always)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/cache-clean.sh" --verbose
```

## Step 3: Report results

Present a single summary table with all results:

```
Session Wrap-Up Report
══════════════════════

Changes detected:
  Swift code:    [yes/no] ([N] files)
  Skills:        [yes/no] ([N] files)
  Hooks:         [yes/no] ([N] files)
  Config:        [yes/no] ([N] files)
  Agents:        [yes/no] ([N] files)

Checks run:
  Tests:         [94 passed ✅ / N failed ❌ / skipped (no Swift changes)]
  Security:      [clean ✅ / N findings ⚠️ / skipped]
  Tokens:        [within budget ✅ / over budget ⚠️ / skipped]
  Compatibility: [all match ✅ / warnings ⚠️ / skipped]
  Cache cleanup: [N items freed / nothing to clean]

Git status:
  Uncommitted:   [N files — consider committing]
  Branch:        [branch name]
```

If any check has warnings or failures, list the specific issues below the summary table.

If there are uncommitted changes, remind the user they can commit with `/commit` or manually.

## Step 4: Handle no changes

If no files were changed during the session, still run cache cleanup and show a brief report:

```
Session Wrap-Up Report
══════════════════════

No changes detected this session.

Cache cleanup: [result]
Branch: [branch] — clean
```
