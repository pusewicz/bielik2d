# Draw Shape Primitives Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the missing CF-parity draw primitives (outline circle, triangle, polyline, polygon outline, boxFill) plus an ambient shape-AA stack, keeping every shape crisply anti-aliased on the existing unified SDF pipeline.

**Architecture:** Extend `Sources/Bielik2D/Draw/Primitives.swift`, reusing the `ShapeType` discriminator and `emitSDFQuadCorners`. Filled triangle gets one new SDF shader branch; outline circle reuses the `circle` branch with a new stroked path. Polyline / polygon outline / stroked triangle are pure Swift built from the existing `capsule` shape (no shader change). Shaders are HLSL (→ SPIR-V via `glslangValidator`) with a hand-written WGSL counterpart, both rebuilt by `Shaders/build.sh`.

**Tech Stack:** Swift 6.3, SDL3 GPU, swift-testing, HLSL + WGSL SDF shaders.

**Working directory:** All commands assume the worktree at `/Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes` (branch `draw-shapes`). Run `swift` with `--package-path /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes`.

**Conventions:** TDD red-green per the project. One atomic commit per task; each builds and `swift test` passes. Human-voice commit messages (lowercase imperative, no Conventional-Commits prefix, no AI signoff).

---

### Task 1: Ambient shape-AA stack

Adds `pushShapeAA`/`popShapeAA` + a `shapeAA:` axis on `with`, and makes the existing primitives read the ambient AA when no explicit `aa:` is passed. Default-arg values can't reference `self`, so each primitive's `aa` becomes `Float? = nil`, resolved to `currentShapeAA` inside.

**Files:**
- Modify: `Sources/Bielik2D/Draw/Draw.swift`
- Modify: `Sources/Bielik2D/Draw/Primitives.swift`
- Test: `Tests/Bielik2DTests/ShapeAATests.swift` (create)

- [ ] **Step 1: Write the failing test**

Create `Tests/Bielik2DTests/ShapeAATests.swift`:

```swift
import Testing
@testable import Bielik2D

@Test func shapeAADefaultsToOnePointFiveOverDensity() {
    let saved = Draw.ambientPixelDensity
    defer { Draw.ambientPixelDensity = saved }
    Draw.ambientPixelDensity = 1.0
    let d = Draw(batcher: Batcher())
    #expect(d.currentShapeAA == 1.5)
}

@Test func pushShapeAAOverridesPrimitiveAA() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.pushShapeAA(3.0)
    d.circleFill(center: .zero, radius: 10)
    #expect(b.vertices.first!.aa == 3.0)
    d.popShapeAA()
}

@Test func withShapeAAScopesAndRestores() {
    let b = Batcher()
    let d = Draw(batcher: b)
    let before = d.currentShapeAA
    d.with(shapeAA: 4.0) {
        d.box(Rect(x: 0, y: 0, width: 10, height: 10))
    }
    #expect(b.vertices.first!.aa == 4.0)
    #expect(d.currentShapeAA == before)
}

@Test func explicitAAStillWins() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.pushShapeAA(3.0)
    d.circleFill(center: .zero, radius: 10, aa: 0.5)
    #expect(b.vertices.first!.aa == 0.5)
    d.popShapeAA()
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes --filter ShapeAA`
Expected: FAIL to compile — `currentShapeAA`, `pushShapeAA`, `with(shapeAA:)` don't exist.

- [ ] **Step 3: Add the shapeAA stack to `Draw.swift`**

In `Sources/Bielik2D/Draw/Draw.swift`, add a stored property with a default initializer alongside the other stacks (after `private var scaleModes = StateStack(initial: ScaleMode.default)`). This matches the existing `transforms`/`colors` style; `Draw.ambientPixelDensity` is a static, so it's legal in a property initializer (no `self`), and the value is captured per-instance at construction:

```swift
    private var shapeAAs = StateStack(initial: 1.5 / Draw.ambientPixelDensity)
```

Add the accessors after the scale-mode section (after `public var currentScaleMode: ScaleMode { scaleModes.peek }`):

```swift
    // MARK: - Shape anti-aliasing (ambient default for SDF primitives)

    /// Sets the ambient AA band (world units) that SDF primitives use when their
    /// `aa:` argument is omitted. Defaults to `1.5 / ambientPixelDensity`.
    public func pushShapeAA(_ aa: Float) {
        shapeAAs.push(aa)
    }

    public func popShapeAA() {
        _ = shapeAAs.pop()
    }

    public var currentShapeAA: Float { shapeAAs.peek }
```

Extend the `with` helper: add the parameter to the signature

```swift
    public func with<R>(transform: Mat3x2? = nil,
                        color: Color? = nil,
                        layer: Int? = nil,
                        scaleMode: ScaleMode? = nil,
                        shapeAA: Float? = nil,
                        _ body: () throws -> R) rethrows -> R {
```

push it after the scaleMode push:

```swift
        if let scaleMode { pushScaleMode(scaleMode) }
        if let shapeAA { pushShapeAA(shapeAA) }
```

and pop it first in the `defer` (reverse order):

```swift
        defer {
            if shapeAA != nil { popShapeAA() }
            if scaleMode != nil { popScaleMode() }
            if layer != nil { popLayer() }
            if color != nil { popColor() }
            if transform != nil { popTransform() }
        }
```

- [ ] **Step 4: Make existing primitives resolve ambient AA in `Primitives.swift`**

For each of `circleFill`, `box`, `line`, `capsule`, change the `aa` parameter from
`aa: Float = 1.5 / Draw.ambientPixelDensity` to `aa: Float? = nil`, and resolve it on the first
line of the body.

`circleFill` — signature becomes:
```swift
    public func circleFill(center: SIMD2<Float>, radius: Float, color: Color = .white, aa: Float? = nil) {
        let aa = aa ?? currentShapeAA
```
`box` — signature becomes:
```swift
    public func box(_ rect: Rect, stroke: Float = 0, cornerRadius: Float = 0,
                    color: Color = .white, aa: Float? = nil) {
        let aa = aa ?? currentShapeAA
```
`line` — signature becomes:
```swift
    public func line(from a: SIMD2<Float>, to b: SIMD2<Float>, thickness: Float,
                     color: Color = .white, aa: Float? = nil) {
        let aa = aa ?? currentShapeAA
```
`capsule` — signature becomes:
```swift
    public func capsule(from a: SIMD2<Float>, to b: SIMD2<Float>, radius: Float,
                        stroke: Float = 0, color: Color = .white, aa: Float? = nil) {
        let aa = aa ?? currentShapeAA
```
(In each, insert `let aa = aa ?? currentShapeAA` as the first statement; the rest of each body is unchanged and keeps using the now-non-optional local `aa`.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --package-path /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes --filter ShapeAA`
Expected: PASS (4 tests). Then run the existing primitives suite to confirm no regression:
Run: `swift test --package-path /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes --filter Primitives`
Expected: PASS (the `circleFillAAScalesWithPixelDensity` test still holds — default resolves to `1.5/density`).

- [ ] **Step 6: Commit**

```bash
git -C /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes add -A
git -C /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes commit -m "add ambient shape-aa stack read by sdf primitives"
```

---

### Task 2: Outline circle

Adds `Draw.circle(center:radius:thickness:)`, a crisp ring. Reuses `ShapeType.circle` with `fill: 0`; the circle shader branch gains a stroked path (it is fill-only today).

**Files:**
- Modify: `Shaders/src/sprite.frag.hlsl` (circle branch)
- Modify: `Shaders/wgsl/sprite.frag.wgsl` (circle branch)
- Modify: `Sources/Bielik2D/Draw/Primitives.swift`
- Test: `Tests/Bielik2DTests/PrimitivesTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `Tests/Bielik2DTests/PrimitivesTests.swift`:

```swift
@Test func circleOutlineEmitsStrokedCircleParams() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.circle(center: SIMD2<Float>(50, 50), radius: 20, thickness: 4, color: .white)
    #expect(b.vertices.count == 6)
    let v = b.vertices.first!
    #expect(v.type == ShapeType.circle.rawValue)
    #expect(v.fill == 0)
    #expect(v.stroke == 4)
    #expect(v.radius == 20)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes --filter circleOutlineEmitsStrokedCircleParams`
Expected: FAIL to compile — `circle(center:radius:thickness:)` doesn't exist.

- [ ] **Step 3: Add `Draw.circle` to `Primitives.swift`**

Add after `circleFill`:

```swift
    /// Antialiased circle outline of the given `thickness`, centred on the radius.
    public func circle(center: SIMD2<Float>, radius: Float, thickness: Float,
                       color: Color = .white, aa: Float? = nil) {
        let aa = aa ?? currentShapeAA
        // Quad must reach the outer edge of the stroke plus the AA fringe.
        let pad = thickness * 0.5 + aa
        let extent = radius + pad
        let bounds = Rect(x: center.x - extent, y: center.y - extent,
                          width: 2 * extent, height: 2 * extent)
        emitSDFQuad(type: .circle, bounds: bounds, color: color,
                    localExtent: extent, radius: radius, stroke: thickness, aa: aa, fill: 0)
    }
```

- [ ] **Step 4: Add the stroked path to the circle branch — HLSL**

In `Shaders/src/sprite.frag.hlsl`, replace the `if (t == 1) { ... }` block with:

```hlsl
    if (t == 1) {
        // circle: distance from uv origin in local-extent units.
        float d = length(input.uv);
        float a;
        if (input.fill > 0.5) {
            // filled disk: opaque inside, AA at the outer edge
            a = smoothstep(input.radius + input.aa, input.radius - input.aa, d);
        } else {
            // outline: opaque band of `stroke` width centred on the radius
            a = smoothstep(input.stroke * 0.5 + input.aa,
                           input.stroke * 0.5 - input.aa, abs(d - input.radius));
        }
        return float4(input.color.rgb, input.color.a * a);
    }
```

- [ ] **Step 5: Add the stroked path to the circle branch — WGSL**

In `Shaders/wgsl/sprite.frag.wgsl`, replace the `if (t == 1) { ... }` block with:

```wgsl
    if (t == 1) {
        let d = length(in.uv);
        var a: f32;
        if (in.fill > 0.5) {
            a = smoothstep(in.radius + in.aa, in.radius - in.aa, d);
        } else {
            let halfStroke = in.stroke * 0.5;
            a = smoothstep(halfStroke + in.aa, halfStroke - in.aa, abs(d - in.radius));
        }
        return vec4<f32>(in.color.rgb, in.color.a * a);
    }
```

- [ ] **Step 6: Rebuild shaders**

Run: `bash /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes/Shaders/build.sh`
Expected: prints `sprite.frag.hlsl -> sprite.frag.spv` and `override sprite.frag.wgsl`, no errors. This regenerates `Sources/Bielik2D/Resources/shaders/sprite.frag.spv` and copies the WGSL override.

- [ ] **Step 7: Run test to verify it passes**

Run: `swift test --package-path /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes --filter circleOutlineEmitsStrokedCircleParams`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git -C /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes add -A
git -C /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes commit -m "add outline circle via stroked circle sdf branch"
```

---

### Task 3: Filled triangle (SDF)

Adds `ShapeType.triangle = 5`, a new shader branch using Inigo Quilez's `sdTriangle`, and `Draw.tri(a,b,c)`. The three triangle corners (in a centroid-local frame) are packed into the free vertex channels: `attributes.xy = a-centroid`, `attributes.zw = b-centroid`, `uvBounds.xy = c-centroid`. `emitSDFQuadCorners` gains a `uvBounds:` parameter to carry the third corner.

**Files:**
- Modify: `Sources/Bielik2D/Draw/Primitives.swift` (ShapeType, `emitSDFQuadCorners`, `tri`)
- Modify: `Shaders/src/sprite.frag.hlsl` (sdTriangle helper + branch)
- Modify: `Shaders/wgsl/sprite.frag.wgsl` (sdTriangle helper + branch)
- Test: `Tests/Bielik2DTests/PrimitivesTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `Tests/Bielik2DTests/PrimitivesTests.swift`:

```swift
@Test func triFilledPacksCornersIntoVertexChannels() {
    let b = Batcher()
    let d = Draw(batcher: b)
    let a = SIMD2<Float>(0, 0), bb = SIMD2<Float>(30, 0), c = SIMD2<Float>(0, 30)
    d.tri(a, bb, c)
    #expect(b.vertices.count == 6)
    let v = b.vertices.first!
    #expect(v.type == ShapeType.triangle.rawValue)
    #expect(v.fill == 1)
    let centroid = (a + bb + c) / 3
    #expect(abs(v.attributes.x - (a.x - centroid.x)) < 1e-3)
    #expect(abs(v.attributes.y - (a.y - centroid.y)) < 1e-3)
    #expect(abs(v.attributes.z - (bb.x - centroid.x)) < 1e-3)
    #expect(abs(v.attributes.w - (bb.y - centroid.y)) < 1e-3)
    #expect(abs(v.uvBounds.x - (c.x - centroid.x)) < 1e-3)
    #expect(abs(v.uvBounds.y - (c.y - centroid.y)) < 1e-3)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes --filter triFilledPacksCornersIntoVertexChannels`
Expected: FAIL to compile — `ShapeType.triangle` and `tri` don't exist.

- [ ] **Step 3: Add the `triangle` ShapeType case**

In `Sources/Bielik2D/Draw/Primitives.swift`, extend the enum:

```swift
public enum ShapeType: Float {
    case sprite = 0
    case circle = 1
    case line = 2
    case box = 3
    case capsule = 4
    case triangle = 5
}
```

- [ ] **Step 4: Add a `uvBounds` parameter to `emitSDFQuadCorners`**

In `Primitives.swift`, change the `emitSDFQuadCorners` signature to add `uvBounds` after `attributes`:

```swift
    private func emitSDFQuadCorners(
        p0: SIMD2<Float>, uv0: SIMD2<Float>,
        p1: SIMD2<Float>, uv1: SIMD2<Float>,
        p2: SIMD2<Float>, uv2: SIMD2<Float>,
        p3: SIMD2<Float>, uv3: SIMD2<Float>,
        type: ShapeType, color: SIMD4<Float>,
        radius: Float, stroke: Float, aa: Float, fill: Float,
        attributes: SIMD4<Float> = .zero,
        uvBounds: SIMD4<Float> = .zero
    ) {
```

and forward it in the inner `v` builder:

```swift
        func v(_ p: SIMD2<Float>, _ uv: SIMD2<Float>) -> Vertex {
            Vertex(pos: p, uv: uv, color: color,
                   radius: radius, stroke: stroke, aa: aa, type: type.rawValue,
                   alpha: 1, fill: fill, attributes: attributes, uvBounds: uvBounds)
        }
```

- [ ] **Step 5: Add `Draw.tri` (filled) to `Primitives.swift`**

Add after `capsule` (before the debug helpers):

```swift
    /// Filled triangle with antialiased edges (SDF). Pass `stroke:` (Task 4) for an outline.
    public func tri(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>,
                    color: Color = .white, aa: Float? = nil) {
        let aa = aa ?? currentShapeAA
        // Work in a centroid-local frame so uv and the packed corners share an origin.
        let centroid = (a + b + c) / 3
        let la = a - centroid, lb = b - centroid, lc = c - centroid
        let minX = min(la.x, min(lb.x, lc.x)), maxX = max(la.x, max(lb.x, lc.x))
        let minY = min(la.y, min(lb.y, lc.y)), maxY = max(la.y, max(lb.y, lc.y))
        let pad = aa  // AA fringe around the triangle's bounding box
        let qx0 = minX - pad, qx1 = maxX + pad
        let qy0 = minY - pad, qy1 = maxY + pad
        let tint = currentColor
        let modulated = SIMD4<Float>(color.r * tint.r, color.g * tint.g,
                                     color.b * tint.b, color.a * tint.a)
        let t = currentTransform
        let p0 = t.transform(centroid + SIMD2(qx0, qy0))
        let p1 = t.transform(centroid + SIMD2(qx1, qy0))
        let p2 = t.transform(centroid + SIMD2(qx1, qy1))
        let p3 = t.transform(centroid + SIMD2(qx0, qy1))
        emitSDFQuadCorners(
            p0: p0, uv0: SIMD2(qx0, qy0),
            p1: p1, uv1: SIMD2(qx1, qy0),
            p2: p2, uv2: SIMD2(qx1, qy1),
            p3: p3, uv3: SIMD2(qx0, qy1),
            type: .triangle, color: modulated,
            radius: 0, stroke: 0, aa: aa, fill: 1,
            attributes: SIMD4<Float>(la.x, la.y, lb.x, lb.y),
            uvBounds: SIMD4<Float>(lc.x, lc.y, 0, 0)
        )
    }
```

- [ ] **Step 6: Add `sdTriangle` + the triangle branch — HLSL**

In `Shaders/src/sprite.frag.hlsl`, add the helper after `sdRoundBox`:

```hlsl
// Signed distance to the triangle (a, b, c). Negative inside. (Inigo Quilez.)
float sdTriangle(float2 p, float2 a, float2 b, float2 c) {
    float2 e0 = b - a, e1 = c - b, e2 = a - c;
    float2 v0 = p - a, v1 = p - b, v2 = p - c;
    float2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    float2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    float2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
    float s = sign(e0.x * e2.y - e0.y * e2.x);
    float2 d = min(min(float2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
                       float2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
                       float2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}
```

and add the branch after the `t == 4` block (before the trailing `return input.color;`):

```hlsl
    if (t == 5) {
        // triangle: corners packed scaleData.xy = a, scaleData.zw = b, uvBounds.xy = c.
        float2 a = input.scaleData.xy;
        float2 b = input.scaleData.zw;
        float2 c = input.uvBounds.xy;
        float dist = sdTriangle(input.uv, a, b, c);
        float al = smoothstep(input.aa, -input.aa, dist);
        return float4(input.color.rgb, input.color.a * al);
    }
```

- [ ] **Step 7: Add `sdTriangle` + the triangle branch — WGSL**

In `Shaders/wgsl/sprite.frag.wgsl`, add the helper after `sdRoundBox`:

```wgsl
// Signed distance to the triangle (a, b, c). Negative inside. (Inigo Quilez.)
fn sdTriangle(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>, c: vec2<f32>) -> f32 {
    let e0 = b - a; let e1 = c - b; let e2 = a - c;
    let v0 = p - a; let v1 = p - b; let v2 = p - c;
    let pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
    let pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
    let pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
    let s = sign(e0.x * e2.y - e0.y * e2.x);
    let d = min(min(vec2<f32>(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
                    vec2<f32>(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
                    vec2<f32>(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}
```

and add the branch before the trailing `return in.color;`:

```wgsl
    if (t == 5) {
        let a = in.scaleData.xy;
        let b = in.scaleData.zw;
        let c = in.uvBounds.xy;
        let dist = sdTriangle(in.uv, a, b, c);
        let al = smoothstep(in.aa, -in.aa, dist);
        return vec4<f32>(in.color.rgb, in.color.a * al);
    }
```

- [ ] **Step 8: Rebuild shaders**

Run: `bash /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes/Shaders/build.sh`
Expected: no errors; `sprite.frag.spv` regenerated and `sprite.frag.wgsl` override copied.

- [ ] **Step 9: Run test to verify it passes**

Run: `swift test --package-path /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes --filter triFilledPacksCornersIntoVertexChannels`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git -C /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes add -A
git -C /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes commit -m "add filled triangle sdf primitive"
```

---

### Task 4: Polyline, polygon outline, stroked triangle

Pure Swift over the existing `capsule` (filled capsule of radius `thickness/2` = a thick line with round caps; consecutive capsules share endpoints → round joins). `poly` and stroked `tri` are closed polylines.

**Files:**
- Modify: `Sources/Bielik2D/Draw/Primitives.swift`
- Test: `Tests/Bielik2DTests/PrimitivesTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `Tests/Bielik2DTests/PrimitivesTests.swift`:

```swift
@Test func polylineEmitsOneCapsulePerSegment() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.polyline([SIMD2<Float>(0, 0), SIMD2<Float>(10, 0), SIMD2<Float>(10, 10)], thickness: 4)
    // 3 points -> 2 segments -> 2 capsules -> 12 vertices, all capsule type.
    #expect(b.vertices.count == 12)
    #expect(b.vertices.allSatisfy { $0.type == ShapeType.capsule.rawValue })
}

@Test func closedPolylineWrapsBackToStart() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.polyline([SIMD2<Float>(0, 0), SIMD2<Float>(10, 0), SIMD2<Float>(10, 10)],
               thickness: 4, closed: true)
    // 3 segments (incl. closing edge) -> 18 vertices.
    #expect(b.vertices.count == 18)
}

@Test func polyOutlineIsAClosedPolyline() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.poly([SIMD2<Float>(0, 0), SIMD2<Float>(20, 0), SIMD2<Float>(10, 20)], stroke: 2)
    #expect(b.vertices.count == 18)  // 3 segments
    #expect(b.vertices.allSatisfy { $0.type == ShapeType.capsule.rawValue })
}

@Test func strokedTriIsAClosedThreeSegmentOutline() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.tri(SIMD2<Float>(0, 0), SIMD2<Float>(20, 0), SIMD2<Float>(10, 20), stroke: 2)
    #expect(b.vertices.count == 18)
    #expect(b.vertices.allSatisfy { $0.type == ShapeType.capsule.rawValue })
}

@Test func polylineWithFewerThanTwoPointsEmitsNothing() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.polyline([SIMD2<Float>(5, 5)], thickness: 4)
    #expect(b.vertices.isEmpty)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes --filter olyline`
Expected: FAIL to compile — `polyline`, `poly`, and the `tri(stroke:)` overload don't exist.

- [ ] **Step 3: Add `polyline`, `poly`, and stroked `tri` to `Primitives.swift`**

Add after the filled `tri` from Task 3:

```swift
    /// Connected line segments through `points`, each a round-capped `capsule`, so
    /// the joints are naturally rounded. `closed` adds a segment back to the first point.
    public func polyline(_ points: [SIMD2<Float>], thickness: Float, closed: Bool = false,
                         color: Color = .white, aa: Float? = nil) {
        guard points.count >= 2 else { return }
        let aa = aa ?? currentShapeAA
        let radius = thickness * 0.5
        for i in 0..<(points.count - 1) {
            capsule(from: points[i], to: points[i + 1], radius: radius, color: color, aa: aa)
        }
        if closed {
            capsule(from: points[points.count - 1], to: points[0], radius: radius, color: color, aa: aa)
        }
    }

    /// Polygon outline: a closed `polyline` of `stroke` thickness. (Filled convex
    /// polygons are a deferred follow-up.)
    public func poly(_ points: [SIMD2<Float>], stroke: Float,
                     color: Color = .white, aa: Float? = nil) {
        polyline(points, thickness: stroke, closed: true, color: color, aa: aa)
    }

    /// Triangle outline of the given `stroke` thickness (round joins via `polyline`).
    public func tri(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>,
                    stroke: Float, color: Color = .white, aa: Float? = nil) {
        polyline([a, b, c], thickness: stroke, closed: true, color: color, aa: aa)
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes --filter olyline`
Expected: PASS. Also run the stroked-tri/poly tests:
Run: `swift test --package-path /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes --filter Outline`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git -C /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes add -A
git -C /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes commit -m "add polyline, polygon outline, and stroked triangle"
```

---

### Task 5: boxFill convenience

A CF-named filled-box convenience over the existing `box` (which already fills when `stroke == 0` and rounds when `cornerRadius > 0`).

**Files:**
- Modify: `Sources/Bielik2D/Draw/Primitives.swift`
- Test: `Tests/Bielik2DTests/PrimitivesTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `Tests/Bielik2DTests/PrimitivesTests.swift`:

```swift
@Test func boxFillEmitsFilledBox() {
    let b = Batcher()
    let d = Draw(batcher: b)
    d.boxFill(Rect(x: 0, y: 0, width: 40, height: 20), cornerRadius: 6)
    #expect(b.vertices.count == 6)
    let v = b.vertices.first!
    #expect(v.type == ShapeType.box.rawValue)
    #expect(v.fill == 1)
    #expect(v.radius == 6)  // cornerRadius forwarded
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes --filter boxFillEmitsFilledBox`
Expected: FAIL to compile — `boxFill` doesn't exist.

- [ ] **Step 3: Add `Draw.boxFill`**

Add after `box` in `Primitives.swift`:

```swift
    /// Filled (optionally rounded) box — a CF-named convenience over `box(stroke: 0)`.
    public func boxFill(_ rect: Rect, cornerRadius: Float = 0,
                        color: Color = .white, aa: Float? = nil) {
        box(rect, stroke: 0, cornerRadius: cornerRadius, color: color, aa: aa)
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes --filter boxFillEmitsFilledBox`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git -C /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes add -A
git -C /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes commit -m "add boxFill convenience"
```

---

### Task 6: Demo showcase + docs

Show the new shapes on screen, then update the roadmap docs per the CLAUDE.md rule.

**Files:**
- Modify: `Sources/Bielik2DDemo/main.swift`
- Modify: `FEATURES.md`
- Modify: `TODO.md`

- [ ] **Step 1: Add a shapes row to the demo**

In `Sources/Bielik2DDemo/main.swift`, inside the main render loop (after the existing primitive draws like `draw.circleFill(...)` / `draw.line(...)`, before `app.drawOntoScreen(...)`), add:

```swift
    // Phase 19 shape primitives: outline circle, rounded fill, triangle (filled +
    // outlined), polyline/poly, and a shapeAA contrast.
    let shapeY: Float = 320
    draw.circle(center: SIMD2(520, shapeY), radius: 34, thickness: 5, color: Color(r: 0.5, g: 0.9, b: 1.0))
    draw.boxFill(Rect(x: 580, y: shapeY - 34, width: 68, height: 68), cornerRadius: 14,
                 color: Color(r: 1.0, g: 0.7, b: 0.3))
    draw.tri(SIMD2(680, shapeY + 34), SIMD2(748, shapeY + 34), SIMD2(714, shapeY - 34),
             color: Color(r: 0.7, g: 1.0, b: 0.6))
    draw.tri(SIMD2(780, shapeY + 34), SIMD2(848, shapeY + 34), SIMD2(814, shapeY - 34),
             stroke: 4, color: Color(r: 1.0, g: 0.5, b: 0.8))
    draw.polyline([SIMD2(890, shapeY + 30), SIMD2(920, shapeY - 30),
                   SIMD2(950, shapeY + 30), SIMD2(980, shapeY - 30)],
                  thickness: 5, color: Color(r: 0.9, g: 0.9, b: 0.4))
    draw.with(shapeAA: 4.0) {
        draw.poly([SIMD2(1020, shapeY - 30), SIMD2(1060, shapeY - 10),
                   SIMD2(1045, shapeY + 30), SIMD2(1000, shapeY + 20)],
                  stroke: 3, color: Color(r: 0.8, g: 0.7, b: 1.0))
    }
```

(If the demo's variable for the draw list is named differently than `draw`, match the local name already in `main.swift`.)

- [ ] **Step 2: Build and run the demo to eyeball it**

Run: `swift build --package-path /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes`
Expected: `Build complete!`
Run (manual, ~5s): `swift run --package-path /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes Bielik2DDemo`
Expected: a window on Metal showing the new shapes, crisp at HiDPI — filled vs stroked triangle, rounded fill box, outline circle, polyline, and the softer-edged `poly` (shapeAA 4.0). Close the window to exit.

- [ ] **Step 3: Update `FEATURES.md` (draw row + summary)**

In `FEATURES.md`, edit the **draw** row's Notes to move the shipped primitives out of "Missing:". Replace the `**Missing:**` clause so it reads (keeping the state-stack + text items, which are later slices):

```
**Missing:** `pushScissor`/`pushViewport`/`pushBlendState` and text effects (color markup, outline, shadow). (Phase 19, remaining slices)
```

and update the shipped part of the Notes to mention the new shapes, e.g. append to the draw row's shipped description:
`outline circle, filled+outlined triangle, polyline, polygon outline, boxFill, and an ambient pushShapeAA.`

If the **draw** row is still flagged 🟡, it stays 🟡 (state stacks + text effects remain). Do not change the Summary counts (no module crossed a threshold).

- [ ] **Step 4: Tick `TODO.md` Phase 19 items**

In `TODO.md`, in the Phase 19 SDF-primitives bullet, mark the now-shipped shapes. Change:

```
- [ ] SDF primitives: outline `circle`, `boxFill`, `capsule`, `polyline`, `tri`, rounded box —
```

to a checked item noting filled convex `poly` is the remaining deferred piece, e.g.:

```
- [x] SDF primitives: outline `circle`, `boxFill`, `capsule`, `polyline`, `tri` (filled + outline),
      polygon outline, rounded box, ambient `pushShapeAA`. (Filled convex `poly` deferred.)
```

Leave the `pushScissor`/state-stack and text-effects bullets unchecked (later slices).

- [ ] **Step 5: Run the full test suite**

Run: `swift test --package-path /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes`
Expected: all tests pass, exit code 0.

- [ ] **Step 6: Commit**

```bash
git -C /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes add -A
git -C /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes commit -m "showcase new draw primitives and update roadmap docs"
```

---

## Verification (whole feature)

- `swift test --package-path /Users/piotr/Work/GitHub/pusewicz/bielik2d-draw-shapes` is green.
- `Shaders/build.sh` runs clean; `sprite.frag.spv` + `sprite.frag.wgsl` regenerated and committed.
- Demo on Metal shows all new shapes crisp at HiDPI; filled vs stroked and the shapeAA contrast read correctly.
- `FEATURES.md` draw row + `TODO.md` Phase 19 reflect the shipped primitives.
- Merge `draw-shapes` → `main` (fast-forward/rebase, conflict-free since this only touches Draw + shaders + demo + docs) once green; remove the worktree.

## Out of scope (later Phase 19 slices)

- Filled convex `poly` (needs a convex-poly SDF / vertex-layout rework).
- `pushScissor` / `pushViewport` / `pushBlendState` draw-state stacks.
- Text effects: color markup, outline, shadow.
- `ScaleMode` → NEAREST/LINEAR/SMOOTH rename.
