# Phase 18 — Collision design

Bielik2D's first collision module: a 2D shape-query layer, pure math with zero GPU, plus a
capsule SDF primitive pulled forward so collision shapes are debug-drawable immediately. This
is the highest-impact post-v0 gap — it unblocks every gameplay interaction. Maps to Phase 18 in
[TODO.md](../../../TODO.md) and the `collision` row in [FEATURES.md](../../../FEATURES.md).

## Goals

- Closed-form overlap, manifold, and raycast queries for three shapes: `Circle`, `AABB`, `Capsule`.
- Protocol-oriented Swift API with compile-time dispatch (`player.overlaps(wall)`).
- A capsule SDF draw primitive (`ShapeType.capsule`) so collision shapes can be debug-drawn now,
  alongside `Circle`/`AABB` debug-draw built on existing primitives.

## Non-goals (deferred to a follow-up phase)

- `Poly` (convex polygon) shape and `poly`-pair queries.
- `Halfspace` shape.
- GJK closest-points, swept time-of-impact (TOI), convex-hull builder, `inflate`/`slice`.
- Spatial partitioning / broadphase — these are all-pairs narrowphase queries only.

## Shapes

```swift
struct Circle:  CollisionShape { var center: SIMD2<Float>; var radius: Float }
struct AABB:    CollisionShape { var min: SIMD2<Float>; var max: SIMD2<Float> }
struct Capsule: CollisionShape { var a: SIMD2<Float>; var b: SIMD2<Float>; var radius: Float }
struct Ray { var origin: SIMD2<Float>; var direction: SIMD2<Float>; var length: Float }
```

- `AABB` stores `min`/`max` corners (cheaper interval math than `Rect`'s origin+size). A bridge
  `init(_ rect: Rect)` and a `var rect: Rect` round-trip keep it interoperable with the rest of
  the engine, which speaks `Rect`.
- `Ray.init(origin:direction:length:)` normalizes `direction` so every query can assume a unit
  direction (raycast correctness depends on this — matches CF's `cf_make_ray`).
- `Capsule` is a segment `a→b` inflated by `radius`. A zero-length capsule (`a == b`) degenerates
  to a circle; queries must stay correct in that case (clamp handles it).
- `protocol CollisionShape {}` is a marker uniting the three concrete shapes; used by debug-draw.
  No `Shape` enum — both queries and debug-draw operate on concrete types (YAGNI).

## Result types

```swift
struct Manifold { var normal: SIMD2<Float>; var depth: Float; var contact: SIMD2<Float> }
struct Raycast  { var t: Float; var point: SIMD2<Float>; var normal: SIMD2<Float> }
```

- **Manifold normal convention:** `normal` points from `self` toward `other`. To separate, push
  `self` by `-normal * depth` (or `other` by `+normal * depth`). `depth >= 0`. `contact` is a
  representative contact point on the overlap (on `self`'s surface along the normal).
- **Raycast:** `t` is the distance along the ray (`0...length`); `point = origin + direction * t`;
  `normal` is the surface normal at the hit, pointing back toward the ray origin. `nil` = no hit
  within `length`. A ray starting inside a shape is defined per-query (documented in tests).

## API — protocol-oriented, concrete overloads

Each shape exposes overloaded methods, so call sites get compile-time dispatch with no
double-dispatch cost:

```swift
if player.overlaps(wall) { ... }              // Bool
if let m = player.manifold(with: wall) {      // Manifold?
    playerPos -= m.normal * m.depth           // push out of penetration
}
if let hit = ray.cast(against: enemy) { ... } // Raycast?
```

Each unordered pair is implemented once in a canonical direction. The reverse direction delegates
and negates the manifold normal:

```swift
extension Circle {
    func overlaps(_ o: Circle) -> Bool      // canonical
    func overlaps(_ o: AABB) -> Bool        // canonical
    func overlaps(_ o: Capsule) -> Bool     // canonical
}
extension AABB {
    func overlaps(_ o: Circle) -> Bool { o.overlaps(self) }            // delegate
    func overlaps(_ o: AABB) -> Bool        // canonical
    func overlaps(_ o: Capsule) -> Bool     // canonical
}
extension Capsule {
    func overlaps(_ o: Circle) -> Bool { o.overlaps(self) }            // delegate
    func overlaps(_ o: AABB) -> Bool { o.overlaps(self) }              // delegate
    func overlaps(_ o: Capsule) -> Bool     // canonical
}
// manifold(with:) follows the same canonical/delegate pattern; delegates flip normal sign.
```

Six unordered pairs: Circle–Circle, Circle–AABB, Circle–Capsule, AABB–AABB, AABB–Capsule,
Capsule–Capsule. Raycast targets all three shapes (`Ray.cast(against: Circle/AABB/Capsule)`).

## Math

All closed-form, built on a small set of shared closest-point helpers:

- `closestPointOnSegment(_ p:, _ a:, _ b:) -> SIMD2<Float>`
- `closestPointOnAABB(_ p:, _ box:) -> SIMD2<Float>`
- `segmentSegmentClosest(_ a0:, _ a1:, _ b0:, _ b1:) -> (SIMD2<Float>, SIMD2<Float>)`
- `segmentAABBClosest(_ a0:, _ a1:, _ box:) -> (SIMD2<Float>, SIMD2<Float>)`

Pair logic (overlap; manifold extends each with normal/depth/contact):

| Pair | Test |
|---|---|
| Circle–Circle | `distance(centers) <= r1 + r2` |
| Circle–AABB | `distance(center, closestPointOnAABB) <= r` |
| Circle–Capsule | `distance(center, closestPointOnSegment) <= r1 + r2` |
| AABB–AABB | interval overlap on both axes |
| AABB–Capsule | `distance(segment, box) <= r` via `segmentAABBClosest` |
| Capsule–Capsule | `distance(segment, segment) <= r1 + r2` via `segmentSegmentClosest` |

Raycast: ray–circle (quadratic), ray–AABB (slab method), ray–capsule (ray vs segment-swept
circle). Degenerate cases (zero-length capsule, ray origin inside, parallel/grazing) covered by
tests.

## Capsule SDF primitive (pulled forward from Phase 19)

A new `ShapeType.capsule = 4` rendered through the existing unified SDF pipeline.

- **Vertex emission** reuses the line's setup: a quad around the segment, extended by `radius + aa`
  on all sides; UVs in capsule-local world units (x along the segment from `-halfLen`, y
  perpendicular); `halfLen` in `attributes.x`; `radius` carried in `Vertex.radius`.
- **Shader branch** added to both `Shaders/src/sprite.frag.hlsl` and `Shaders/wgsl/sprite.frag.wgsl`:

  ```
  float dx = abs(uv.x) - halfLen;
  float dist = length(float2(max(dx, 0.0), uv.y)) - radius;
  // fill:    a = smoothstep(aa, -aa, dist);
  // outline: a = smoothstep(stroke*0.5 + aa, stroke*0.5 - aa, abs(dist));
  ```

  Verified: inside the x-range `dx <= 0`, so `dist = |y| - radius`; past an endpoint the term
  measures distance to the rounded cap. `ShapeType` enum in `Draw/Primitives.swift` gains `.capsule`.
- **Draw API:** `Draw.capsule(from:to:radius:stroke:color:aa:)` — `stroke == 0` fills, `> 0` outlines.
- **Debug-draw:** `Draw.debug(_ c: Circle)`, `Draw.debug(_ b: AABB)`, `Draw.debug(_ cap: Capsule)`
  routing to a `circleFill` outline / `box` / `capsule` respectively, in a uniform debug color.

Shaders are recompiled via `Shaders/build.sh` (regenerates `.spv` + copies WGSL overrides).

## Module layout

```
Sources/Bielik2D/Collision/
  Shapes.swift        Circle, AABB, Capsule, Ray, CollisionShape, Rect bridge
  Results.swift       Manifold, Raycast
  ClosestPoint.swift  shared closest-point helpers
  Overlap.swift       overlap booleans (canonical + delegates)
  Manifolds.swift     manifold generators (canonical + delegates)
  Raycast.swift       ray vs circle / aabb / capsule
```

Draw additions live in `Draw/Primitives.swift` (capsule + debug helpers); the `ShapeType` enum
there gains `.capsule`.

## Testing (red-green TDD)

swift-testing, hand-computed expected values (matching `PrimitivesTests`):

- `CollisionOverlapTests` — touching / overlapping / disjoint for all six pairs; zero-length
  capsule behaves as a circle.
- `CollisionManifoldTests` — normal direction (self→other), depth magnitude, contact point on
  known overlaps; reverse-pair normal is the negation of the canonical pair.
- `CollisionRaycastTests` — hit `t`/point/normal vs all three shapes; miss returns `nil`; ray
  starting inside; parallel/grazing edge cases.
- `ClosestPointTests` — the shared helpers against hand-computed points.
- `CapsulePrimitiveTests` — vertex count (6), `ShapeType.capsule`, quad bounds and `aa` scaling
  (mirrors the existing box/line primitive tests).

## Verification

- `swift test` green.
- `Shaders/build.sh` regenerates shaders without error.
- `swift build -c release` clean; demo extended with a capsule and a small push-out resolution
  showcase (a dot resolved out of a box/capsule via `manifold`), confirmed running on Metal.

## Build sequence

1. `ClosestPoint.swift` + `ClosestPointTests` (foundation helpers).
2. `Shapes.swift` + `Results.swift` (types, `Ray` normalization, `Rect` bridge).
3. `Overlap.swift` + `CollisionOverlapTests` (all six pairs).
4. `Manifolds.swift` + `CollisionManifoldTests`.
5. `Raycast.swift` + `CollisionRaycastTests`.
6. `ShapeType.capsule` + capsule shader branch (HLSL + WGSL) + `Shaders/build.sh`.
7. `Draw.capsule` + `Draw.debug(_:)` overloads + `CapsulePrimitiveTests`.
8. Demo showcase + release verification.

Each step is an atomic commit that builds and passes tests.
