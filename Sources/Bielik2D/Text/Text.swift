#if canImport(CSDL3)
import CSDL3

/// A cached `TTF_Text` handle. Use this when the same text engine + font is
/// drawn every frame and only the *string* might change — `setString` does
/// nothing when content is unchanged, and the underlying glyph layout is
/// reused across frames instead of being recreated. Hot HUD paths should
/// hold a `Label` rather than calling `Draw.text(_ string:...)` each frame.
public final class Label {
    public let engine: TextEngine
    public let font: Font
    let handle: UnsafeMutablePointer<TTF_Text>
    private var cached: String

    public init(font: Font, engine: TextEngine, initial: String = "") throws {
        self.engine = engine
        self.font = font
        self.cached = initial
        guard let h = initial.withCString({ cstr in
            TTF_CreateText(engine.handle, font.handle, cstr, initial.utf8.count)
        }) else {
            throw FontError.createTextFailed(lastSDLError())
        }
        self.handle = h
    }

    /// Replaces the rendered string. No-ops when `s` equals the cached value.
    public func setString(_ s: String) {
        if s == cached { return }
        s.withCString { cstr in
            _ = TTF_SetTextString(handle, cstr, s.utf8.count)
        }
        cached = s
    }

    deinit {
        TTF_DestroyText(handle)
    }
}

extension Draw {
    /// Renders a UTF-8 string into the batcher using SDL3_ttf's GPU text engine.
    /// Creates and destroys a `TTF_Text` for the call — fine for one-off labels,
    /// but use `Label` + `text(_ label:...)` for anything drawn every frame.
    public func text(_ string: String, font: Font, at origin: SIMD2<Float>, color: Color = .white) {
        guard let engine = textEngine as? TextEngine else { return }
        guard let textHandle = string.withCString({ cstr in
            TTF_CreateText(engine.handle, font.handle, cstr, string.utf8.count)
        }) else { return }
        defer { TTF_DestroyText(textHandle) }
        emitTextSequence(handle: textHandle, at: origin, color: color)
    }

    /// Renders a cached label. Glyph layout was set up at `Label.setString` time,
    /// so this path skips the create/destroy cost of the one-shot overload.
    public func text(_ label: Label, at origin: SIMD2<Float>, color: Color = .white) {
        guard textEngine is TextEngine else { return }
        emitTextSequence(handle: label.handle, at: origin, color: color)
    }

    private func emitTextSequence(handle: UnsafeMutablePointer<TTF_Text>, at origin: SIMD2<Float>, color: Color) {
        guard var seq = TTF_GetGPUTextDrawData(handle) else { return }

        let t = currentTransform
        let tint = currentColor
        let tinted = SIMD4<Float>(
            color.r * tint.r,
            color.g * tint.g,
            color.b * tint.b,
            color.a * tint.a
        )

        while true {
            let s = seq.pointee
            batcher.setTexture(s.atlas_texture)

            let xy = s.xy
            let uv = s.uv
            let indices = s.indices

            for i in 0..<Int(s.num_indices) {
                let idx = Int(indices![i])
                let local = xy![idx]
                // SDL_ttf assumes +Y is up in its GPU output (see SDL_gpu_textengine.c:
                // "In the GPU API positive y-axis is upwards so the signs of the y-coords is reversed").
                // Our world is +Y down, so flip y back. Origin then corresponds to the
                // text's top-left rather than its baseline.
                let world = t.transform(SIMD2(origin.x + local.x, origin.y - local.y))
                let v = Vertex(
                    pos: world,
                    uv: SIMD2(uv![idx].x, uv![idx].y),
                    color: tinted,
                    type: ShapeType.sprite.rawValue,
                    alpha: 1, fill: 1
                )
                batcher.append(v)
            }

            guard let next = s.next else { break }
            seq = next
        }
    }
}
#endif
