# Swept TOI + slide/resolve — design

**Date:** 2026-06-15
**Branch/worktree:** `swept-toi` (`../bielik2d-swept-toi`)
**Phase:** 18 follow-up (continuous collision)

## Problem

Bielik2D's collision module is discrete-only. `overlaps`/`manifold`/`cast` answer "are these
two shapes touching *right now*", but a fast-moving shape tunnels straight through a thin
collider between two frames — a falling player passes through a one-tile platform, a bullet
passes through a wall. This is a gameplay-correctness gap, not a polish gap: it's the last
missing piece of the Phase 18 collision module (`TODO.md` lists swept `toi` as the only
remaining item) and the highest-leverage thing blocking a typical 2D game.

## Goals

1. A continuous **time-of-impact (TOI)** primitive for translating convex shapes — genuinely
   tunnel-proof, not probabilistic.
2. A **slide/resolve helper** ("move-and-collide") on top of the primitive — the call a
   kinematic character controller actually makes: move a shape by a displacement against a set
   of static colliders, sliding along surfaces instead of stopping dead.

## Non-goals

- **Rotation / angular velocity.** Engine collision shapes are world-space and translation-only;
  conservative advancement is applied to linear motion only. (Out of scope, not on the path.)
- **Physics response** (restitution, friction, mass, impulses). This is kinematic sweep + slide,
  not a dynamics solver.
- **Broadphase.** The helper takes an explicit `world: [CollisionShape]`; spatial partitioning is
  the caller's concern (and a separate future module).

## Coverage

- **Mover:** any convex shape — `Circle`, `AABB`, `Capsule`, `Polygon`.
- **World / target:** any convex shape **plus** `Halfspace` (walls/floors as planes).
- All convex-vs-convex pairs go through one GJK path. `Halfspace` (no finite support) gets a
  closed-form path.

## Algorithm — GJK conservative advancement

Chosen over per-pair closed-form swept tests (O(pairs) hand-written math, nasty polygon-polygon
case) and substepped discrete overlap (only *reduces* tunneling, jitters — doesn't solve the
problem). Conservative advancement reuses the `Support` / `gjkDistance` machinery already in
`Collision/GJK.swift`, is one code path for all convex pairs, and is the method CF's `c2TOI` uses.

Reduce both-moving to one-moving via **relative displacement** `relDelta = delta - targetDelta`;
the target is treated as static and the mover sweeps along `relDelta`.

Per step, with the mover at parameter `t ∈ [0,1]` along `relDelta`:

1. Compute `gjkDistance` between the mover (translated to `t`) core and the target core; apply
   the combined radius margin (`Support.radius` of both) to get the true gap `d` and the
   separating `normal` (mover → target).
2. **Closing speed** along the normal: `vc = dot(relDelta, normal)`. If `vc <= eps`, the shapes
   are not approaching along the contact normal → no impact this sweep → return `nil`.
3. **Safe advance:** `t += (d - target_tolerance) / vc`. This is the largest step that provably
   cannot cause penetration (the gap shrinks by at most `vc * Δt`).
4. If `t > 1`, the impact is beyond the sweep → `nil`. If `d <= tolerance`, converged → impact at
   `t` with the current `normal` and a contact point recovered from the GJK witness points.
5. Iteration cap (e.g. 32, matching `gjkDistance`) as a divergence backstop.

**Halfspace closed-form:** the mover's nearest extent toward the solid side is its support in
`-normal`; signed distance to the plane is `dot(extent - planePoint, normal)`. Closing speed is
`-dot(relDelta, normal)`. `t = distance / closingSpeed` if approaching and `t ∈ [0,1]`, else `nil`.

## Public API

### Types (`Sources/Bielik2D/Collision/TOI.swift`)

```swift
/// A continuous time-of-impact result for a swept shape.
/// `t` is the fraction of the sweep displacement at first contact (0...1);
/// `point` is the contact point; `normal` is the surface normal facing back toward the mover.
public struct ToI: Equatable, Sendable {
    public var t: Float
    public var point: SIMD2<Float>
    public var normal: SIMD2<Float>
    public init(t: Float, point: SIMD2<Float>, normal: SIMD2<Float>)
}
```

### Raw primitive

Mirrors the existing `cast(against:)` convention. Modeled on **displacement over the step**
(frame-rate agnostic): `t` is the fraction of `delta` consumed at impact.

```swift
extension Circle  { func sweep(by delta: SIMD2<Float>, against target: <Shape>,
                               movedBy targetDelta: SIMD2<Float> = .zero) -> ToI? }
// …and on AABB, Capsule, Polygon, for each convex target + Halfspace.
```

Internally all convex pairs funnel through a single generic helper over `Support`; the public
methods are thin per-pair entry points (matching the module's existing explicit-dispatch style).
`nil` = clean miss. Already-overlapping at `t=0` returns `t=0` with the EPA/manifold separating
normal (so the resolve helper can still push out).

### Slide/resolve helper (`Sources/Bielik2D/Collision/Move.swift`)

```swift
/// Net result of a swept move with surface sliding.
public struct MoveResult: Equatable, Sendable {
    public var motion: SIMD2<Float>        // net displacement actually applied
    public var normals: [SIMD2<Float>]     // surfaces touched (grounded / wall checks)
    public init(motion: SIMD2<Float>, normals: [SIMD2<Float>])
}

extension <ConvexShape> {
    /// Sweep `self` by `delta` against `world`, sliding along contacts.
    /// Caller owns the game-object position and applies `MoveResult.motion`.
    func move(by delta: SIMD2<Float>, against world: [CollisionShape],
              iterations: Int = 4, skin: Float = 0.01) -> MoveResult
}
```

Per iteration: find the **earliest** TOI across all `world` colliders → advance to just before
it (back off by `skin` along the normal to avoid sticking) → record the contact normal → project
the *remaining* displacement onto the contact tangent (slide) → repeat up to `iterations` times
or until the remaining displacement is ~zero. Returns the summed net motion and all contact
normals. The caller derives grounded/wall state from `normals` (e.g. a normal with `y` above a
threshold = floor).

### Supporting addition

```swift
extension <Shape> { func translated(by v: SIMD2<Float>) -> Self }
```

Uniform translation for `Circle` (center), `AABB` (min/max), `Capsule` (a/b), `Polygon`
(vertices). Needed internally to advance the mover between substeps; exposed publicly because
it's generally useful. `Halfspace`/`Ray` translation not required for this work (targets are
static); add only if trivial.

## Edge cases

- **Already penetrating at `t=0`** → `ToI(t: 0, …)` with the separating normal from EPA; the
  resolve helper pushes out by depth before sweeping.
- **Zero displacement** (`delta == .zero`) → `nil` from `sweep`; `MoveResult(motion: .zero, …)`
  from `move` (plus any push-out if already penetrating).
- **Grazing / parallel motion** (`closing speed <= eps`) → `nil` (not approaching).
- **Halfspace receding** → `nil`.
- **Degenerate shapes** (zero-radius capsule, zero-length displacement) — same numeric guards the
  GJK code already uses (`1e-12` / `1e-8`).

## Testing (TDD, red-green, hand-computed)

`Tests/Bielik2DTests/` — new `SweptTOITests.swift` + `MoveSlideTests.swift`:

- Circle falling straight onto an AABB stops exactly at the surface (`t` and contact verified).
- A fast circle whose displacement *crosses* a thin box reports impact (regression: would have
  tunneled with discrete overlap).
- Slide along a 45° wall retains the tangential component (motion magnitude check).
- Halfspace floor: a downward sweep stops at the plane.
- Both shapes moving: impact computed via relative displacement.
- Polygon-vs-polygon sweep (exercises the full GJK path).
- Edge cases: zero displacement, already-penetrating, receding (all → no-impact / push-out).

All predicates checked against hand-computed expected values, matching the module's existing
test style.

## Docs to update (same commit as the code that lands the capability)

- `FEATURES.md`: collision row — drop "**Missing:** swept time-of-impact"; bump Notes; the
  Summary counts stay (collision is already 🟡). Update "What to build next" (remove the swept-TOI
  bullet).
- `TODO.md`: check the Phase 18 `swept toi` box.

## Build sequence (each step builds + tests green)

1. `ToI` type + `translated(by:)` on the four convex shapes (with tests).
2. Generic GJK conservative-advancement core + `Circle`/`Circle` `sweep` as the first pair (RED
   test for tunneling first).
3. Extend `sweep` to all convex pairs through the shared core.
4. `Halfspace` closed-form `sweep` path.
5. `MoveResult` + `move(by:against:)` slide helper (single collider, then multi + iterations).
6. Edge-case hardening (already-penetrating push-out, zero/grazing).
7. Demo slice (optional): a draggable circle that slides along a few static boxes/planes.
8. `FEATURES.md` + `TODO.md` update in the commit that lands the user-visible capability.
