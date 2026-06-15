# Bielik2D

A 2D game engine in pure Swift 6.3 on SDL3's modern GPU API, inspired by Cute Framework.

## Keep FEATURES.md and TODO.md current

[FEATURES.md](FEATURES.md) tracks the engine's feature surface against Cute Framework (✅ shipped ·
🟡 partial · ⏳ planned · ⛔ deferred · ➖ N/A). It rots the moment it's maintained by memory, so
treat it as a standing rule of the codebase:

**When an engine module's outward maturity changes — a planned capability ships, a partial module
fills a gap, a new primitive lands, or a "Missing:" item is resolved — update `FEATURES.md` (status
flag, Notes cell, Summary counts, "What to build next") and the matching `TODO.md` phase checkbox in
the same commit as the code.**

Do *not* touch FEATURES.md for intermediate red-green TDD commits, refactors, or tooling/CI work that
doesn't change a module's outward capability. The test: *did a module's maturity actually change?*

The `update-features` skill (`.claude/skills/update-features/`) has the mechanics and fires
proactively after shipping a feature — follow it.
