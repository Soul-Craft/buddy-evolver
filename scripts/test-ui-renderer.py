#!/usr/bin/env python3
"""
Buddy card renderer — reference implementation used by /buddy-status.

Reads fixture files (~/.claude.json and ~/.claude/backups/buddy-patch-meta.json)
and renders a visual card identical to what the skill produces via Claude.

Extracted into a standalone script so UI tests can pin exact output against
pinned fixtures. Tests invoke it with HOME pointed at a temp dir that contains
fixture files.

Usage:
    HOME=/path/to/fixture python3 test-ui-renderer.py
    HOME=/path/to/fixture python3 test-ui-renderer.py --json  # emit raw state

Exit codes:
    0 — rendered successfully (any state: evolved, wild, missing)
    1 — unexpected error
"""
import argparse
import datetime
import json
import os
import sys
import time

# ── Rarity flair map ─────────────────────────────────────────────────
RARITY_FLAIR = {
    "legendary": "\u2605 LEGENDARY",  # ★
    "epic":      "\u25C6 EPIC",        # ◆
    "rare":      "\u25CF RARE",        # ●
    "uncommon":  "\u25CB UNCOMMON",    # ○
    "common":    "\u00B7 COMMON",      # ·
}

STAT_NAMES = ["debugging", "patience", "chaos", "wisdom", "snark"]


def load_state():
    """Gather the same data the skill collects."""
    soul = {}
    try:
        with open(os.path.expanduser("~/.claude.json")) as f:
            soul = json.load(f).get("companion", {})
    except Exception:
        pass

    meta = {}
    try:
        with open(os.path.expanduser(
                "~/.claude/backups/buddy-patch-meta.json")) as f:
            meta = json.load(f)
    except Exception:
        pass

    hatched = soul.get("hatchedAt", 0)
    if hatched:
        age_ms = time.time() * 1000 - hatched
        age_days = int(age_ms / 86_400_000)
        age_hours = int((age_ms % 86_400_000) / 3_600_000)
        hatched_date = datetime.datetime.fromtimestamp(
            hatched / 1000).strftime("%b %d, %Y")
    else:
        age_days = 0
        age_hours = 0
        hatched_date = "Unknown"

    return {
        "soul": soul,
        "meta": meta,
        "age_days": age_days,
        "age_hours": age_hours,
        "hatched_date": hatched_date,
        "evolved": bool(meta),
    }


# ── Render helpers ───────────────────────────────────────────────────

def space_name(name: str) -> str:
    """Render 'Smaug' as 'S M A U G'. Single-char names stay unchanged."""
    if not name:
        return ""
    if len(name) == 1:
        return name.upper()
    return " ".join(name.upper())


def render_age(age_days: int, age_hours: int) -> str:
    if age_days == 0 and age_hours == 0:
        return "Just hatched!"
    if age_days == 0:
        return f"{age_hours} hours old"
    return f"{age_days} days old"


def render_stat_bar(value: int) -> str:
    """85 → '████████░░' (filled=8, empty=2)."""
    value = max(0, min(value, 99))
    filled = value // 10
    empty = 10 - filled
    return "\u2588" * filled + "\u2591" * empty


def rarity_flair(rarity: str, shiny: bool) -> str:
    flair = RARITY_FLAIR.get(rarity, rarity.upper())
    if shiny:
        flair = f"{flair} \u2728 SHINY"
    return flair


# ── Card renderers ───────────────────────────────────────────────────

def render_evolved(state: dict) -> str:
    soul = state["soul"]
    meta = state["meta"]
    name = soul.get("name", "Buddy")
    personality = soul.get("personality", "")
    emoji = meta.get("emoji", "")
    species = meta.get("species", "unknown")
    rarity = meta.get("rarity", "common")
    shiny = meta.get("shiny", False)
    version = meta.get("version", "?")
    stats = meta.get("stats")

    age = render_age(state["age_days"], state["age_hours"])
    flair = rarity_flair(rarity, shiny)

    lines = [
        "\u2554" + "\u2550" * 42 + "\u2557",
        f"\u2551  {emoji}  {space_name(name)}".ljust(43) + "\u2551",
        f"\u2551  {flair}".ljust(43) + "\u2551",
        "\u2560" + "\u2550" * 42 + "\u2563",
        "\u2551" + " " * 42 + "\u2551",
        f"\u2551  Species:      {species} {emoji}".ljust(43) + "\u2551",
        f"\u2551  Personality:  \"{personality}\"".ljust(43) + "\u2551",
        f"\u2551  Age:          {age}".ljust(43) + "\u2551",
        f"\u2551  Hatched:      {state['hatched_date']}".ljust(43) + "\u2551",
        f"\u2551  Evolution:    Evolved (v{version})".ljust(43) + "\u2551",
        "\u2551" + " " * 42 + "\u2551",
        "\u2560" + "\u2550" * 42 + "\u2563",
        "\u2551  S T A T S".ljust(43) + "\u2551",
        "\u2551" + " " * 42 + "\u2551",
    ]

    if stats:
        for stat in STAT_NAMES:
            value = stats.get(stat, 0)
            bar = render_stat_bar(value)
            label = stat.upper().ljust(9)
            lines.append(
                f"\u2551  {label} [{bar}]  {value}".ljust(43) + "\u2551")
    else:
        lines.extend([
            "\u2551  No stats assigned yet.".ljust(43) + "\u2551",
            "\u2551  Re-evolve with /buddy-evolve to set".ljust(43) + "\u2551",
            "\u2551  custom stats for your buddy.".ljust(43) + "\u2551",
        ])

    lines.extend([
        "\u2551" + " " * 42 + "\u2551",
        "\u2560" + "\u2550" * 42 + "\u2563",
        "\u2551  /buddy-evolve   Re-evolve your buddy".ljust(43) + "\u2551",
        "\u2551  /buddy-reset    Restore original buddy".ljust(43) + "\u2551",
        "\u255A" + "\u2550" * 42 + "\u255D",
    ])
    return "\n".join(lines)


def render_wild(state: dict) -> str:
    soul = state["soul"]
    name = soul.get("name", "Buddy")
    personality = soul.get("personality", "")
    age = render_age(state["age_days"], state["age_hours"])

    lines = [
        "\u2554" + "\u2550" * 42 + "\u2557",
        f"\u2551  \U0001F423  {space_name(name)}".ljust(43) + "\u2551",
        "\u2551  Wild Buddy \u2014 Not yet evolved".ljust(43) + "\u2551",
        "\u2560" + "\u2550" * 42 + "\u2563",
        "\u2551" + " " * 42 + "\u2551",
        f"\u2551  Personality:  \"{personality}\"".ljust(43) + "\u2551",
        f"\u2551  Age:          {age}".ljust(43) + "\u2551",
        f"\u2551  Hatched:      {state['hatched_date']}".ljust(43) + "\u2551",
        "\u2551" + " " * 42 + "\u2551",
        "\u2551  Your buddy hasn't evolved yet!".ljust(43) + "\u2551",
        "\u2551  Feed it a psychedelic mushroom \U0001F344".ljust(43) + "\u2551",
        "\u2551  to unlock species, stats, and more.".ljust(43) + "\u2551",
        "\u2551" + " " * 42 + "\u2551",
        "\u2560" + "\u2550" * 42 + "\u2563",
        "\u2551  /buddy-evolve   Start evolution \U0001F344".ljust(43) + "\u2551",
        "\u255A" + "\u2550" * 42 + "\u255D",
    ]
    return "\n".join(lines)


def render_missing() -> str:
    return (
        "No buddy found! Start Claude Code to hatch your companion,\n"
        "then run /buddy-evolve to customize it."
    )


def render_card(state: dict) -> str:
    if state["evolved"]:
        return render_evolved(state)
    if state["soul"]:
        return render_wild(state)
    return render_missing()


# ── CLI entry point ──────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Render a buddy status card.")
    parser.add_argument("--json", action="store_true",
                        help="Emit raw gathered state as JSON (no render)")
    args = parser.parse_args()

    try:
        state = load_state()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(state, indent=2, default=str))
        return 0

    print(render_card(state))
    return 0


if __name__ == "__main__":
    sys.exit(main())
