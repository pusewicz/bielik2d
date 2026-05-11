#if os(WASI)
import JavaScriptKit
import JavaScriptEventLoop
import Bielik2D
import Bielik2DWeb

JavaScriptEventLoop.installGlobalExecutor()

enum DemoState {
    nonisolated(unsafe) static var platform: WebPlatform?
    nonisolated(unsafe) static var backend: WebGPURenderBackend?
    nonisolated(unsafe) static var pipeline: JSObject?
    nonisolated(unsafe) static var vertexBuffer: JSObject?
    nonisolated(unsafe) static var bindGroup0: JSObject?
    nonisolated(unsafe) static var bindGroup1: JSObject?
}

Task {
    do { try await runDemo() }
    catch { print("bielik2d: error \(error)") }
}

func runDemo() async throws {
    let platform = try WebPlatform.attach(canvasID: "bielik2d")
    let backend = try await WebGPURenderBackend.create(on: platform)
    DemoState.platform = platform
    DemoState.backend = backend

    let vsModule = try await backend.loadShaderModule(url: "shaders/sprite.vert.wgsl")
    let fsModule = try await backend.loadShaderModule(url: "shaders/sprite.frag.wgsl")

    // Vertex layout: locations 0..8 of Bielik2D.Vertex.bufferLayout. The
    // shader does not consume locations 9..11 (posH, attributes, uvBounds), so
    // we trim the layout to the bound subset.
    let attrs = Vertex.bufferLayout.attributes.prefix(9).map { attr -> JSObject in
        WebJS.object([
            "shaderLocation": .number(Double(attr.location)),
            "offset": .number(Double(attr.offset)),
            "format": .string(wgpuVertexFormat(attr.format)),
        ])
    }
    let vbDescriptor = WebJS.object([
        "arrayStride": .number(Double(Vertex.bufferLayout.stride)),
        "attributes": .object(WebJS.array(Array(attrs))),
    ])

    let blendComponent: (String, String) -> JSObject = { src, dst in
        WebJS.object([
            "srcFactor": .string(src),
            "dstFactor": .string(dst),
            "operation": .string("add"),
        ])
    }
    let colorTarget = WebJS.object([
        "format": .string(backend.preferredFormat),
        "blend": .object(WebJS.object([
            "color": .object(blendComponent("src-alpha", "one-minus-src-alpha")),
            "alpha": .object(blendComponent("one", "one-minus-src-alpha")),
        ])),
    ])

    let pipelineDescriptor = WebJS.object([
        "layout": .string("auto"),
        "vertex": .object(WebJS.object([
            "module": .object(vsModule),
            "entryPoint": .string("main"),
            "buffers": .object(WebJS.array([vbDescriptor])),
        ])),
        "fragment": .object(WebJS.object([
            "module": .object(fsModule),
            "entryPoint": .string("main"),
            "targets": .object(WebJS.array([colorTarget])),
        ])),
        "primitive": .object(WebJS.object([
            "topology": .string("triangle-list"),
        ])),
    ])

    guard let pipeline = backend.device.createRenderPipeline!(pipelineDescriptor).object else {
        throw WebGPUError.deviceRequestFailed
    }

    // Camera + uniform buffer.
    let camera = Camera(viewportSize: SIMD2(Float(platform.size.x), Float(platform.size.y)))
    var viewProj = camera.viewProjection
    let uniformBuffer = backend.device.createBuffer!(WebJS.object([
        "size": .number(64),
        "usage": .number(Double(GPUBufferUsage.uniform | GPUBufferUsage.copyDst)),
    ])).object!
    withUnsafeBytes(of: &viewProj) { ptr in
        let bytes = Array(ptr.bindMemory(to: UInt8.self))
        _ = backend.queue.writeBuffer!(uniformBuffer, 0, JSTypedArray<UInt8>(bytes).jsObject)
    }

    // Sprite texture from a fetched PNG.
    let bitmap = try await WebAssetLoader.loadImageBitmap(url: "assets/p1_stand.png")
    let (texture, spriteW, spriteH) = backend.makeTexture(from: bitmap)

    let sampler = backend.device.createSampler!(WebJS.object([
        "magFilter": .string("linear"),
        "minFilter": .string("linear"),
    ])).object!

    // Bind groups derived from pipeline's auto-layout.
    let bgl0 = pipeline.getBindGroupLayout!(0).object!
    let bgl1 = pipeline.getBindGroupLayout!(1).object!
    let bindGroup0 = backend.device.createBindGroup!(WebJS.object([
        "layout": .object(bgl0),
        "entries": .object(WebJS.array([
            WebJS.object([
                "binding": .number(0),
                "resource": .object(WebJS.object(["buffer": .object(uniformBuffer)])),
            ]),
        ])),
    ])).object!
    let bindGroup1 = backend.device.createBindGroup!(WebJS.object([
        "layout": .object(bgl1),
        "entries": .object(WebJS.array([
            WebJS.object([
                "binding": .number(0),
                "resource": .object(texture.createView!().object!),
            ]),
            WebJS.object([
                "binding": .number(1),
                "resource": .object(sampler),
            ]),
        ])),
    ])).object!

    // One quad at the sprite's native pixel size, centred on the canvas.
    let white = SIMD4<Float>(1, 1, 1, 1)
    let cx = Float(platform.size.x) * 0.5
    let cy = Float(platform.size.y) * 0.5
    let halfW = Float(spriteW) * 0.5
    let halfH = Float(spriteH) * 0.5
    let verts: [Vertex] = [
        Vertex(pos: SIMD2(cx - halfW, cy - halfH), uv: SIMD2(0, 0), color: white),
        Vertex(pos: SIMD2(cx + halfW, cy - halfH), uv: SIMD2(1, 0), color: white),
        Vertex(pos: SIMD2(cx + halfW, cy + halfH), uv: SIMD2(1, 1), color: white),
        Vertex(pos: SIMD2(cx - halfW, cy - halfH), uv: SIMD2(0, 0), color: white),
        Vertex(pos: SIMD2(cx + halfW, cy + halfH), uv: SIMD2(1, 1), color: white),
        Vertex(pos: SIMD2(cx - halfW, cy + halfH), uv: SIMD2(0, 1), color: white),
    ]
    let vertexBuffer = backend.device.createBuffer!(WebJS.object([
        "size": .number(Double(verts.count * MemoryLayout<Vertex>.stride)),
        "usage": .number(Double(GPUBufferUsage.vertex | GPUBufferUsage.copyDst)),
    ])).object!
    verts.withUnsafeBytes { ptr in
        let bytes = Array(ptr.bindMemory(to: UInt8.self))
        _ = backend.queue.writeBuffer!(vertexBuffer, 0, JSTypedArray<UInt8>(bytes).jsObject)
    }

    DemoState.pipeline = pipeline
    DemoState.vertexBuffer = vertexBuffer
    DemoState.bindGroup0 = bindGroup0
    DemoState.bindGroup1 = bindGroup1

    let clear = ClearColor(r: 0.10, g: 0.12, b: 0.18, a: 1.0)
    let vertexCount = verts.count
    platform.run { _ in
        backend.frame(clear: clear) { pass in
            _ = pass.setPipeline!(pipeline)
            _ = pass.setBindGroup!(0, bindGroup0)
            _ = pass.setBindGroup!(1, bindGroup1)
            _ = pass.setVertexBuffer!(0, vertexBuffer)
            _ = pass.draw!(vertexCount)
        }
    }
}

func wgpuVertexFormat(_ f: VertexFormat) -> String {
    switch f {
    case .float: "float32"
    case .float2: "float32x2"
    case .float3: "float32x3"
    case .float4: "float32x4"
    case .ubyte4Norm: "unorm8x4"
    }
}

// WebGPU GPUBufferUsage / GPUTextureUsage flag constants. The browser exposes
// these as `GPUBufferUsage.VERTEX` etc., but threading them through JSValue
// for every descriptor is noisy — keep them as Swift constants here.
enum GPUBufferUsage {
    static let mapRead: Int = 1
    static let mapWrite: Int = 2
    static let copySrc: Int = 4
    static let copyDst: Int = 8
    static let index: Int = 16
    static let vertex: Int = 32
    static let uniform: Int = 64
    static let storage: Int = 128
    static let indirect: Int = 256
}

enum GPUTextureUsage {
    static let copySrc: Int = 1
    static let copyDst: Int = 2
    static let textureBinding: Int = 4
    static let storageBinding: Int = 8
    static let renderAttachment: Int = 16
}
#else
import Bielik2DWeb
print("Bielik2DWeb \(Bielik2DWeb.version) — built for non-wasi target; run via scripts/build-web.sh")
#endif
