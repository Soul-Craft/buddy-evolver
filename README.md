# 🍄 Buddy Customizer

Evolve your Claude Code Buddy terminal pet into your dream companion.

Feed your buddy a psychedelic mushroom and watch it transform — choose any species, rarity, custom emoji, name, personality, and stats.

## Installation

```
claude plugin add github:Soul-Craft/Buddy
```

Restart Claude Code after installing.

## Usage

### Customize your buddy
```
/customize-buddy
```
Launches an interactive evolution ceremony:
1. Your current buddy discovers a mysterious 🍄 mushroom
2. You choose species, rarity, emoji, name, personality, and stats
3. Your buddy evolves with a sparkle animation
4. Restart Claude Code and run `/buddy` to see your new companion

### Restore original buddy
```
/restore-buddy
```
Reverts all changes and restores your original buddy.

## Available Species

duck, goose, blob, cat, dragon, octopus, owl, penguin, turtle, snail, axolotl, ghost, robot, mushroom, cactus, rabbit, chonk, capybara

## Rarity Tiers

| Tier | Reaction Rate | Description |
|------|--------------|-------------|
| common | 5% | Your buddy rarely speaks up |
| uncommon | 15% | Occasional commentary |
| rare | 25% | Regular reactions |
| epic | 35% | Frequent companion chatter |
| legendary | 50% | Reacts to half of everything you do |

## How It Works

The plugin patches the Claude Code Mach-O binary to customize your buddy:
- Species array variable references (3-byte swaps in the Bun bytecode)
- Rarity probability weights (digit replacement)
- Shiny threshold (guarantees shiny for evolved buddies)
- ASCII art templates (replaced with custom emoji)
- Companion soul in `~/.claude.json` (name, personality)

All patches maintain exact byte length. The binary is re-signed with an ad-hoc codesign after patching. Your original binary is backed up automatically and can be restored at any time with `/restore-buddy`.

## Caveats

- **macOS only** (requires `codesign`)
- **Auto-updates reset patches** — Claude Code updates replace the binary. Run `/customize-buddy` again after updates (your preferences are saved and can be re-applied)
- **Version-specific** — The script uses pattern matching for portability, but major Claude Code refactors may require script updates

## Uninstall

```
claude plugin remove buddy-customizer
```

## License

[MIT](LICENSE)
