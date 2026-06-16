#if canImport(CSDL3)
import CSDL3

struct RenderPass {
    public let handle: OpaquePointer

    public func bind(_ pipeline: GraphicsPipeline) {
        SDL_BindGPUGraphicsPipeline(handle, pipeline.handle)
    }

    public func bindVertexBuffer(_ buffer: Buffer, offset: Int = 0, slot: UInt32 = 0) {
        var binding = SDL_GPUBufferBinding()
        binding.buffer = buffer.handle
        binding.offset = UInt32(offset)
        SDL_BindGPUVertexBuffers(handle, slot, &binding, 1)
    }

    public func bindFragmentSampler(_ texture: Texture, sampler: Sampler, slot: UInt32 = 0) {
        bindFragmentSampler(textureHandle: texture.handle, sampler: sampler, slot: slot)
    }

    /// Binds a raw `SDL_GPUTexture*` handle. Used by the batcher when iterating
    /// commands — the per-command texture might be a sprite, a canvas, or
    /// SDL3_ttf's glyph atlas, all of which we only know as opaque pointers.
    public func bindFragmentSampler(textureHandle: OpaquePointer?, sampler: Sampler, slot: UInt32 = 0) {
        guard let textureHandle else { return }
        var binding = SDL_GPUTextureSamplerBinding()
        binding.texture = textureHandle
        binding.sampler = sampler.handle
        SDL_BindGPUFragmentSamplers(handle, slot, &binding, 1)
    }

    public func draw(vertexCount: Int, firstVertex: Int = 0, instanceCount: Int = 1) {
        SDL_DrawGPUPrimitives(handle, UInt32(vertexCount), UInt32(instanceCount), UInt32(firstVertex), 0)
    }

    public func setScissor(x: Int, y: Int, width: Int, height: Int) {
        var r = SDL_Rect(x: Int32(x), y: Int32(y), w: Int32(width), h: Int32(height))
        SDL_SetGPUScissor(handle, &r)
    }

    public func setViewport(x: Float, y: Float, width: Float, height: Float) {
        var vp = SDL_GPUViewport(x: x, y: y, w: width, h: height, min_depth: 0, max_depth: 1)
        SDL_SetGPUViewport(handle, &vp)
    }
}

extension CommandBuffer {
    public func withRenderPass(colorTarget: Texture,
                               clear: Color? = nil,
                               cycle: Bool = false,
                               _ body: (RenderPass) -> Void) {
        var info = SDL_GPUColorTargetInfo()
        info.texture = colorTarget.handle
        info.load_op = clear == nil ? SDL_GPU_LOADOP_LOAD : SDL_GPU_LOADOP_CLEAR
        info.store_op = SDL_GPU_STOREOP_STORE
        // Cycle an offscreen target that's also sampled elsewhere: it hands us a
        // fresh backing each frame so rendering into it can't race a still-in-flight
        // sampler reading last frame's contents (otherwise the canvas feeds back).
        info.cycle = cycle
        if let c = clear {
            info.clear_color = SDL_FColor(r: c.r, g: c.g, b: c.b, a: c.a)
        }
        let pass = withUnsafePointer(to: &info) { ptr in
            SDL_BeginGPURenderPass(handle, ptr, 1, nil)
        }
        guard let pass else { return }
        body(RenderPass(handle: pass))
        SDL_EndGPURenderPass(pass)
    }
}
#endif
