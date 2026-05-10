import CSDL3

public struct CommandBuffer {
    public let handle: OpaquePointer

    public func submit() {
        _ = SDL_SubmitGPUCommandBuffer(handle)
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
