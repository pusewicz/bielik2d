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

    // Vertex layout: the full Bielik2D.Vertex.bufferLayout. The sprite shader
    // consumes locations 0..8 plus the atlas attributes at 10 (attributes) and
    // 11 (uvBounds). WebGPU requires every shader-consumed location to be present
    // in the vertex state; the unused posH at location 9 is harmless to include.
    let attrs = Vertex.bufferLayout.attributes.map { attr -> JSObject in
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

    // Vertex buffer sized for a comfortable per-frame upper bound. Bielik2D's
    // Batcher resets in place each frame so allocations don't churn.
    let maxVertexCount = 6 * 1024
    let vertexBuffer = backend.device.createBuffer!(WebJS.object([
        "size": .number(Double(maxVertexCount * MemoryLayout<Vertex>.stride)),
        "usage": .number(Double(GPUBufferUsage.vertex | GPUBufferUsage.copyDst)),
    ])).object!

    let draw = Draw()
    draw.reserveVertexCapacity(maxVertexCount)

    // Pre-rasterise the static label and build a matching bind group + quad.
    let label = WebTextRasterizer.rasterize("Hello, Bielik!", fontCSS: "32px -apple-system, sans-serif")!
    let (labelTexture, labelW, labelH) = backend.makeTexture(from: label.canvas)
    let labelBindGroup = backend.device.createBindGroup!(WebJS.object([
        "layout": .object(bgl1),
        "entries": .object(WebJS.array([
            WebJS.object([
                "binding": .number(0),
                "resource": .object(labelTexture.createView!().object!),
            ]),
            WebJS.object([
                "binding": .number(1),
                "resource": .object(sampler),
            ]),
        ])),
    ])).object!
    let labelOrigin = SIMD2<Float>(40, 40)
    let labelVerts: [Vertex] = {
        let w = Float(labelW), h = Float(labelH)
        let c = SIMD4<Float>(1, 1, 1, 1)
        return [
            Vertex(pos: SIMD2(labelOrigin.x,     labelOrigin.y    ), uv: SIMD2(0, 0), color: c),
            Vertex(pos: SIMD2(labelOrigin.x + w, labelOrigin.y    ), uv: SIMD2(1, 0), color: c),
            Vertex(pos: SIMD2(labelOrigin.x + w, labelOrigin.y + h), uv: SIMD2(1, 1), color: c),
            Vertex(pos: SIMD2(labelOrigin.x,     labelOrigin.y    ), uv: SIMD2(0, 0), color: c),
            Vertex(pos: SIMD2(labelOrigin.x + w, labelOrigin.y + h), uv: SIMD2(1, 1), color: c),
            Vertex(pos: SIMD2(labelOrigin.x,     labelOrigin.y + h), uv: SIMD2(0, 1), color: c),
        ]
    }()
    let labelBuffer = backend.device.createBuffer!(WebJS.object([
        "size": .number(Double(labelVerts.count * MemoryLayout<Vertex>.stride)),
        "usage": .number(Double(GPUBufferUsage.vertex | GPUBufferUsage.copyDst)),
    ])).object!
    labelVerts.withUnsafeBytes { ptr in
        let bytes = Array(ptr.bindMemory(to: UInt8.self))
        _ = backend.queue.writeBuffer!(labelBuffer, 0, JSTypedArray<UInt8>(bytes).jsObject)
    }
    let labelVertexCount = labelVerts.count

    DemoState.pipeline = pipeline
    DemoState.vertexBuffer = vertexBuffer
    DemoState.bindGroup0 = bindGroup0
    DemoState.bindGroup1 = bindGroup1

    let cx = Float(platform.size.x) * 0.5
    let cy = Float(platform.size.y) * 0.5
    let halfW = Float(spriteW) * 0.5
    let halfH = Float(spriteH) * 0.5
    let white = SIMD4<Float>(1, 1, 1, 1)
    let spriteUV = Rect(x: 0, y: 0, width: 1, height: 1)

    // The WebGPU backend is a RenderBackend, so the demo queues into a Draw and
    // flushes through it — identical to the native path, just a different backend.
    let webRenderer = WebRenderer(
        backend: backend, pipeline: pipeline,
        vertexBuffer: vertexBuffer, maxVertexCount: maxVertexCount,
        bindGroup0: bindGroup0, bindGroup1: bindGroup1,
        labelBindGroup: labelBindGroup, labelBuffer: labelBuffer,
        labelVertexCount: labelVertexCount
    )

    platform.run { _ in
        // Sprite (textured quad).
        draw.quad(
            rect: Rect(x: cx - halfW, y: cy - halfH, width: halfW * 2, height: halfH * 2),
            uv: spriteUV,
            color: white
        )
        // SDF circle to the right of the sprite.
        draw.circleFill(center: SIMD2(cx + halfW + 120, cy), radius: 60, color: Color(r: 0.4, g: 0.8, b: 1.0))
        // SDF line below the sprite.
        draw.line(from: SIMD2(cx - 220, cy + halfH + 80), to: SIMD2(cx + 220, cy + halfH + 80),
                  thickness: 8, color: Color(r: 1.0, g: 0.9, b: 0.3))

        draw.flush(through: webRenderer, camera: camera, clear: Color(r: 0.10, g: 0.12, b: 0.18))
    }
}
#else
import Bielik2DWeb
print("Bielik2DWeb \(Bielik2DWeb.version) — built for non-wasi target; run via scripts/build-web.sh")
#endif
