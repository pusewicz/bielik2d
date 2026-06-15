#if canImport(simd)
import simd
#else
import kvSIMD
#endif

/// Net result of a swept move with surface sliding.
/// `motion` is the displacement actually applied; `normals` are the contact surface normals
/// touched along the way (facing back toward the mover), for grounded / wall detection — the
/// same surface may appear more than once across iterations. Each contact backs the mover off
/// by `skin` along its normal, so in tight corners the per-move skin offsets can compound; keep
/// `skin` small relative to your geometry.
public struct MoveResult: Equatable, Sendable {
    public var motion: SIMD2<Float>
    public var normals: [SIMD2<Float>]
    public init(motion: SIMD2<Float>, normals: [SIMD2<Float>]) {
        self.motion = motion
        self.normals = normals
    }
}

/// Sweep a convex `mover` (as its `Support`) by `delta` against `world`, sliding along contacts.
func moveSlide(_ mover: Support, by delta: SIMD2<Float>, against world: [CollisionShape],
               iterations: Int, skin: Float) -> MoveResult {
    var offset = SIMD2<Float>(0, 0)
    var remaining = delta
    var normals: [SIMD2<Float>] = []
    var iters = iterations
    while iters > 0 && simd_length_squared(remaining) > 1e-12 {
        let here = mover.offset(by: offset)
        var best: ToI? = nil
        for shape in world {
            if let hit = sweepConvex(here, by: remaining, movedBy: .zero, against: shape),
               best == nil || hit.t < best!.t {
                best = hit
            }
        }
        guard let hit = best else {                 // clear path: consume the rest
            offset += remaining
            remaining = .zero
            break
        }
        offset += remaining * hit.t                 // advance to the contact
        offset += hit.normal * skin                 // back off along the outward normal
        normals.append(hit.normal)
        let leftover = remaining * (1 - hit.t)      // project leftover onto the surface tangent
        remaining = leftover - hit.normal * simd_dot(leftover, hit.normal)
        iters -= 1
    }
    return MoveResult(motion: offset, normals: normals)
}

extension Circle {
    /// Sweep `self` by `delta` against `world`, sliding along contacts. Apply `MoveResult.motion`
    /// to the game object's position. `normals` reports surfaces touched (grounded / wall checks).
    public func move(by delta: SIMD2<Float>, against world: [CollisionShape],
                     iterations: Int = 4, skin: Float = 0.01) -> MoveResult {
        moveSlide(support, by: delta, against: world, iterations: iterations, skin: skin)
    }
}

extension AABB {
    /// Sweep `self` by `delta` against `world`, sliding along contacts. Apply `MoveResult.motion`
    /// to the game object's position. `normals` reports surfaces touched (grounded / wall checks).
    public func move(by delta: SIMD2<Float>, against world: [CollisionShape],
                     iterations: Int = 4, skin: Float = 0.01) -> MoveResult {
        moveSlide(support, by: delta, against: world, iterations: iterations, skin: skin)
    }
}

extension Capsule {
    /// Sweep `self` by `delta` against `world`, sliding along contacts. Apply `MoveResult.motion`
    /// to the game object's position. `normals` reports surfaces touched (grounded / wall checks).
    public func move(by delta: SIMD2<Float>, against world: [CollisionShape],
                     iterations: Int = 4, skin: Float = 0.01) -> MoveResult {
        moveSlide(support, by: delta, against: world, iterations: iterations, skin: skin)
    }
}

extension Polygon {
    /// Sweep `self` by `delta` against `world`, sliding along contacts. Apply `MoveResult.motion`
    /// to the game object's position. `normals` reports surfaces touched (grounded / wall checks).
    public func move(by delta: SIMD2<Float>, against world: [CollisionShape],
                     iterations: Int = 4, skin: Float = 0.01) -> MoveResult {
        moveSlide(support, by: delta, against: world, iterations: iterations, skin: skin)
    }
}
