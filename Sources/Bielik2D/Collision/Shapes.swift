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
