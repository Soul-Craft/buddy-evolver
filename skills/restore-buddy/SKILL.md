---
name: restore-buddy
description: This skill should be used when the user asks to "restore buddy", "restore-buddy", "revert buddy", "undo buddy changes", "get my original buddy back", or "reset my terminal pet".
---

# Restore Buddy — Revert to Original

Restore the user's original Claude Code Buddy by reverting all binary patches and companion data.

## Steps

### 1. Check for backups

```bash
BINARY=$(readlink ~/.local/bin/claude 2>/dev/null || echo "NOT_FOUND")
BACKUP="${BINARY}.original-backup"
echo "Binary: $BINARY"
echo "Backup exists: $(test -f "$BACKUP" && echo 'yes' || echo 'no')"
echo "Soul backup exists: $(test -f ~/.claude/backups/.claude.json.pre-customize && echo 'yes' || echo 'no')"
```

If no backups exist, tell the user there is nothing to restore and exit.

### 2. Show current vs original

Read and display the current companion data from `~/.claude.json` so the user knows what they're reverting from.

### 3. Confirm with user

Ask: "This will restore your original buddy and revert all customizations. Continue?"

### 4. Execute restore

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/patch-buddy.py" --restore
```

### 5. Instruct user

Tell the user to restart Claude Code:
```
Your original buddy has been restored!

⚠️  Restart Claude Code to see your original buddy:
   pkill -f claude && claude
   Then run /buddy

To re-customize anytime: /customize-buddy
```
