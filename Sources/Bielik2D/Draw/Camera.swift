import simd

/// A simple 2D camera: an orthographic projection sized to the viewport, plus
/// a `view` transform applied to the world before projection.
///
/// World convention: +Y points down (screen-style), origin at the top-left.
/// SDL_GPU's clip space matches Vulkan's (Y points down too), so we don't flip.
public struct Camera {
    public var viewportSize: SIMD2<Float>
    public var view: Mat3x2

    public init(viewportSize: SIMD2<Float>, view: Mat3x2 = .identity) {
        self.viewportSize = viewportSize
        self.view = view
    }

    /// Maps screen-style world coords (origin top-left, +Y down) to SDL_GPU's
    /// clip space, which behaves like Metal's NDC here: +Y is **up**, so we
    /// need to flip Y in projection. World (0,0) → clip(-1, +1) → top-left,
    /// world (viewportSize) → clip(+1, -1) → bottom-right.
    public var projection: simd_float4x4 {
        let w = viewportSize.x
        let h = viewportSize.y
        return simd_float4x4(
            SIMD4( 2 / w,   0,    0, 0),
            SIMD4( 0,      -2 / h, 0, 0),
            SIMD4( 0,       0,    1, 0),
            SIMD4(-1,       1,    0, 1)
        )
    }

    /// The view matrix as a 4x4 affine. Z stays at 0.
    public var viewMatrix4x4: simd_float4x4 {
        simd_float4x4(
            SIMD4(view.a, view.b, 0, 0),
            SIMD4(view.c, view.d, 0, 0),
            SIMD4(0, 0, 1, 0),
            SIMD4(view.tx, view.ty, 0, 1)
        )
    }

    public var viewProjection: simd_float4x4 {
        projection * viewMatrix4x4
    }
}
