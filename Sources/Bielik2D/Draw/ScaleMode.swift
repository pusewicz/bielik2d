/// How a sampled texture is filtered when drawn at a non-native size.
/// Mirrors SDL's `SDL_ScaleMode`. The chosen mode rides along in the sprite
/// vertex (`Vertex.attributes`) and the fragment shader branches on it.
public enum ScaleMode: Equatable, Sendable {
    /// Snap to the nearest texel. Blocky, classic; emulated in-shader.
    case nearest
    /// Hardware bilinear. Smooth but blurry on upscaled pixel art.
    case linear
    /// Antialiased pixel-art upscaling (SDL_SCALEMODE_PIXELART): crisp texel
    /// edges that stay shimmer-free at non-integer scale.
    case pixelArt

    public static let `default`: ScaleMode = .linear

    /// Value the shader compares against. `linear == 0` so that vertices whose
    /// scale payload is left zeroed render exactly as before.
    public var shaderValue: Float {
        switch self {
        case .linear: 0
        case .pixelArt: 1
        case .nearest: 2
        }
    }
}
