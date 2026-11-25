# Security Policy

## Security Model

Buddy Evolver writes a name and a personality to `~/.claude.json` and card metadata to
`~/.claude/backups/`. Since version 2.0.0 it no longer touches the Claude Code binary.
The project keeps defense-in-depth across three layers: Swift input validation, atomic
writes with a one-time backup, and plugin-level argument interception. See the
[Security](docs/ARCHITECTURE.md#security) section of docs/ARCHITECTURE.md for the full
architecture.

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 2.0.x   | ✅ Yes     |
| 1.x     | ❌ No, upgrade to 2.0.0 |

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Use [GitHub Security Advisories](https://github.com/Soul-Craft/buddy-evolver/security/advisories/new)
to report privately. We aim to acknowledge reports within 72 hours.

Include:
- Description of the vulnerability
- Steps to reproduce
- Affected versions
- Potential impact

## Security-Sensitive Files

These files have outsized security impact, so reports here are especially welcome:

| File | Role |
|------|------|
| `scripts/BuddyPatcher/Sources/BuddyPatcherLib/Validation.swift` | All user-input validation |
| `scripts/BuddyPatcher/Sources/BuddyPatcherLib/BackupRestore.swift` | Backup integrity, SHA-256 verification |
| `scripts/BuddyPatcher/Sources/BuddyPatcherLib/PatchEngine.swift` | Binary modification |
| `hooks/guard-patcher-args.sh` | Shell injection prevention |
| `scripts/test-security.sh` | Security test suite |

## Security Design Principles

Contributors should maintain these invariants:

- All user inputs are validated in `Validation.swift` **before** any write operation
- All `Data.write()` calls use `.atomic` (backed by `rename(2)`), so a crash leaves no partial write
- Backup integrity is verified by SHA-256 hash before any restore
- Codesign failure after patching triggers automatic restore and `exit(1)`
- Zero third-party Swift dependencies, only Foundation and CryptoKit

## No Bug Bounty

There is no formal bug bounty program. Responsibly disclosed vulnerabilities will
be credited in release notes.
