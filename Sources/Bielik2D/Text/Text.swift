import CSDL3

extension Draw {
    /// Renders a UTF-8 string into the batcher using SDL3_ttf's GPU text engine.
    /// The text engine produces a linked list of atlas draw sequences (one per
    /// atlas texture); each sequence is an indexed triangle list that we expand
    /// into the unified-SDF vertex format.
    public func text(_ string: String, font: Font, at origin: SIMD2<Float>, color: Color = .white) {
        guard let engine = textEngine else { return }
        guard let textHandle = string.withCString({ cstr in
            TTF_CreateText(engine.handle, font.handle, cstr, string.utf8.count)
        }) else { return }
        defer { TTF_DestroyText(textHandle) }

        guard var seq = TTF_GetGPUTextDrawData(textHandle) else { return }

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
