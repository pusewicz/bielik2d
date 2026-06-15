---
name: update-features
description: Use when the user asks to update FEATURES.md, mark a module/feature as shipped or partial, flip a status flag, or notes that FEATURES.md is out of date. Also trigger proactively after shipping or changing an engine module's outward capability — a planned module lands, a new draw primitive or sub-feature ships, a "Missing:" item is resolved, or a TODO phase completes — even if the user hasn't explicitly asked, because CLAUDE.md requires FEATURES.md to move in the same commit as the code. Covers prompts like "update FEATURES.md", "mark collision as shipped", "the binding action map is done", "we finished Phase 18", or after implementing any module-level engine capability.
---

# Updating FEATURES.md

[FEATURES.md](../../../FEATURES.md) tracks Bielik2D's feature surface against Cute Framework. CLAUDE.md
requires it (and the matching `TODO.md` phase) to stay current in the **same commit** as the code that
changes a module's maturity. This skill is the how-to.

**Legend:** ✅ shipped · 🟡 partial · ⏳ planned · ⛔ deferred · ➖ N/A (Swift stdlib/Foundation covers it)

## What gets an update

Anything that changes a module's *outward maturity*:

- A module crosses a legend threshold: ⏳→🟡 (first capability lands), 🟡→✅ (last gap filled), or
  ⏳→✅ (shipped whole).
- A new primitive or sub-feature lands inside a 🟡 module — move it out of that row's "Missing:" list
  into the shipped Notes.
- A ⛔ deferred item gets picked up — promote it to ⏳/🟡/✅ as appropriate.
- A TODO phase completes — reflect it here and tick the phase in `TODO.md`.

## What does NOT get an update

Internal work that doesn't change what the engine can outwardly do:

- Intermediate red-green TDD commits inside an in-progress feature.
- Refactors, cleanup, architecture changes.
- Build system, CI, tooling changes.
- Performance improvements that don't add or complete a capability.

The test: *did a module's outward maturity actually change?* If no, leave FEATURES.md alone.

## How to update

1. **Understand what changed** — read the diff and/or recent commits if it isn't already clear.
   `git diff HEAD` for uncommitted work; `git log --oneline -10` + `git show <sha>` for committed work.

2. **Flip the status flag** — in the **Engine modules** table, update the module's legend emoji to its
   new maturity.

3. **Edit the Notes cell** — describe the new capability in the same voice as the existing notes. When
   a 🟡 module fills a gap, remove that item from its "**Missing:**" list (and drop the "Missing:"
   clause entirely once nothing's left, flipping the row to ✅).

4. **Recompute the Summary table** — the counts and module lists in the **Summary** section must stay
   consistent with the Engine-modules table. E.g. shipping a planned module: ⏳ planned count −1 and
   drop it from that list; ✅ shipped count +1 and add it. Double-check the totals.

5. **Update "What to build next"** — if a listed item shipped, remove or re-sequence it so the section
   still points at the real next work.

6. **Sync TODO.md** — tick the matching phase checkbox(es) so `FEATURES.md` and `TODO.md` agree (the
   phase numbers in FEATURES.md's Notes are the cross-reference).

7. **Stage together** — `git add FEATURES.md TODO.md` alongside the code so it lands in the same commit.

## Confirm

Briefly show the user the status transitions made (e.g. "collision ⏳→✅, Summary shipped 6→7 /
planned 3→2, Phase 18 ticked in TODO.md").
