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
    public private(set) var vertices: ContiguousArray<Vertex> = []
    private var closedCommands: [DrawCommand] = []
    public private(set) var state: DrawCallState = DrawCallState()
    private var currentStart: Int = 0

    public init() {}

    /// Reserve enough storage for `n` vertices up front so subsequent emits
    /// never trigger a reallocation. Cheap to call repeatedly with the same n.
    public func reserveVertexCapacity(_ n: Int) {
        vertices.reserveCapacity(n)
    }

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
        emitQuadCorners(
            p0: SIMD2<Float>(rect.minX, rect.minY),
            p1: SIMD2<Float>(rect.maxX, rect.minY),
            p2: SIMD2<Float>(rect.maxX, rect.maxY),
            p3: SIMD2<Float>(rect.minX, rect.maxY),
            uv: uv,
            color: color
        )
    }

    /// Appends a single raw vertex. Bypasses the convenience quad/UV helpers —
    /// the caller is responsible for setting any SDF fields on the vertex.
    public func append(_ vertex: Vertex) {
        vertices.append(vertex)
    }

    public func emitQuadCorners(p0: SIMD2<Float>, p1: SIMD2<Float>, p2: SIMD2<Float>, p3: SIMD2<Float>,
                                uv: Rect, color: SIMD4<Float>) {
        let u0 = SIMD2<Float>(uv.minX, uv.minY)
        let u1 = SIMD2<Float>(uv.maxX, uv.minY)
        let u2 = SIMD2<Float>(uv.maxX, uv.maxY)
        let u3 = SIMD2<Float>(uv.minX, uv.maxY)
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
