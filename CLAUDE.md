@AGENTS.md

## Claude Code only

| Topic | Rule |
| --- | --- |
| Reviews | Load the `merging` skill before reviewing or merging a pull request |
| Session skills | `/session-start`, `/session-execute`, `/session-review`, `/session-deploy`, `/session-exit` walk a change from plan to release. They coordinate and spawn no agents of their own |
| Hooks | `hooks/hooks.json` guards patcher arguments, reminds about tests and docs on `git commit`, and cleans worktrees on exit. Cloud threads do not load hooks, so the same rules sit in `AGENTS.md` and CI |
| Architecture | The artifact lists, data flow, security layers, test tiers and Swift layout are in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Read the section you need, not the whole file |
| Platform | macOS and the Xcode Command Line Tools. Tests isolate the home folder with `BUDDY_HOME` (see `Paths.swift`) |
| Security | Validate every new input in `Validation.swift`, write with `.atomic`, add a `[DRY RUN]` branch, then run `scripts/test-security.sh`. Layers: [Security](docs/ARCHITECTURE.md#security) |

## Where things live

| Part | Path |
| --- | --- |
| Plugin manifest | `.claude-plugin/` |
| Skills and agents | `skills/`, `agents/`, `.claude-plugin/agents/` |
| Hooks | `hooks/` |
| Swift patcher and tests | `scripts/BuddyPatcher/` |
| Test and release scripts | `scripts/` |
| Quality, Speed and Consumption page | `quality/` |
| Process map | `quality/process/config.json` |
