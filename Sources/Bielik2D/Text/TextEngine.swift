// The neutral text-engine seam. `Draw` stores its text engine as `Any?` and the
// platform `Draw.text` extension casts to its concrete engine, but every engine
// — native SDL3_ttf or web Canvas 2D — conforms to `TextEngineProtocol` so the
// portable layer can name the seam without naming a platform type.
public protocol TextEngineProtocol: AnyObject {
    /// Releases backing GPU/browser resources. Idempotent where practical.
    func destroy()

    /// Rasterizes `string` in `font` and emits its glyph geometry into `draw`'s
    /// batcher at `origin`, tinted by `color`. Engines that haven't wired
    /// rasterization yet inherit the no-op default. The native engine draws
    /// through its own typed `Draw.text` overloads instead and ignores this.
    func drawText(_ string: String, font: Font, at origin: SIMD2<Float>, color: Color, into draw: Draw)
}

extension TextEngineProtocol {
    public func drawText(_ string: String, font: Font, at origin: SIMD2<Float>, color: Color, into draw: Draw) {}
}

#if canImport(CSDL3)
import CSDL3

/// Native text engine: a thin owner of SDL3_ttf's GPU text engine handle. Fonts
/// are opened independently (`Font(path:)`) and drawn through this engine, so the
/// engine stays a per-renderer singleton while fonts come and go.
public final class TextEngine: TextEngineProtocol {
    public let handle: OpaquePointer

    public init(on renderer: Renderer) throws {
        try TTFLifecycle.ensureInit()
        guard let h = TTF_CreateGPUTextEngine(renderer.device.handle) else {
            throw FontError.createEngineFailed(lastSDLError())
        }
        self.handle = h
    }

    public func destroy() {
        TTF_DestroyGPUTextEngine(handle)
    }
}
#endif
