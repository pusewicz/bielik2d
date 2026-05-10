import CSDL3

public struct RenderPass {
    public let handle: OpaquePointer
}

extension CommandBuffer {
    public func withRenderPass(colorTarget: Texture,
                               clear: Color? = nil,
                               _ body: (RenderPass) -> Void) {
        var info = SDL_GPUColorTargetInfo()
        info.texture = colorTarget.handle
        info.load_op = clear == nil ? SDL_GPU_LOADOP_LOAD : SDL_GPU_LOADOP_CLEAR
        info.store_op = SDL_GPU_STOREOP_STORE
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
