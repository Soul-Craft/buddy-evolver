# Species Variable Map — Binary Reference

## Species → Minified Variable Names

These 18 species have ASCII art templates in the binary. Each uses a 3-character minified variable name.

| Species | Variable | String.fromCharCode |
|---------|----------|-------------------|
| duck | `GL_` | `c2(100,117,99,107)` |
| goose | `ZL_` | `c2(103,111,111,115,101)` |
| blob | `LL_` | `c2(98,108,111,98)` |
| cat | `kL_` | `c2(99,97,116)` |
| dragon | `vL_` | `c2(100,114,97,103,111,110)` |
| octopus | `hL_` | `c2(111,99,116,111,112,117,115)` |
| owl | `yL_` | `c2(111,119,108)` |
| penguin | `NL_` | `c2(112,101,110,103,117,105,110)` |
| turtle | `VL_` | `c2(116,117,114,116,108,101)` |
| snail | `SL_` | `c2(115,110,97,105,108)` |
| ghost | `EL_` | `c2(103,104,111,115,116)` |
| axolotl | `CL_` | `c2(97,120,111,108,111,116,108)` |
| capybara | `bL_` | `c2(99,97,112,121,98,97,114,97)` |
| cactus | `IL_` | `c2(99,97,99,116,117,115)` |
| robot | `xL_` | `c2(114,111,98,111,116)` |
| rabbit | `uL_` | `c2(114,97,98,98,105,116)` |
| mushroom | `mL_` | `c2(109,117,115,104,114,111,111,109)` |
| chonk | `pL_` | `c2(99,104,111,110,107)` |

## Binary Patch Locations (v2.1.90)

| Component | Anchor Pattern | Expected Locations |
|-----------|---------------|-------------------|
| Species array (voq) | `GL_,ZL_,LL_,kL_,` | 4 |
| Rarity weights (LN6) | `common:60,uncommon:25,rare:10,epic:4,legendary:1` | 2 |
| Shiny threshold | `H()<0.01` | 2 |
| ASCII art (sk7) | `[{var}]:[[` per species | 2 |
| Stat generator (eN4) | `Math.floor(H()*40)` | 2 |

## Patching Constraints

1. All patches MUST maintain exact byte length (no shifting)
2. All species variable names are exactly 3 bytes
3. Binary must be re-signed with `codesign --force --sign -` after patching
4. Offsets are version-specific — the script uses pattern matching, not hardcoded offsets
5. The `__BUN/__bun` Mach-O section contains the actual executable JS bundle
6. Source map strings exist separately and must also be patched for consistency

## Rarity Probability Weights

| Rarity | Original Weight | Probability |
|--------|----------------|-------------|
| common | 60 | 60% |
| uncommon | 25 | 25% |
| rare | 10 | 10% |
| epic | 4 | 4% |
| legendary | 1 | 1% |

## Rarity → Reaction Frequency

| Rarity | Reaction Rate |
|--------|--------------|
| common | 5% |
| uncommon | 15% |
| rare | 25% |
| epic | 35% |
| legendary | 50% |
