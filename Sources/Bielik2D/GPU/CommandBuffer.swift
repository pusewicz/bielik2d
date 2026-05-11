#if canImport(CSDL3)
import CSDL3

public struct CommandBuffer {
    public let handle: OpaquePointer

    public func submit() {
        _ = SDL_SubmitGPUCommandBuffer(handle)
    }

    public func pushVertexUniform<T>(_ value: T, slot: UInt32 = 0) {
        var v = value
        withUnsafePointer(to: &v) { ptr in
            SDL_PushGPUVertexUniformData(handle, slot, ptr, UInt32(MemoryLayout<T>.size))
        }
    }

    public func pushFragmentUniform<T>(_ value: T, slot: UInt32 = 0) {
        var v = value
        withUnsafePointer(to: &v) { ptr in
            SDL_PushGPUFragmentUniformData(handle, slot, ptr, UInt32(MemoryLayout<T>.size))
        }
    }

    /// Waits for and acquires the swapchain texture for `window`.
    /// Returns nil when the window is minimized — caller should still submit the command buffer.
    public func acquireSwapchainTexture(for window: OpaquePointer, device: GPUDevice) -> Texture? {
        var tex: OpaquePointer?
        var w: UInt32 = 0
        var h: UInt32 = 0
        guard SDL_WaitAndAcquireGPUSwapchainTexture(handle, window, &tex, &w, &h),
              let texHandle = tex else { return nil }
        let fmtRaw = SDL_GetGPUSwapchainTextureFormat(device.handle, window)
        let format: TextureFormat = (fmtRaw == SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM) ? .rgba8Unorm : .bgra8Unorm
        return Texture(handle: texHandle, width: Int(w), height: Int(h),
                       format: format, device: device.handle, owned: false)
    }
}

extension GPUDevice {
    public func acquireCommandBuffer() throws -> CommandBuffer {
        guard let cmd = SDL_AcquireGPUCommandBuffer(handle) else {
            throw GPUError.acquireCommandBuffer(lastSDLError())
        }
        return CommandBuffer(handle: cmd)
    }
}
#endif
