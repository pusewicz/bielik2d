/// State that determines whether two consecutive emits can share a draw call.
/// Any change to this state forces a flush.
public struct DrawCallState: Equatable {
    public var texture: OpaquePointer?
    public var blendMode: BlendMode
    public var layer: Int

    public init(texture: OpaquePointer? = nil, blendMode: BlendMode = .alpha, layer: Int = 0) {
        self.texture = texture
        self.blendMode = blendMode
        self.layer = layer
    }
}

public struct DrawCommand: Equatable {
    public let state: DrawCallState
    public let vertexStart: Int
    public let vertexCount: Int
}

/// Accumulates vertices and emits a `DrawCommand` whenever the active state changes.
/// Pure data — no GPU contact, so it's unit-testable without a device.
public final class Batcher {
    public private(set) var vertices: [Vertex] = []
    private var closedCommands: [DrawCommand] = []
    public private(set) var state: DrawCallState = DrawCallState()
    private var currentStart: Int = 0

    public init() {}

    public var commands: [DrawCommand] {
        var out = closedCommands
        let count = vertices.count - currentStart
        if count > 0 {
            out.append(DrawCommand(state: state, vertexStart: currentStart, vertexCount: count))
        }
        return out
    }

    public func setTexture(_ t: OpaquePointer?) {
        flushIfChange { $0.texture = t }
    }

    public func setBlend(_ b: BlendMode) {
        flushIfChange { $0.blendMode = b }
    }

    public func setLayer(_ l: Int) {
        flushIfChange { $0.layer = l }
    }

    public func emitQuad(rect: Rect, uv: Rect, color: SIMD4<Float>) {
        let p0 = SIMD2<Float>(rect.minX, rect.minY)
        let p1 = SIMD2<Float>(rect.maxX, rect.minY)
        let p2 = SIMD2<Float>(rect.maxX, rect.maxY)
        let p3 = SIMD2<Float>(rect.minX, rect.maxY)
        let u0 = SIMD2<Float>(uv.minX, uv.minY)
        let u1 = SIMD2<Float>(uv.maxX, uv.minY)
        let u2 = SIMD2<Float>(uv.maxX, uv.maxY)
        let u3 = SIMD2<Float>(uv.minX, uv.maxY)
        // Two triangles: (p0,p1,p2), (p0,p2,p3)
        vertices.append(Vertex(pos: p0, uv: u0, color: color))
        vertices.append(Vertex(pos: p1, uv: u1, color: color))
        vertices.append(Vertex(pos: p2, uv: u2, color: color))
        vertices.append(Vertex(pos: p0, uv: u0, color: color))
        vertices.append(Vertex(pos: p2, uv: u2, color: color))
        vertices.append(Vertex(pos: p3, uv: u3, color: color))
    }

    public var commandsSortedByLayer: [DrawCommand] {
        commands.sorted { $0.state.layer < $1.state.layer }
    }

    public func reset() {
        vertices.removeAll(keepingCapacity: true)
        closedCommands.removeAll(keepingCapacity: true)
        currentStart = 0
    }

    private func closeRun() {
        let count = vertices.count - currentStart
        if count > 0 {
            closedCommands.append(DrawCommand(state: state, vertexStart: currentStart, vertexCount: count))
            currentStart = vertices.count
        }
    }

    private func flushIfChange(_ mutate: (inout DrawCallState) -> Void) {
        var next = state
        mutate(&next)
        guard next != state else { return }
        closeRun()
        state = next
    }
}
