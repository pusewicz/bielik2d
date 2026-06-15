# Collision (Phase 18) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add closed-form 2D collision queries (overlap, manifold, raycast) for Circle, AABB, and Capsule, plus a capsule SDF draw primitive so collision shapes are debug-drawable.

**Architecture:** A pure-math `Collision/` module of value-type shapes with protocol-oriented, compile-time-dispatched query methods. Each unordered shape pair is implemented once in a canonical direction; reverse directions delegate and negate the manifold normal. A new `ShapeType.capsule` reuses the existing unified SDF vertex pipeline for rendering and debug-draw.

**Tech Stack:** Swift 6.3, `simd` (with `kvSIMD` fallback), swift-testing (`import Testing`), SDL3 GPU via shadercross; HLSL→SPIR-V and hand-written WGSL shaders.

---

## Conventions used throughout

- **Test framework:** swift-testing. Files import `Testing` and `@testable import Bielik2D`. Tests are `@Test func name() { #expect(...) }`.
- **Run a single test:** `swift test --filter <TestFuncName>`
- **Run all tests:** `swift test`
- **simd import pattern** (top of every Collision source file), matching `Draw/Primitives.swift`:

```swift
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
```

- **Float comparisons in tests** use a tolerance: `#expect(abs(a - b) < 1e-4)`.
- **Commit style:** lowercase imperative, no Conventional-Commits prefix, no AI signoff (per repo convention).

---

## File Structure

```
Sources/Bielik2D/Collision/
  Shapes.swift        Circle, AABB, Capsule, Ray, CollisionShape marker, Rect bridge, AABB.contains
  Results.swift       Manifold, Raycast
  ClosestPoint.swift  clamp01, closestPointOnSegment, closestPointOnAABB, segmentSegmentClosest, segmentAABBClosest
  Overlap.swift       6 overlap booleans (canonical + delegating reverses)
  Manifolds.swift     6 manifold generators (canonical + delegating reverses)
  Raycast.swift       Ray.cast(against:) vs Circle / AABB / Capsule
Sources/Bielik2D/Draw/Primitives.swift   (modify) ShapeType.capsule, Draw.capsule, Draw.debug overloads
Shaders/src/sprite.frag.hlsl             (modify) t == 4 capsule branch
Shaders/wgsl/sprite.frag.wgsl            (modify) t == 4 capsule branch
Tests/Bielik2DTests/ClosestPointTests.swift
Tests/Bielik2DTests/CollisionOverlapTests.swift
Tests/Bielik2DTests/CollisionManifoldTests.swift
Tests/Bielik2DTests/CollisionRaycastTests.swift
Tests/Bielik2DTests/CapsulePrimitiveTests.swift
```

---

### Task 1: Shape and result types

**Files:**
- Create: `Sources/Bielik2D/Collision/Shapes.swift`
- Create: `Sources/Bielik2D/Collision/Results.swift`
- Test: `Tests/Bielik2DTests/CollisionTypesTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/Bielik2DTests/CollisionTypesTests.swift`:

```swift
import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

@Test func rayNormalizesDirection() {
    let r = Ray(origin: SIMD2(0, 0), direction: SIMD2(3, 4), length: 10)
    #expect(abs(simd_length(r.direction) - 1) < 1e-5)
    #expect(abs(r.direction.x - 0.6) < 1e-5)
    #expect(abs(r.direction.y - 0.8) < 1e-5)
    #expect(r.length == 10)
}

@Test func aabbBridgesToAndFromRect() {
    let box = AABB(Rect(x: 1, y: 2, width: 4, height: 6))
    #expect(box.min == SIMD2(1, 2))
    #expect(box.max == SIMD2(5, 8))
    let back = box.rect
    #expect(back == Rect(x: 1, y: 2, width: 4, height: 6))
}

@Test func aabbContainsPoint() {
    let box = AABB(min: SIMD2(0, 0), max: SIMD2(2, 2))
    #expect(box.contains(SIMD2(1, 1)))
    #expect(box.contains(SIMD2(0, 0)))    // boundary counts
    #expect(!box.contains(SIMD2(3, 1)))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CollisionTypesTests`
Expected: FAIL — `cannot find 'Ray' in scope` (types not defined yet).

- [ ] **Step 3: Create the types**

Create `Sources/Bielik2D/Collision/Shapes.swift`:

```swift
#if canImport(simd)
import simd
#else
import kvSIMD
#endif

/// Marker uniting the concrete collision shapes. Used by `Draw.debug(_:)`.
public protocol CollisionShape {}

/// A circle defined by its centre and radius.
public struct Circle: CollisionShape, Equatable, Sendable {
    public var center: SIMD2<Float>
    public var radius: Float
    public init(center: SIMD2<Float>, radius: Float) {
        self.center = center
        self.radius = radius
    }
}

/// An axis-aligned bounding box stored as min/max corners (cheaper interval math than Rect).
public struct AABB: CollisionShape, Equatable, Sendable {
    public var min: SIMD2<Float>
    public var max: SIMD2<Float>
    public init(min: SIMD2<Float>, max: SIMD2<Float>) {
        self.min = min
        self.max = max
    }
    /// Bridge from the engine's origin+size `Rect`.
    public init(_ rect: Rect) {
        self.min = SIMD2(rect.minX, rect.minY)
        self.max = SIMD2(rect.maxX, rect.maxY)
    }
    /// Round-trip back to a `Rect`.
    public var rect: Rect {
        Rect(x: min.x, y: min.y, width: max.x - min.x, height: max.y - min.y)
    }
    /// True if `p` is inside or on the boundary.
    public func contains(_ p: SIMD2<Float>) -> Bool {
        p.x >= min.x && p.x <= max.x && p.y >= min.y && p.y <= max.y
    }
}

/// A segment `a`→`b` inflated by `radius`. A zero-length capsule degenerates to a circle.
public struct Capsule: CollisionShape, Equatable, Sendable {
    public var a: SIMD2<Float>
    public var b: SIMD2<Float>
    public var radius: Float
    public init(a: SIMD2<Float>, b: SIMD2<Float>, radius: Float) {
        self.a = a
        self.b = b
        self.radius = radius
    }
}

/// A ray for casting queries. `direction` is normalised at init; `length` bounds the cast.
public struct Ray: Equatable, Sendable {
    public var origin: SIMD2<Float>
    public var direction: SIMD2<Float>
    public var length: Float
    public init(origin: SIMD2<Float>, direction: SIMD2<Float>, length: Float) {
        self.origin = origin
        let len = simd_length(direction)
        self.direction = len > 1e-12 ? direction / len : SIMD2(0, 0)
        self.length = length
    }
}
```

Create `Sources/Bielik2D/Collision/Results.swift`:

```swift
#if canImport(simd)
import simd
#else
import kvSIMD
#endif

/// Penetration data for an overlapping pair. `normal` points from the query shape
/// (`self`) toward the other shape; separate by moving `self` by `-normal * depth`.
public struct Manifold: Equatable, Sendable {
    public var normal: SIMD2<Float>
    public var depth: Float
    public var contact: SIMD2<Float>
    public init(normal: SIMD2<Float>, depth: Float, contact: SIMD2<Float>) {
        self.normal = normal
        self.depth = depth
        self.contact = contact
    }
}

/// A ray hit. `t` is the distance along the ray (`0...length`); `point = origin + direction * t`;
/// `normal` is the surface normal at the hit, facing back toward the ray origin.
public struct Raycast: Equatable, Sendable {
    public var t: Float
    public var point: SIMD2<Float>
    public var normal: SIMD2<Float>
    public init(t: Float, point: SIMD2<Float>, normal: SIMD2<Float>) {
        self.t = t
        self.point = point
        self.normal = normal
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter CollisionTypesTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/Bielik2D/Collision/Shapes.swift Sources/Bielik2D/Collision/Results.swift Tests/Bielik2DTests/CollisionTypesTests.swift
git commit -m "add collision shape and result types"
```

---

### Task 2: Closest-point helpers

**Files:**
- Create: `Sources/Bielik2D/Collision/ClosestPoint.swift`
- Test: `Tests/Bielik2DTests/ClosestPointTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/Bielik2DTests/ClosestPointTests.swift`:

```swift
import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

@Test func closestPointOnSegmentClampsToEndpoints() {
    let a = SIMD2<Float>(0, 0), b = SIMD2<Float>(10, 0)
    #expect(closestPointOnSegment(SIMD2(5, 3), a, b) == SIMD2(5, 0))   // perpendicular foot
    #expect(closestPointOnSegment(SIMD2(-4, 1), a, b) == SIMD2(0, 0))  // before a
    #expect(closestPointOnSegment(SIMD2(99, 1), a, b) == SIMD2(10, 0)) // past b
}

@Test func closestPointOnSegmentHandlesDegenerateSegment() {
    let a = SIMD2<Float>(2, 2)
    #expect(closestPointOnSegment(SIMD2(9, 9), a, a) == a)
}

@Test func closestPointOnAABBClamps() {
    let box = AABB(min: SIMD2(0, 0), max: SIMD2(4, 4))
    #expect(closestPointOnAABB(SIMD2(2, 9), box) == SIMD2(2, 4))   // above
    #expect(closestPointOnAABB(SIMD2(-3, 2), box) == SIMD2(0, 2))  // left
    #expect(closestPointOnAABB(SIMD2(2, 2), box) == SIMD2(2, 2))   // inside -> itself
}

@Test func segmentSegmentClosestParallelOffset() {
    // Two horizontal segments offset by 2 in y; closest distance is 2.
    let (c1, c2) = segmentSegmentClosest(SIMD2(0, 0), SIMD2(10, 0),
                                         SIMD2(0, 2), SIMD2(10, 2))
    #expect(abs(simd_distance(c1, c2) - 2) < 1e-4)
}

@Test func segmentSegmentClosestCrossingIsZero() {
    let (c1, c2) = segmentSegmentClosest(SIMD2(-5, 0), SIMD2(5, 0),
                                         SIMD2(0, -5), SIMD2(0, 5))
    #expect(simd_distance(c1, c2) < 1e-4)   // they intersect at the origin
}

@Test func segmentAABBClosestOutsideAndCrossing() {
    let box = AABB(min: SIMD2(0, 0), max: SIMD2(2, 2))
    // Segment fully to the right of the box; nearest distance is 1 (x=3 vs x=2).
    let (s1, b1) = segmentAABBClosest(SIMD2(3, -5), SIMD2(3, 5), box)
    #expect(abs(simd_distance(s1, b1) - 1) < 1e-4)
    // Segment passing through the box -> distance 0.
    let (s2, b2) = segmentAABBClosest(SIMD2(-5, 1), SIMD2(5, 1), box)
    #expect(simd_distance(s2, b2) < 1e-4)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ClosestPointTests`
Expected: FAIL — `cannot find 'closestPointOnSegment' in scope`.

- [ ] **Step 3: Implement the helpers**

Create `Sources/Bielik2D/Collision/ClosestPoint.swift`:

```swift
#if canImport(simd)
import simd
#else
import kvSIMD
#endif

@inline(__always)
func clamp01(_ v: Float) -> Float { min(max(v, 0), 1) }

/// Closest point on segment `a`→`b` to `p`. Returns `a` for a degenerate segment.
func closestPointOnSegment(_ p: SIMD2<Float>, _ a: SIMD2<Float>, _ b: SIMD2<Float>) -> SIMD2<Float> {
    let ab = b - a
    let denom = simd_dot(ab, ab)
    guard denom > 1e-12 else { return a }
    let t = clamp01(simd_dot(p - a, ab) / denom)
    return a + ab * t
}

/// Closest point on (or inside) the AABB to `p`.
func closestPointOnAABB(_ p: SIMD2<Float>, _ box: AABB) -> SIMD2<Float> {
    SIMD2(
        min(max(p.x, box.min.x), box.max.x),
        min(max(p.y, box.min.y), box.max.y)
    )
}

/// Closest points between segment `p1`→`q1` and segment `p2`→`q2`.
/// Returns `(point on first, point on second)`. (Ericson, Real-Time Collision Detection.)
func segmentSegmentClosest(_ p1: SIMD2<Float>, _ q1: SIMD2<Float>,
                           _ p2: SIMD2<Float>, _ q2: SIMD2<Float>) -> (SIMD2<Float>, SIMD2<Float>) {
    let d1 = q1 - p1
    let d2 = q2 - p2
    let r = p1 - p2
    let a = simd_dot(d1, d1)
    let e = simd_dot(d2, d2)
    let f = simd_dot(d2, r)
    let eps: Float = 1e-12
    var s: Float = 0
    var t: Float = 0
    if a <= eps && e <= eps {
        return (p1, p2)                       // both segments are points
    }
    if a <= eps {
        s = 0
        t = clamp01(f / e)                    // first segment is a point
    } else {
        let c = simd_dot(d1, r)
        if e <= eps {
            t = 0
            s = clamp01(-c / a)               // second segment is a point
        } else {
            let b = simd_dot(d1, d2)
            let denom = a * e - b * b
            s = denom > eps ? clamp01((b * f - c * e) / denom) : 0
            t = (b * s + f) / e
            if t < 0 {
                t = 0
                s = clamp01(-c / a)
            } else if t > 1 {
                t = 1
                s = clamp01((b - c) / a)
            }
        }
    }
    return (p1 + d1 * s, p2 + d2 * t)
}

/// Closest points between segment `a0`→`a1` and the solid AABB.
/// Returns `(point on segment, point on box)`. Distance is 0 when the segment touches/enters the box.
func segmentAABBClosest(_ a0: SIMD2<Float>, _ a1: SIMD2<Float>, _ box: AABB) -> (SIMD2<Float>, SIMD2<Float>) {
    if box.contains(a0) { return (a0, a0) }
    if box.contains(a1) { return (a1, a1) }
    // Segment is outside (or crosses) the box: the nearest approach lies between the
    // segment and one of the four box edges (an interior crossing yields distance 0 there).
    let corners = [
        box.min,
        SIMD2(box.max.x, box.min.y),
        box.max,
        SIMD2(box.min.x, box.max.y),
    ]
    var best = (a0, corners[0])
    var bestDist = Float.greatestFiniteMagnitude
    for i in 0..<4 {
        let (cs, ce) = segmentSegmentClosest(a0, a1, corners[i], corners[(i + 1) % 4])
        let d = simd_distance(cs, ce)
        if d < bestDist {
            bestDist = d
            best = (cs, ce)
        }
    }
    return best
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ClosestPointTests`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/Bielik2D/Collision/ClosestPoint.swift Tests/Bielik2DTests/ClosestPointTests.swift
git commit -m "add closest-point collision helpers"
```

---

### Task 3: Overlap booleans

**Files:**
- Create: `Sources/Bielik2D/Collision/Overlap.swift`
- Test: `Tests/Bielik2DTests/CollisionOverlapTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/Bielik2DTests/CollisionOverlapTests.swift`:

```swift
import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

@Test func circleCircleOverlap() {
    let a = Circle(center: SIMD2(0, 0), radius: 2)
    #expect(a.overlaps(Circle(center: SIMD2(3, 0), radius: 2)))   // dist 3 < 4
    #expect(a.overlaps(Circle(center: SIMD2(4, 0), radius: 2)))   // dist 4 == 4 (touching)
    #expect(!a.overlaps(Circle(center: SIMD2(5, 0), radius: 2)))  // dist 5 > 4
}

@Test func circleAABBOverlapBothDirections() {
    let c = Circle(center: SIMD2(0, 0), radius: 1)
    let near = AABB(min: SIMD2(0.5, -1), max: SIMD2(2, 1))   // closest pt (0.5,0), dist 0.5
    let far = AABB(min: SIMD2(2, -1), max: SIMD2(4, 1))      // closest pt (2,0), dist 2
    #expect(c.overlaps(near))
    #expect(near.overlaps(c))    // reverse delegate
    #expect(!c.overlaps(far))
    #expect(!far.overlaps(c))
}

@Test func circleCapsuleOverlap() {
    let cap = Capsule(a: SIMD2(-5, 0), b: SIMD2(5, 0), radius: 1)
    #expect(Circle(center: SIMD2(0, 1.5), radius: 1).overlaps(cap))   // gap 0.5 < r sum 2
    #expect(!Circle(center: SIMD2(0, 4), radius: 1).overlaps(cap))    // gap 3 > 2
    #expect(cap.overlaps(Circle(center: SIMD2(0, 1.5), radius: 1)))   // reverse delegate
}

@Test func aabbAABBOverlap() {
    let a = AABB(min: SIMD2(0, 0), max: SIMD2(2, 2))
    #expect(a.overlaps(AABB(min: SIMD2(1, 1), max: SIMD2(3, 3))))
    #expect(!a.overlaps(AABB(min: SIMD2(3, 0), max: SIMD2(5, 2))))
}

@Test func aabbCapsuleOverlap() {
    let box = AABB(min: SIMD2(0, 0), max: SIMD2(2, 2))
    let through = Capsule(a: SIMD2(-5, 1), b: SIMD2(5, 1), radius: 0.5)   // passes through
    let near = Capsule(a: SIMD2(2.4, -5), b: SIMD2(2.4, 5), radius: 0.5)  // gap 0.4 < 0.5
    let far = Capsule(a: SIMD2(3, -5), b: SIMD2(3, 5), radius: 0.5)       // gap 1 > 0.5
    #expect(box.overlaps(through))
    #expect(box.overlaps(near))
    #expect(near.overlaps(box))   // reverse delegate
    #expect(!box.overlaps(far))
}

@Test func capsuleCapsuleOverlap() {
    let a = Capsule(a: SIMD2(0, 0), b: SIMD2(10, 0), radius: 1)
    let crossing = Capsule(a: SIMD2(5, -5), b: SIMD2(5, 5), radius: 1)
    let parallelNear = Capsule(a: SIMD2(0, 1.5), b: SIMD2(10, 1.5), radius: 1) // gap 1.5 < 2
    let parallelFar = Capsule(a: SIMD2(0, 3), b: SIMD2(10, 3), radius: 1)      // gap 3 > 2
    #expect(a.overlaps(crossing))
    #expect(a.overlaps(parallelNear))
    #expect(!a.overlaps(parallelFar))
}

@Test func zeroLengthCapsuleActsAsCircle() {
    let dot = Capsule(a: SIMD2(0, 0), b: SIMD2(0, 0), radius: 2)
    #expect(Circle(center: SIMD2(3, 0), radius: 2).overlaps(dot))   // like circle dist 3 < 4
    #expect(!Circle(center: SIMD2(5, 0), radius: 2).overlaps(dot))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CollisionOverlapTests`
Expected: FAIL — `value of type 'Circle' has no member 'overlaps'`.

- [ ] **Step 3: Implement the overlap booleans**

Create `Sources/Bielik2D/Collision/Overlap.swift`:

```swift
#if canImport(simd)
import simd
#else
import kvSIMD
#endif

extension Circle {
    public func overlaps(_ o: Circle) -> Bool {
        let r = radius + o.radius
        return simd_distance_squared(center, o.center) <= r * r
    }
    public func overlaps(_ o: AABB) -> Bool {
        simd_distance_squared(center, closestPointOnAABB(center, o)) <= radius * radius
    }
    public func overlaps(_ o: Capsule) -> Bool {
        let cp = closestPointOnSegment(center, o.a, o.b)
        let r = radius + o.radius
        return simd_distance_squared(center, cp) <= r * r
    }
}

extension AABB {
    public func overlaps(_ o: Circle) -> Bool { o.overlaps(self) }
    public func overlaps(_ o: AABB) -> Bool {
        min.x <= o.max.x && max.x >= o.min.x &&
        min.y <= o.max.y && max.y >= o.min.y
    }
    public func overlaps(_ o: Capsule) -> Bool {
        let (cs, ce) = segmentAABBClosest(o.a, o.b, self)
        return simd_distance_squared(cs, ce) <= o.radius * o.radius
    }
}

extension Capsule {
    public func overlaps(_ o: Circle) -> Bool { o.overlaps(self) }
    public func overlaps(_ o: AABB) -> Bool { o.overlaps(self) }
    public func overlaps(_ o: Capsule) -> Bool {
        let (c1, c2) = segmentSegmentClosest(a, b, o.a, o.b)
        let r = radius + o.radius
        return simd_distance_squared(c1, c2) <= r * r
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter CollisionOverlapTests`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/Bielik2D/Collision/Overlap.swift Tests/Bielik2DTests/CollisionOverlapTests.swift
git commit -m "add collision overlap booleans for all shape pairs"
```

---

### Task 4: Manifold generation

**Files:**
- Create: `Sources/Bielik2D/Collision/Manifolds.swift`
- Test: `Tests/Bielik2DTests/CollisionManifoldTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/Bielik2DTests/CollisionManifoldTests.swift`:

```swift
import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

@Test func circleCircleManifold() {
    let a = Circle(center: SIMD2(0, 0), radius: 2)
    let b = Circle(center: SIMD2(3, 0), radius: 2)   // overlap depth 1
    let m = a.manifold(with: b)
    #expect(m != nil)
    #expect(abs(m!.normal.x - 1) < 1e-4)        // points from a toward b
    #expect(abs(m!.normal.y) < 1e-4)
    #expect(abs(m!.depth - 1) < 1e-4)
    #expect(abs(m!.contact.x - 2) < 1e-4)       // on a's surface along normal
}

@Test func disjointShapesHaveNoManifold() {
    let a = Circle(center: SIMD2(0, 0), radius: 1)
    #expect(a.manifold(with: Circle(center: SIMD2(5, 0), radius: 1)) == nil)
}

@Test func reversePairNegatesNormal() {
    let c = Circle(center: SIMD2(0, 0), radius: 1)
    let box = AABB(min: SIMD2(0.5, -1), max: SIMD2(3, 1))   // overlap on +x
    let forward = c.manifold(with: box)!
    let reverse = box.manifold(with: c)!
    #expect(abs(forward.normal.x - 1) < 1e-4)               // circle pushed -x to separate
    #expect(abs(reverse.normal.x + 1) < 1e-4)               // negated
    #expect(abs(forward.depth - reverse.depth) < 1e-4)
}

@Test func aabbAABBManifoldPicksMinimumAxis() {
    let a = AABB(min: SIMD2(0, 0), max: SIMD2(2, 2))
    let b = AABB(min: SIMD2(1.5, 0.5), max: SIMD2(3.5, 2.5))  // overlapX 0.5 < overlapY 1.5
    let m = a.manifold(with: b)!
    #expect(abs(m.normal.x - 1) < 1e-4)    // separates along x (b is to the right)
    #expect(abs(m.normal.y) < 1e-4)
    #expect(abs(m.depth - 0.5) < 1e-4)
}

@Test func capsuleCapsuleManifold() {
    let a = Capsule(a: SIMD2(0, 0), b: SIMD2(10, 0), radius: 1)
    let b = Capsule(a: SIMD2(0, 1.5), b: SIMD2(10, 1.5), radius: 1)  // gap 1.5, depth 0.5
    let m = a.manifold(with: b)!
    #expect(abs(m.normal.y - 1) < 1e-4)    // points from a up toward b
    #expect(abs(m.depth - 0.5) < 1e-4)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CollisionManifoldTests`
Expected: FAIL — `value of type 'Circle' has no member 'manifold'`.

- [ ] **Step 3: Implement the manifold generators**

Create `Sources/Bielik2D/Collision/Manifolds.swift`:

```swift
#if canImport(simd)
import simd
#else
import kvSIMD
#endif

// Manifold `normal` points from the query shape (`self`) toward the other shape.
// Separate by moving `self` by `-normal * depth`. Reverse pairs delegate and negate.

@inline(__always)
private func flip(_ m: Manifold?) -> Manifold? {
    guard let m else { return nil }
    return Manifold(normal: -m.normal, depth: m.depth, contact: m.contact)
}

extension Circle {
    public func manifold(with o: Circle) -> Manifold? {
        let delta = o.center - center
        let dist = simd_length(delta)
        let r = radius + o.radius
        guard dist <= r else { return nil }
        let normal = dist > 1e-6 ? delta / dist : SIMD2<Float>(0, 1)
        return Manifold(normal: normal, depth: r - dist, contact: center + normal * radius)
    }

    public func manifold(with o: AABB) -> Manifold? {
        let cp = closestPointOnAABB(center, o)
        let delta = cp - center
        let distSq = simd_length_squared(delta)
        guard distSq <= radius * radius else {
            // Centre may be inside the box (closest point == centre); handle below.
            if o.contains(center) { return manifoldFromInsideAABB(o) }
            return nil
        }
        if distSq > 1e-12 {
            let dist = sqrt(distSq)
            let normal = delta / dist
            return Manifold(normal: normal, depth: radius - dist, contact: center + normal * radius)
        }
        return manifoldFromInsideAABB(o)
    }

    /// Circle centre is inside the box: push out along the nearest face.
    private func manifoldFromInsideAABB(_ o: AABB) -> Manifold {
        let toMinX = center.x - o.min.x, toMaxX = o.max.x - center.x
        let toMinY = center.y - o.min.y, toMaxY = o.max.y - center.y
        let m = min(min(toMinX, toMaxX), min(toMinY, toMaxY))
        let normal: SIMD2<Float>
        if m == toMinX { normal = SIMD2(-1, 0) }
        else if m == toMaxX { normal = SIMD2(1, 0) }
        else if m == toMinY { normal = SIMD2(0, -1) }
        else { normal = SIMD2(0, 1) }
        return Manifold(normal: normal, depth: radius + m, contact: center + normal * radius)
    }

    public func manifold(with o: Capsule) -> Manifold? {
        let cp = closestPointOnSegment(center, o.a, o.b)
        let delta = cp - center
        let dist = simd_length(delta)
        let r = radius + o.radius
        guard dist <= r else { return nil }
        let normal = dist > 1e-6 ? delta / dist : SIMD2<Float>(0, 1)
        return Manifold(normal: normal, depth: r - dist, contact: center + normal * radius)
    }
}

extension AABB {
    public func manifold(with o: Circle) -> Manifold? { flip(o.manifold(with: self)) }

    public func manifold(with o: AABB) -> Manifold? {
        let overlapX = Swift.min(max.x, o.max.x) - Swift.max(min.x, o.min.x)
        let overlapY = Swift.min(max.y, o.max.y) - Swift.max(min.y, o.min.y)
        guard overlapX >= 0 && overlapY >= 0 else { return nil }
        let ca = (min + max) * 0.5
        let cb = (o.min + o.max) * 0.5
        if overlapX < overlapY {
            let sign: Float = cb.x >= ca.x ? 1 : -1
            let contactX = sign > 0 ? max.x : min.x
            let contactY = (Swift.max(min.y, o.min.y) + Swift.min(max.y, o.max.y)) * 0.5
            return Manifold(normal: SIMD2(sign, 0), depth: overlapX, contact: SIMD2(contactX, contactY))
        } else {
            let sign: Float = cb.y >= ca.y ? 1 : -1
            let contactY = sign > 0 ? max.y : min.y
            let contactX = (Swift.max(min.x, o.min.x) + Swift.min(max.x, o.max.x)) * 0.5
            return Manifold(normal: SIMD2(0, sign), depth: overlapY, contact: SIMD2(contactX, contactY))
        }
    }

    public func manifold(with o: Capsule) -> Manifold? {
        let (onSeg, onBox) = segmentAABBClosest(o.a, o.b, self)
        let delta = onSeg - onBox            // from box toward the capsule's spine
        let dist = simd_length(delta)
        guard dist <= o.radius else { return nil }
        // Deep penetration (spine inside the box) gives a near-zero delta; fall back to the
        // box-vs-segment-midpoint direction so the normal stays well defined.
        let normal: SIMD2<Float>
        if dist > 1e-6 {
            normal = delta / dist
        } else {
            let mid = (o.a + o.b) * 0.5
            let c = (min + max) * 0.5
            let d = mid - c
            normal = simd_length(d) > 1e-6 ? simd_normalize(d) : SIMD2(0, 1)
        }
        return Manifold(normal: normal, depth: o.radius - dist, contact: onBox)
    }
}

extension Capsule {
    public func manifold(with o: Circle) -> Manifold? { flip(o.manifold(with: self)) }
    public func manifold(with o: AABB) -> Manifold? { flip(o.manifold(with: self)) }

    public func manifold(with o: Capsule) -> Manifold? {
        let (c1, c2) = segmentSegmentClosest(a, b, o.a, o.b)
        let delta = c2 - c1
        let dist = simd_length(delta)
        let r = radius + o.radius
        guard dist <= r else { return nil }
        let normal = dist > 1e-6 ? delta / dist : SIMD2<Float>(0, 1)
        return Manifold(normal: normal, depth: r - dist, contact: c1 + normal * radius)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter CollisionManifoldTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/Bielik2D/Collision/Manifolds.swift Tests/Bielik2DTests/CollisionManifoldTests.swift
git commit -m "add collision manifold generation for all shape pairs"
```

---

### Task 5: Raycasting

**Files:**
- Create: `Sources/Bielik2D/Collision/Raycast.swift`
- Test: `Tests/Bielik2DTests/CollisionRaycastTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/Bielik2DTests/CollisionRaycastTests.swift`:

```swift
import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

@Test func rayHitsCircle() {
    let ray = Ray(origin: SIMD2(-5, 0), direction: SIMD2(1, 0), length: 100)
    let hit = ray.cast(against: Circle(center: SIMD2(0, 0), radius: 2))
    #expect(hit != nil)
    #expect(abs(hit!.t - 3) < 1e-4)
    #expect(abs(hit!.point.x + 2) < 1e-4)        // (-2, 0)
    #expect(abs(hit!.normal.x + 1) < 1e-4)       // faces back toward origin
}

@Test func rayMissesCircle() {
    let ray = Ray(origin: SIMD2(-5, 10), direction: SIMD2(1, 0), length: 100)
    #expect(ray.cast(against: Circle(center: SIMD2(0, 0), radius: 2)) == nil)
}

@Test func rayTooShortMissesCircle() {
    let ray = Ray(origin: SIMD2(-5, 0), direction: SIMD2(1, 0), length: 2)  // stops at x=-3
    #expect(ray.cast(against: Circle(center: SIMD2(0, 0), radius: 2)) == nil)
}

@Test func rayFromInsideCircleHitsAtZero() {
    let ray = Ray(origin: SIMD2(0, 0), direction: SIMD2(1, 0), length: 100)
    let hit = ray.cast(against: Circle(center: SIMD2(0, 0), radius: 2))
    #expect(hit != nil)
    #expect(abs(hit!.t) < 1e-4)
}

@Test func rayHitsAABB() {
    let ray = Ray(origin: SIMD2(-5, 0), direction: SIMD2(1, 0), length: 100)
    let hit = ray.cast(against: AABB(min: SIMD2(-2, -2), max: SIMD2(2, 2)))
    #expect(hit != nil)
    #expect(abs(hit!.t - 3) < 1e-4)
    #expect(abs(hit!.normal.x + 1) < 1e-4)
}

@Test func rayParallelMissesAABB() {
    let ray = Ray(origin: SIMD2(-5, 9), direction: SIMD2(1, 0), length: 100)
    #expect(ray.cast(against: AABB(min: SIMD2(-2, -2), max: SIMD2(2, 2))) == nil)
}

@Test func rayHitsCapsuleSide() {
    let ray = Ray(origin: SIMD2(0, -5), direction: SIMD2(0, 1), length: 100)
    let hit = ray.cast(against: Capsule(a: SIMD2(-3, 0), b: SIMD2(3, 0), radius: 1))
    #expect(hit != nil)
    #expect(abs(hit!.t - 4) < 1e-4)              // hits y = -1
    #expect(abs(hit!.normal.y + 1) < 1e-4)
}

@Test func rayHitsCapsuleEndCap() {
    let ray = Ray(origin: SIMD2(-10, 0), direction: SIMD2(1, 0), length: 100)
    let hit = ray.cast(against: Capsule(a: SIMD2(-3, 0), b: SIMD2(3, 0), radius: 1))
    #expect(hit != nil)
    #expect(abs(hit!.t - 6) < 1e-4)              // hits the left cap at x = -4
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CollisionRaycastTests`
Expected: FAIL — `value of type 'Ray' has no member 'cast'`.

- [ ] **Step 3: Implement the raycasts**

Create `Sources/Bielik2D/Collision/Raycast.swift`:

```swift
#if canImport(simd)
import simd
#else
import kvSIMD
#endif

extension Ray {
    public func cast(against c: Circle) -> Raycast? {
        let m = origin - c.center
        let b = simd_dot(m, direction)
        let cc = simd_dot(m, m) - c.radius * c.radius
        if cc > 0 && b > 0 { return nil }           // origin outside, pointing away
        let discr = b * b - cc
        if discr < 0 { return nil }                 // ray misses the circle
        var t = -b - sqrt(discr)
        if t < 0 { t = 0 }                          // origin inside the circle
        if t > length { return nil }
        let point = origin + direction * t
        let normal = simd_normalize(point - c.center)
        return Raycast(t: t, point: point, normal: normal)
    }

    public func cast(against box: AABB) -> Raycast? {
        var tmin: Float = 0
        var tmax: Float = length
        var hitNormal = SIMD2<Float>(0, 0)
        for axis in 0..<2 {
            let o = origin[axis], d = direction[axis]
            let lo = box.min[axis], hi = box.max[axis]
            if abs(d) < 1e-8 {
                if o < lo || o > hi { return nil }  // parallel and outside the slab
            } else {
                let inv = 1 / d
                var t1 = (lo - o) * inv
                var t2 = (hi - o) * inv
                var n: SIMD2<Float> = axis == 0 ? SIMD2(-1, 0) : SIMD2(0, -1)
                if t1 > t2 { swap(&t1, &t2); n = -n }
                if t1 > tmin { tmin = t1; hitNormal = n }
                if t2 < tmax { tmax = t2 }
                if tmin > tmax { return nil }
            }
        }
        return Raycast(t: tmin, point: origin + direction * tmin, normal: hitNormal)
    }

    public func cast(against cap: Capsule) -> Raycast? {
        var best: Raycast? = nil
        func consider(_ r: Raycast?) {
            if let r, best == nil || r.t < best!.t { best = r }
        }
        consider(cast(against: Circle(center: cap.a, radius: cap.radius)))
        consider(cast(against: Circle(center: cap.b, radius: cap.radius)))
        let axis = cap.b - cap.a
        let len = simd_length(axis)
        if len > 1e-6 {
            let n = SIMD2<Float>(-axis.y, axis.x) / len
            for s in [Float(1), Float(-1)] {
                let off = n * (cap.radius * s)
                consider(raySegment(cap.a + off, cap.b + off, sideNormal: n * s))
            }
        }
        return best
    }

    /// Ray vs a thin segment `p0`→`p1`. `sideNormal` is the outward normal returned on hit.
    private func raySegment(_ p0: SIMD2<Float>, _ p1: SIMD2<Float>,
                            sideNormal: SIMD2<Float>) -> Raycast? {
        let e = p1 - p0
        let denom = direction.x * e.y - direction.y * e.x   // cross(direction, e)
        if abs(denom) < 1e-8 { return nil }                 // parallel
        let diff = p0 - origin
        let t = (diff.x * e.y - diff.y * e.x) / denom        // distance along the ray
        let u = (diff.x * direction.y - diff.y * direction.x) / denom  // param along segment
        if t < 0 || t > length || u < 0 || u > 1 { return nil }
        return Raycast(t: t, point: origin + direction * t, normal: sideNormal)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter CollisionRaycastTests`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/Bielik2D/Collision/Raycast.swift Tests/Bielik2DTests/CollisionRaycastTests.swift
git commit -m "add collision raycasting against circle, aabb, and capsule"
```

---

### Task 6: Capsule SDF shader branch

**Files:**
- Modify: `Sources/Bielik2D/Draw/Primitives.swift` (the `ShapeType` enum near the top, lines 10-15)
- Modify: `Shaders/src/sprite.frag.hlsl` (add a `t == 4` branch after the `t == 3` box branch, ~line 106)
- Modify: `Shaders/wgsl/sprite.frag.wgsl` (add a `t == 4` branch after the `t == 3` box branch, ~line 106)

This task changes shaders and an enum; it is verified by building, not a unit test (the draw-side test is Task 7).

- [ ] **Step 1: Add the `capsule` case to `ShapeType`**

In `Sources/Bielik2D/Draw/Primitives.swift`, change the enum:

```swift
public enum ShapeType: Float {
    case sprite = 0
    case circle = 1
    case line = 2
    case box = 3
    case capsule = 4
}
```

- [ ] **Step 2: Add the capsule branch to the HLSL fragment shader**

In `Shaders/src/sprite.frag.hlsl`, immediately after the closing `}` of the `if (t == 3)` block and before the final `// unknown type` return, insert:

```hlsl
    if (t == 4) {
        // Capsule: segment along local x in [-halfLen, halfLen], rounded by `radius`.
        // uv is in capsule-local world coords; scaleData.x = halfLen.
        float halfLen = input.scaleData.x;
        float dx = abs(input.uv.x) - halfLen;
        float dist = length(float2(max(dx, 0.0), input.uv.y)) - input.radius;
        float a;
        if (input.fill > 0.5) {
            a = smoothstep(input.aa, -input.aa, dist);
        } else {
            a = smoothstep(input.stroke * 0.5 + input.aa,
                           input.stroke * 0.5 - input.aa, abs(dist));
        }
        return float4(input.color.rgb, input.color.a * a);
    }
```

- [ ] **Step 3: Add the matching branch to the WGSL fragment shader**

In `Shaders/wgsl/sprite.frag.wgsl`, immediately after the closing `}` of the `if (t == 3)` block and before the final `return in.color;`, insert:

```wgsl
    if (t == 4) {
        // Capsule: segment along local x in [-halfLen, halfLen], rounded by `radius`.
        // uv is in capsule-local world coords; scaleData.x = halfLen.
        let halfLen = in.scaleData.x;
        let dx = abs(in.uv.x) - halfLen;
        let dist = length(vec2<f32>(max(dx, 0.0), in.uv.y)) - in.radius;
        var a: f32;
        if (in.fill > 0.5) {
            a = smoothstep(in.aa, -in.aa, dist);
        } else {
            let halfStroke = in.stroke * 0.5;
            a = smoothstep(halfStroke + in.aa, halfStroke - in.aa, abs(dist));
        }
        return vec4<f32>(in.color.rgb, in.color.a * a);
    }
```

- [ ] **Step 4: Recompile shaders**

Run: `bash Shaders/build.sh`
Expected: prints `==> done` with `sprite.frag.hlsl -> sprite.frag.spv` and `override sprite.frag.wgsl` lines, no errors. (The `naga skipped sprite.frag.spv` warning is normal — the WGSL override is used.)

- [ ] **Step 5: Verify the build compiles**

Run: `swift build -c release --product Bielik2DDemo`
Expected: `Build of product 'Bielik2DDemo' complete!` (ld dylib version warnings are pre-existing and harmless).

- [ ] **Step 6: Commit**

```bash
git add Sources/Bielik2D/Draw/Primitives.swift Shaders/src/sprite.frag.hlsl Shaders/wgsl/sprite.frag.wgsl Sources/Bielik2D/Resources/shaders/sprite.frag.spv Sources/Bielik2D/Resources/shaders/sprite.frag.wgsl
git commit -m "add capsule SDF branch to sprite fragment shader"
```

---

### Task 7: Capsule draw primitive and debug-draw

**Files:**
- Modify: `Sources/Bielik2D/Draw/Primitives.swift` (add `capsule(...)` and `debug(...)` methods inside the `extension Draw`)
- Test: `Tests/Bielik2DTests/CapsulePrimitiveTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/Bielik2DTests/CapsulePrimitiveTests.swift`:

```swift
import Testing
#if canImport(simd)
import simd
#else
import kvSIMD
#endif
@testable import Bielik2D

@Test func capsuleEmitsQuadWithCapsuleType() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.capsule(from: SIMD2(0, 0), to: SIMD2(100, 0), radius: 10, color: .white)
    #expect(b.vertices.count == 6)
    let v = b.vertices.first!
    #expect(v.type == ShapeType.capsule.rawValue)
    #expect(v.radius == 10)
    #expect(v.fill == 1)                          // stroke 0 -> filled
    #expect(abs(v.attributes.x - 50) < 1e-4)      // halfLen = length/2
}

@Test func capsuleStrokeMarksOutline() {
    let b = Batcher()
    Draw(batcher: b).capsule(from: SIMD2(0, 0), to: SIMD2(10, 0), radius: 4, stroke: 2)
    #expect(b.vertices.first!.fill == 0)          // stroke > 0 -> outline
    #expect(b.vertices.first!.stroke == 2)
}

@Test func capsuleQuadExtendsByRadiusPlusAA() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.capsule(from: SIMD2(0, 0), to: SIMD2(100, 0), radius: 10, color: .white, aa: 1)
    let xs = b.vertices.map(\.pos.x)
    let ys = b.vertices.map(\.pos.y)
    // Axis x extends radius+aa past each endpoint; perpendicular y spans radius+aa.
    #expect(abs(xs.min()! - (-11)) < 1e-3)
    #expect(abs(xs.max()! - 111) < 1e-3)
    #expect(abs(ys.min()! - (-11)) < 1e-3)
    #expect(abs(ys.max()! - 11) < 1e-3)
}

@Test func debugDrawCircleEmitsRing() {
    let b = Batcher()
    Draw(batcher: b).debug(Circle(center: SIMD2(0, 0), radius: 5))
    // A circle ring is drawn via a zero-length stroked capsule.
    #expect(b.vertices.first!.type == ShapeType.capsule.rawValue)
    #expect(b.vertices.first!.radius == 5)
    #expect(b.vertices.first!.fill == 0)   // stroked outline, not filled
}

@Test func debugDrawAABBEmitsBox() {
    let b = Batcher()
    Draw(batcher: b).debug(AABB(min: SIMD2(0, 0), max: SIMD2(4, 4)))
    #expect(b.vertices.first!.type == ShapeType.box.rawValue)
}

@Test func debugDrawCapsuleEmitsCapsule() {
    let b = Batcher()
    Draw(batcher: b).debug(Capsule(a: SIMD2(0, 0), b: SIMD2(10, 0), radius: 2))
    #expect(b.vertices.first!.type == ShapeType.capsule.rawValue)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CapsulePrimitiveTests`
Expected: FAIL — `value of type 'Draw' has no member 'capsule'`.

- [ ] **Step 3: Implement `capsule` and `debug`**

In `Sources/Bielik2D/Draw/Primitives.swift`, inside `extension Draw` (after the `line(...)` method, before the `// MARK: - Internal SDF emission helpers` comment), add:

```swift
    /// Filled or outlined capsule: a segment `a`→`b` with rounded ends of `radius`.
    /// `stroke` 0 fills; `> 0` draws an outline of that thickness centred on the boundary.
    public func capsule(from a: SIMD2<Float>, to b: SIMD2<Float>, radius: Float,
                        stroke: Float = 0, color: Color = .white,
                        aa: Float = 1.5 / Draw.ambientPixelDensity) {
        let dir = b - a
        let len = simd_length(dir)
        let d = len > 1e-6 ? dir / len : SIMD2<Float>(1, 0)
        let n = SIMD2<Float>(-d.y, d.x)
        let halfLen = len * 0.5
        // Round caps reach `radius` past each endpoint; add `aa` for the fade and the
        // stroke half-width that spills outside the boundary when stroked.
        let pad = radius + (stroke > 0 ? stroke * 0.5 : 0) + aa
        let halfBand = pad
        let tint = currentColor
        let modulated = SIMD4<Float>(color.r * tint.r, color.g * tint.g,
                                     color.b * tint.b, color.a * tint.a)
        let t = currentTransform
        let mid = (a + b) * 0.5
        let tp0 = t.transform(mid - d * (halfLen + pad) + n * halfBand)
        let tp1 = t.transform(mid + d * (halfLen + pad) + n * halfBand)
        let tp2 = t.transform(mid + d * (halfLen + pad) - n * halfBand)
        let tp3 = t.transform(mid - d * (halfLen + pad) - n * halfBand)
        let uvTL = SIMD2<Float>(-(halfLen + pad),  halfBand)
        let uvTR = SIMD2<Float>( (halfLen + pad),  halfBand)
        let uvBR = SIMD2<Float>( (halfLen + pad), -halfBand)
        let uvBL = SIMD2<Float>(-(halfLen + pad), -halfBand)
        emitSDFQuadCorners(
            p0: tp0, uv0: uvTL,
            p1: tp1, uv1: uvTR,
            p2: tp2, uv2: uvBR,
            p3: tp3, uv3: uvBL,
            type: .capsule, color: modulated,
            radius: radius, stroke: stroke, aa: aa, fill: stroke <= 0 ? 1 : 0,
            attributes: SIMD4<Float>(halfLen, 0, 0, 0)
        )
    }

    /// Debug-draw a collision circle as a thin ring. A zero-length stroked capsule is a
    /// ring of the given radius, so it reuses the capsule path (no stroked-circle branch needed).
    public func debug(_ c: Circle, color: Color = Color(r: 0, g: 1, b: 0),
                      stroke: Float = 1) {
        capsule(from: c.center, to: c.center, radius: c.radius, stroke: stroke, color: color)
    }

    /// Debug-draw a collision AABB as a thin box outline.
    public func debug(_ b: AABB, color: Color = Color(r: 0, g: 1, b: 0),
                      stroke: Float = 1) {
        box(b.rect, stroke: stroke, color: color)
    }

    /// Debug-draw a collision capsule as a thin outline.
    public func debug(_ cap: Capsule, color: Color = Color(r: 0, g: 1, b: 0),
                      stroke: Float = 1) {
        capsule(from: cap.a, to: cap.b, radius: cap.radius, stroke: stroke, color: color)
    }
```

Note: `debug(_ c: Circle)` is implemented as a zero-length stroked capsule, which renders as a ring of `c.radius` — this avoids a separate stroked-circle path. The `debugDrawCircleEmitsRing` test in Step 1 already expects this.

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter CapsulePrimitiveTests`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/Bielik2D/Draw/Primitives.swift Tests/Bielik2DTests/CapsulePrimitiveTests.swift
git commit -m "add capsule draw primitive and collision debug-draw"
```

---

### Task 8: Demo showcase and full verification

**Files:**
- Modify: `Sources/Bielik2DDemo/main.swift` (add a capsule + a manifold push-out showcase in the main pass, near the other primitive draws around line 113)

- [ ] **Step 1: Add a capsule and a push-out resolution showcase to the demo**

In `Sources/Bielik2DDemo/main.swift`, after the existing `draw.line(...)` call (around line 115), add:

```swift
    // Collision showcase: a static box obstacle, and a dot driven toward it that gets
    // pushed back out along the manifold normal so it never penetrates.
    let obstacle = AABB(min: SIMD2(200, 250), max: SIMD2(320, 330))
    draw.debug(obstacle, color: Color(r: 0.4, g: 1.0, b: 0.5))
    draw.capsule(from: SIMD2(360, 250), to: SIMD2(460, 330), radius: 16,
                 color: Color(r: 0.7, g: 0.5, b: 1.0))
    var probe = Circle(center: SIMD2(260 + sin(t) * 120, 290), radius: 18)
    if let m = obstacle.manifold(with: probe) {
        probe.center += m.normal * m.depth        // resolve out of the box
    }
    draw.circleFill(center: probe.center, radius: probe.radius,
                    color: Color(r: 1.0, g: 0.85, b: 0.2))
```

- [ ] **Step 2: Build the demo in release**

Run: `swift build -c release --product Bielik2DDemo`
Expected: `Build of product 'Bielik2DDemo' complete!`

- [ ] **Step 3: Run the full test suite**

Run: `swift test`
Expected: all tests pass, including the five new collision/primitive test files.

- [ ] **Step 4: Commit**

```bash
git add Sources/Bielik2DDemo/main.swift
git commit -m "showcase collision manifold push-out and capsule in the demo"
```

- [ ] **Step 5: Update TODO.md and FEATURES.md status**

In `TODO.md`, change the Phase 18 heading from `## Phase 18 — Collision: 2D shapes + queries ⏳` to `🟡` and check the boxes that are now done (`Circle`/`AABB`/`Capsule`/`Ray`, `overlap`→`manifold`→`raycast`, debug-draw). Leave `gjk`/`toi`/poly/hull unchecked with a note they're deferred.

In `FEATURES.md`, change the `collision` row from `⏳` to `🟡` with a note: "Circle/AABB/Capsule overlap + manifold + raycast shipped; Poly, GJK, TOI, hull deferred." Update the summary counts (shipped/partial/planned) accordingly.

- [ ] **Step 6: Commit**

```bash
git add TODO.md FEATURES.md
git commit -m "mark collision core shipped in TODO and FEATURES"
```

---

## Self-Review notes

- **Spec coverage:** shapes (Task 1), closest-point helpers (Task 2), six overlap pairs (Task 3), six manifold pairs incl. reverse-negation (Task 4), three raycasts (Task 5), capsule SDF shader (Task 6), capsule + debug-draw (Task 7), demo + verification + status docs (Task 8). All spec sections map to a task.
- **Manifold normal convention** (self→other, push self by `-normal*depth`) is consistent across Task 4 and the demo in Task 8.
- **`attributes.x = halfLen`** carries the capsule axis length, read as `scaleData.x` in the shader (the vertex shader copies `attributes`→`scaleData`), consistent between Task 6 (shader) and Task 7 (emission) — matching the existing box/line setup.
- **Known limitation (documented):** AABB–Capsule manifold uses a fallback normal under deep penetration (spine fully inside the box); acceptable for focused-core v1, GJK would supersede it later.
