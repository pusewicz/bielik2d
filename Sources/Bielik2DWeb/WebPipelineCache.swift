#if os(WASI)
import JavaScriptKit
import Bielik2D

/// Identifies a vertex/fragment shader pair the renderer can drive. Mirrors the
/// native `Renderer`'s shader set: a plain position/color pipeline (`basic`) and
/// the unified sprite + SDF pipeline (`sprite`). The native renderer happens to
/// use only `sprite` for everything, but the cache supports both so a command's
/// shader can vary later.
public enum WebShaderID: Hashable, Sendable {
    case basic
    case sprite

    /// Base names of the vert/frag WGSL files under `shaders/`.
    var moduleBaseName: String {
        switch self {
        case .basic: "basic"
        case .sprite: "sprite"
        }
    }
}

/// Cache key: which shader pair, and which blend mode. Two commands that share
/// both reuse one WebGPU pipeline — the analogue of the native `PipelineKey`
/// (which also folds in colour format; the web swapchain has a single format,
/// so it's implicit here).
public struct WebPipelineKey: Hashable, Sendable {
    public var shader: WebShaderID
    public var blend: BlendMode

    public init(shader: WebShaderID, blend: BlendMode) {
        self.shader = shader
        self.blend = blend
    }
}

/// Lazily builds and caches one WebGPU `GPURenderPipeline` per `(shader, blend)`.
/// Shader modules are loaded once up front (a module is fetched async and reused
/// across every blend variant); pipelines are built on first use of a key.
public final class WebPipelineCache {
    private let device: JSObject
    private let colorFormat: String
    private let vertexLayout: JSObject
    private let modules: [WebShaderID: (vertex: JSObject, fragment: JSObject)]
    private let pipelineLayout: JSObject
    private var pipelines: [WebPipelineKey: JSObject] = [:]

    /// Bind-group layouts shared by every pipeline so bind groups built once stay
    /// valid no matter which (shader, blend) pipeline is currently bound.
    /// group 0: camera uniform (`@group(0) @binding(0)`, vertex stage).
    /// group 1: texture + sampler (`@group(1) @binding(0/1)`, fragment stage).
    public let cameraBindGroupLayout: JSObject
    public let textureBindGroupLayout: JSObject

    /// Loads the vert/frag modules for every `WebShaderID` and wires up the cache.
    /// The vertex buffer layout is the FULL `Vertex.bufferLayout` (locations 0..11),
    /// so a single vertex buffer feeds both the basic and sprite pipelines — extra
    /// attributes a shader doesn't read are allowed.
    public static func create(backend: WebGPURenderBackend) async throws -> WebPipelineCache {
        var modules: [WebShaderID: (vertex: JSObject, fragment: JSObject)] = [:]
        for shader in [WebShaderID.basic, WebShaderID.sprite] {
            let base = shader.moduleBaseName
            let vs = try await backend.loadShaderModule(url: "shaders/\(base).vert.wgsl")
            let fs = try await backend.loadShaderModule(url: "shaders/\(base).frag.wgsl")
            modules[shader] = (vs, fs)
        }
        return WebPipelineCache(device: backend.device,
                                colorFormat: backend.preferredFormat,
                                modules: modules)
    }

    private init(device: JSObject, colorFormat: String,
                 modules: [WebShaderID: (vertex: JSObject, fragment: JSObject)]) {
        self.device = device
        self.colorFormat = colorFormat
        self.modules = modules
        self.vertexLayout = Self.makeVertexLayout()

        // GPUShaderStage flags: VERTEX = 1, FRAGMENT = 2.
        let cameraBGL = device.createBindGroupLayout!(WebJS.object([
            "entries": .object(WebJS.array([
                WebJS.object([
                    "binding": .number(0),
                    "visibility": .number(1),
                    "buffer": .object(WebJS.object(["type": .string("uniform")])),
                ]),
            ])),
        ])).object!
        let textureBGL = device.createBindGroupLayout!(WebJS.object([
            "entries": .object(WebJS.array([
                WebJS.object([
                    "binding": .number(0),
                    "visibility": .number(2),
                    "texture": .object(WebJS.object([
                        "sampleType": .string("float"),
                        "viewDimension": .string("2d"),
                    ])),
                ]),
                WebJS.object([
                    "binding": .number(1),
                    "visibility": .number(2),
                    "sampler": .object(WebJS.object(["type": .string("filtering")])),
                ]),
            ])),
        ])).object!
        self.cameraBindGroupLayout = cameraBGL
        self.textureBindGroupLayout = textureBGL
        self.pipelineLayout = device.createPipelineLayout!(WebJS.object([
            "bindGroupLayouts": .object(WebJS.array([cameraBGL, textureBGL])),
        ])).object!
    }

    /// The full Bielik2D vertex layout as a WebGPU vertex-buffer descriptor.
    private static func makeVertexLayout() -> JSObject {
        let attrs = Vertex.bufferLayout.attributes.map { attr -> JSObject in
            WebJS.object([
                "shaderLocation": .number(Double(attr.location)),
                "offset": .number(Double(attr.offset)),
                "format": .string(wgpuVertexFormat(attr.format)),
            ])
        }
        return WebJS.object([
            "arrayStride": .number(Double(Vertex.bufferLayout.stride)),
            "attributes": .object(WebJS.array(Array(attrs))),
        ])
    }

    /// Returns the cached pipeline for `key`, building it on first request.
    public func pipeline(for key: WebPipelineKey) -> JSObject {
        if let existing = pipelines[key] { return existing }
        let built = buildPipeline(key)
        pipelines[key] = built
        return built
    }

    private func buildPipeline(_ key: WebPipelineKey) -> JSObject {
        guard let mods = modules[key.shader] else {
            fatalError("WebPipelineCache: no shader modules loaded for \(key.shader)")
        }

        // Color target: omit `blend` for `.none` (opaque write), otherwise build
        // the GPUBlendState from the shared BlendMode → WebGPU mapping.
        var colorTargetPairs: [String: JSValue] = ["format": .string(colorFormat)]
        if let blend = key.blend.webGPUBlendState {
            colorTargetPairs["blend"] = .object(WebJS.object([
                "color": .object(blendComponent(blend.color)),
                "alpha": .object(blendComponent(blend.alpha)),
            ]))
        }
        let colorTarget = WebJS.object(colorTargetPairs)

        let descriptor = WebJS.object([
            "layout": .object(pipelineLayout),
            "vertex": .object(WebJS.object([
                "module": .object(mods.vertex),
                "entryPoint": .string("main"),
                "buffers": .object(WebJS.array([vertexLayout])),
            ])),
            "fragment": .object(WebJS.object([
                "module": .object(mods.fragment),
                "entryPoint": .string("main"),
                "targets": .object(WebJS.array([colorTarget])),
            ])),
            "primitive": .object(WebJS.object([
                "topology": .string("triangle-list"),
            ])),
        ])

        guard let pipeline = device.createRenderPipeline!(descriptor).object else {
            fatalError("WebPipelineCache: createRenderPipeline failed for \(key)")
        }
        return pipeline
    }

    private func blendComponent(_ c: WebGPUBlendComponent) -> JSObject {
        WebJS.object([
            "srcFactor": .string(c.srcFactor),
            "dstFactor": .string(c.dstFactor),
            "operation": .string(c.operation),
        ])
    }
}
#endif
