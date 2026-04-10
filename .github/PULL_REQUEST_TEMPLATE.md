<!--
Thanks for contributing to Buddy Evolver!

This repo uses a local-first testing model: macOS-dependent tests run on
YOUR machine, and the results are uploaded to GitHub as a Check Run. Only
cheap Ubuntu checks run in GitHub Actions automatically.
-->

## Summary

<!-- What does this PR change? 1-3 bullets. -->

-

## Why

<!-- The motivation. If this fixes a bug, link the issue. -->

## Testing checklist

Before requesting review, run the full local suite on macOS:

- [ ] `scripts/test-all.sh` — all 5 tiers pass (unit / security / integration / functional / UI)
- [ ] `scripts/upload-test-results.sh` — Check Run appears on this PR's head commit
- [ ] If touching UI: `scripts/test-visual-smoke.sh` — visual checks pass, screenshot attached below

<!-- Attach visual-smoke screenshot here if applicable -->

## Scope checklist

- [ ] No changes to byte-length invariants without updating tests
- [ ] Any new user-facing input is validated in `Validation.swift`
- [ ] New skills / agents / hooks are referenced in `CLAUDE.md` (or run `/sync-docs`)
- [ ] No `.build/` or `test-results/` committed
- [ ] Commit messages describe the "why", not just the "what"

## Risk

<!-- Does this change affect patching, backup/restore, or codesign? Flag here. -->

-
