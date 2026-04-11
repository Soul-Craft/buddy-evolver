---
name: buddy-evolve
description: This skill should be used when the user asks to "buddy evolve", "evolve buddy", "change my buddy", "customize buddy", "I want a different buddy", "change buddy species", or "make my buddy shiny".
argument-hint: "species name (optional)"
---

# Buddy Evolve — Transform Your Terminal Pet

Transform the user's Claude Code Buddy terminal pet through an interactive evolution experience.

**The default path is 2 picks:** choose an Evolution Pack, optionally name it, and watch the animation. Power users can pick **"🎨 Build My Own"** to customize every detail.

**Pack data lives in `references/evolution-packs.md`** — read that file once when you start so you have the 8 packs and their defaults loaded.

---

## Act 1 — Discovery

Run pre-flight checks **silently** — capture output, don't echo it:

```bash
BINARY=$(readlink ~/.local/bin/claude 2>/dev/null)
CURRENT_NAME=$(plutil -extract companion.name raw -o - ~/.claude.json 2>/dev/null || echo "your buddy")
CURRENT_SPECIES=$(plutil -extract companion.species raw -o - ~/.claude.json 2>/dev/null || echo "unknown")
if [ -z "$BINARY" ] || [ ! -f "$BINARY" ]; then
  echo "ERROR: Claude Code binary not found at ~/.local/bin/claude"
  exit 1
fi
```

Then display the discovery scene using the ASCII art matching the **current** species. Pick from the templates below and substitute `[NAME]` with `$CURRENT_NAME`.

**Species ASCII Art (use the one matching the current species):**

axolotl:
```
        (      )
    }~(______)~{
    }~(× .. ×)~{     🍄 ?
      ( .--. )
       (_/  \_)
```

duck:
```
    .---.
    (°>°)       🍄 ?
   /(   )\
    `---´
```

cat:
```
   /\_/\
  ( o.o )      🍄 ?
   > ^ <
  /|   |\
```

dragon:
```
    /\___/\
   ( ◉ ω ◉ )   🍄 ?
   /|     |\~
  (_|     |_)
```

capybara:
```
   .-~~~~-.
  /  o  o  \    🍄 ?
 |    __    |
  \  (__)  /
   '------'
```

For any other species, use a simple emoji representation:
```
      [emoji]     🍄 ?
```

Display the scene:
```
🍄 A WILD MUSHROOM APPEARED!

[species ASCII art from above]

[NAME] sniffs the mushroom curiously...
Something magical is about to happen! ✨
```

---

## Act 2 — Pick a Pack

**One AskUserQuestion, ten options.** This is the primary path — most users never go beyond here.

Use AskUserQuestion:
- header: "Evolution Pack"
- question: "Who should [NAME] become?"
- options (in this order):
  1. label: "🐉 Golden Dragon", description: "Rare & radiant"
  2. label: "🌈 Rainbow Axolotl", description: "Happy & silly"
  3. label: "👻 Spooky Ghost", description: "Mysterious & mischievous"
  4. label: "🦫 Chill Capybara", description: "Zen master vibes"
  5. label: "🐙 Smart Octopus", description: "Galaxy brain"
  6. label: "🤖 Cool Robot", description: "Logical & snarky"
  7. label: "🦉 Wise Owl", description: "Knows everything"
  8. label: "🐱 Sneaky Cat", description: "Clever & chaotic"
  9. label: "🎲 Surprise Me!", description: "Pick a random pack"
  10. label: "🎨 Build My Own", description: "Custom evolution (advanced)"

(AskUserQuestion supports up to ~10 options cleanly; if rendering caps at 4 visible, the "Other" fallback lets the user type any pack name.)

### Pack data

Read `references/evolution-packs.md` for the full pack table. Each pack bundles:
- **species** (for `--species`)
- **emoji** (for `--emoji`)
- **default name** (for `--name`, user can override)
- **personality** (for `--personality`)
- **stats preset** + JSON (for `--stats`)

All packs use `--rarity legendary` and `--shiny`.

### Handling the picks

**If a preset pack (options 1–8):** use its bundle as the base, then ask ONE follow-up:

```
Great pick! What should we call your new [species]?
(Press Enter to use "[default_name]")
```

- If the user sends an empty reply, "default", "that's fine", or similar → use the pack's default name
- Otherwise → use their input as the name

**If "🎲 Surprise Me!":** pick a random pack from options 1–8, skip the name question, use the pack's default name. Mention which pack fate chose: "🎲 The dice rolled... **Golden Dragon!** 🐉"

**If "🎨 Build My Own":** jump to the [Build My Own (Advanced)](#build-my-own-advanced) section below.

---

## Act 3 — The Evolution

### Frame 1 — Bite (emit as one message, then `sleep 0.8`)

```
[NAME] takes a big bite of the mushroom... 🍄

[current species ASCII art]

*crunch crunch*
```

Then run:
```bash
sleep 0.8
```

### Frame 2 — Glow (emit as one message)

```
WHOA! [NAME] is starting to glow! ✨

[current species ASCII art with ✨ sparkles added around it]
```

Now run the patcher. The patcher takes ~1–2s to run, which acts as the "big pause" in the animation:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/run-buddy-patcher.sh" \
  --species [species] \
  --rarity legendary \
  --shiny \
  --emoji "[emoji]" \
  --name "[name]" \
  --personality "[personality]" \
  --stats '[stats_json]'
```

All evolved buddies are shiny by default (always pass `--shiny`).

### Frame 3 — Burst (emit as one message, then `sleep 0.8`)

```
     ✨ ✨ ✨ ✨ ✨
   ✨             ✨
  ✨    POOF!     ✨
   ✨             ✨
     ✨ ✨ ✨ ✨ ✨
```

Then run:
```bash
sleep 0.8
```

### Frame 4 — Ta-da! (emit as one message, lead into the reveal)

```
     ✨ TA-DA! ✨

          [new_emoji]
         [NEW_NAME]
```

Do not sleep after Frame 4 — proceed straight to Act 4.

---

## Act 4 — The Reveal

Display the evolved buddy card:

```
    ✨✨✨✨✨✨✨✨✨✨
    ✨                ✨
    ✨    [emoji]     ✨
    ✨                ✨
    ✨✨✨✨✨✨✨✨✨✨

[OLD_NAME] evolved into [NEW_NAME]! 🎉

★ LEGENDARY          [SPECIES]

  [NEW_NAME]
  "[personality]"

  DEBUGGING  ████████████  [n]
  PATIENCE   ████████████  [n]
  CHAOS      ████████████  [n]
  WISDOM     ████████████  [n]
  SNARK      ████████████  [n]
```

Then tell the user (kid-friendly copy, no 🚨 or ⚠️):

```
🎉 Your new buddy is ready!

To meet [NEW_NAME], restart Claude Code:
   exit
   claude

Then run /buddy-status to say hi!

Want your old buddy back? Run /buddy-reset
```

---

## Build My Own (Advanced)

For users who picked "🎨 Build My Own" in Act 2. Four questions instead of six — still customizable, but trims the blank-page prompts that made the old flow painful.

### Step 1: Species
AskUserQuestion:
- header: "Species"
- question: "What species?"
- options:
  - "dragon" — "Fearsome fire-breather"
  - "cat" — "Mysterious and independent"
  - "axolotl" — "Regenerating amphibian"
  - "capybara" — "Chill vibes only"

If the user picks "Other", list all 18: duck, goose, blob, cat, dragon, octopus, owl, penguin, turtle, snail, axolotl, ghost, robot, mushroom, cactus, rabbit, chonk, capybara.

### Step 2: Rarity
AskUserQuestion:
- header: "Rarity"
- question: "What rarity tier?"
- options:
  - "legendary" — "The rarest of the rare (Recommended)"
  - "epic" — "Extremely rare"
  - "rare" — "Uncommon but special"
  - "common" — "Keep it humble"

### Step 3: Name
Freeform: `What's their name? (Press Enter for "[smart_default]")`

**Smart default by species** (from the pack roster where applicable):
- dragon → Aurelius
- axolotl → Sparkle
- ghost → Boo
- capybara → Mellow
- octopus → Tako
- robot → Bleep
- owl → Sage
- cat → Whiskers
- duck → Ducky
- goose → Honk
- blob → Blobby
- penguin → Tux
- turtle → Shelly
- snail → Slurp
- mushroom → Shroomie
- cactus → Spike
- rabbit → Hop
- chonk → Chonk

Accept empty reply, "default", or "that's fine" as "use the smart default."

### Step 4: Vibe
AskUserQuestion:
- header: "Vibe"
- question: "What's their vibe?"
- options:
  - "Powerful hero" — "Brave & unstoppable (all stats 99)"
  - "Chaos goblin" — "Pure mayhem (99 chaos, low rest)"
  - "Wise elder" — "Has seen it all (99 wisdom + patience)"
  - "Sassy sidekick" — "Always has a comeback (99 snark)"

**Vibe → personality + stats mapping:**

| Vibe | Personality | Stats JSON |
|------|-------------|------------|
| Powerful hero | Brave, bold, and unstoppable | `{"debugging":99,"patience":99,"chaos":99,"wisdom":99,"snark":99}` |
| Chaos goblin | Causes adorable mayhem wherever they go | `{"debugging":20,"patience":20,"chaos":99,"wisdom":20,"snark":60}` |
| Wise elder | Has seen it all, knows more than they say | `{"debugging":60,"patience":99,"chaos":10,"wisdom":99,"snark":40}` |
| Sassy sidekick | Always has a comeback ready | `{"debugging":60,"patience":20,"chaos":99,"wisdom":50,"snark":80}` |

If the user picks "Other" / wants to write their own:
- Ask in conversation: "Describe their personality in a sentence or two."
- Default to `{"debugging":99,"patience":99,"chaos":99,"wisdom":99,"snark":99}` for stats (all maxed).

### Emoji auto-pick

Emoji is auto-derived from the species using the pack-roster mapping:

| Species | Emoji | | Species | Emoji |
|---------|-------|---|---------|-------|
| dragon | 🐉 | | duck | 🦆 |
| axolotl | 🌈 | | goose | 🪿 |
| ghost | 👻 | | blob | 🫠 |
| capybara | 🦫 | | penguin | 🐧 |
| octopus | 🐙 | | turtle | 🐢 |
| robot | 🤖 | | snail | 🐌 |
| owl | 🦉 | | mushroom | 🍄 |
| cat | 🐱 | | cactus | 🌵 |
| | | | rabbit | 🐇 |
| | | | chonk | 🐖 |

Use these without asking. If the user wants a different emoji, they can say so and you override.

### Then continue to Act 3

Once you have species + rarity + name + personality + stats + emoji, run the same Act 3 animation and Act 4 reveal as the pack flow.

---

## Error Handling

If the patcher fails:
- Display the error output
- Suggest running `/buddy-reset` to revert
- Note that binary offsets are version-specific — if Claude Code just updated, run `/test-patch` to check compatibility
