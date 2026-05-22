/// A read-only snapshot of one frame's queued geometry, handed to a render
/// backend at flush time. Backends consume this — they never see the `Batcher`,
/// which is an engine implementation detail.
public struct DrawList {
    public let vertices: ContiguousArray<Vertex>
    public let commands: [DrawCommand]

    public init(vertices: ContiguousArray<Vertex>, commands: [DrawCommand]) {
        self.vertices = vertices
        self.commands = commands
    }
}

/// Turns a `Draw`'s queued geometry into pixels. The native SDL `Renderer` and
/// the WebGPU backend both conform; `Draw.flush(through:)` drives whichever one
/// you hand it. This is the seam that lets the `Batcher` stay internal while two
/// backends in two modules still render it.
public protocol RenderBackend: AnyObject {
    func render(_ list: DrawList, camera: Camera, clear: Color?)
}

extension Draw {
    /// Hands this frame's queued geometry to `backend`, then clears the queue
    /// (CF's "the flush consumes the queue" semantics). `camera` supplies the
    /// view-projection; `clear`, when set, clears the target first.
    public func flush(through backend: RenderBackend, camera: Camera, clear: Color? = nil) {
        let list = DrawList(vertices: batcher.vertices, commands: batcher.commandsSortedByLayer)
        backend.render(list, camera: camera, clear: clear)
        batcher.reset()
    }
}
