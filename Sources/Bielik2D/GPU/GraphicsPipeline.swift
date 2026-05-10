import CSDL3

public enum VertexFormat: Sendable {
    case float, float2, float3, float4
    case ubyte4Norm

    var sdlValue: SDL_GPUVertexElementFormat {
        switch self {
        case .float: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT
        case .float2: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2
        case .float3: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3
        case .float4: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4
        case .ubyte4Norm: SDL_GPU_VERTEXELEMENTFORMAT_UBYTE4_NORM
        }
    }
}

public struct VertexAttribute: Sendable {
    public var name: String
    public var location: UInt32
    public var format: VertexFormat
    public var offset: UInt32

    public init(name: String = "", location: UInt32, format: VertexFormat, offset: UInt32) {
        self.name = name
        self.location = location
        self.format = format
        self.offset = offset
    }
}

public struct VertexBufferDescriptor: Sendable {
    public var stride: Int
    public var attributes: [VertexAttribute]

    public init(stride: Int, attributes: [VertexAttribute]) {
        self.stride = stride
        self.attributes = attributes
    }
}


extension BlendMode {
    var sdlState: SDL_GPUColorTargetBlendState {
        var s = SDL_GPUColorTargetBlendState()
        switch self {
        case .none:
            s.enable_blend = false
        case .alpha:
            s.enable_blend = true
            s.src_color_blendfactor = SDL_GPU_BLENDFACTOR_SRC_ALPHA
            s.dst_color_blendfactor = SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA
            s.color_blend_op = SDL_GPU_BLENDOP_ADD
            s.src_alpha_blendfactor = SDL_GPU_BLENDFACTOR_ONE
            s.dst_alpha_blendfactor = SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA
            s.alpha_blend_op = SDL_GPU_BLENDOP_ADD
        case .premultipliedAlpha:
            s.enable_blend = true
            s.src_color_blendfactor = SDL_GPU_BLENDFACTOR_ONE
            s.dst_color_blendfactor = SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA
            s.color_blend_op = SDL_GPU_BLENDOP_ADD
            s.src_alpha_blendfactor = SDL_GPU_BLENDFACTOR_ONE
            s.dst_alpha_blendfactor = SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA
            s.alpha_blend_op = SDL_GPU_BLENDOP_ADD
        case .additive:
            s.enable_blend = true
            s.src_color_blendfactor = SDL_GPU_BLENDFACTOR_ONE
            s.dst_color_blendfactor = SDL_GPU_BLENDFACTOR_ONE
            s.color_blend_op = SDL_GPU_BLENDOP_ADD
            s.src_alpha_blendfactor = SDL_GPU_BLENDFACTOR_ONE
            s.dst_alpha_blendfactor = SDL_GPU_BLENDFACTOR_ONE
            s.alpha_blend_op = SDL_GPU_BLENDOP_ADD
        }
        s.color_write_mask = SDL_GPUColorComponentFlags(SDL_GPU_COLORCOMPONENT_R | SDL_GPU_COLORCOMPONENT_G | SDL_GPU_COLORCOMPONENT_B | SDL_GPU_COLORCOMPONENT_A)
        return s
    }
}

public struct GraphicsPipeline {
    public let handle: OpaquePointer
    let device: OpaquePointer

    public func destroy() {
        SDL_ReleaseGPUGraphicsPipeline(device, handle)
    }
}

extension GPUDevice {
    public func makePipeline(vertex: Shader,
                             fragment: Shader,
                             vertexBuffer: VertexBufferDescriptor,
                             colorTargetFormat: TextureFormat,
                             blendMode: BlendMode = .none) throws -> GraphicsPipeline {
        var attrs: [SDL_GPUVertexAttribute] = vertexBuffer.attributes.map { a in
            var x = SDL_GPUVertexAttribute()
            x.location = a.location
            x.buffer_slot = 0
            x.format = a.format.sdlValue
            x.offset = a.offset
            return x
        }
        var bufferDesc = SDL_GPUVertexBufferDescription()
        bufferDesc.slot = 0
        bufferDesc.pitch = UInt32(vertexBuffer.stride)
        bufferDesc.input_rate = SDL_GPU_VERTEXINPUTRATE_VERTEX

        var colorState = SDL_GPUColorTargetDescription()
        colorState.format = colorTargetFormat.sdlValue
        colorState.blend_state = blendMode.sdlState

        return try attrs.withUnsafeBufferPointer { attrPtr -> GraphicsPipeline in
            try withUnsafePointer(to: &bufferDesc) { bufferPtr in
                try withUnsafePointer(to: &colorState) { colorPtr in
                    var info = SDL_GPUGraphicsPipelineCreateInfo()
                    info.vertex_shader = vertex.handle
                    info.fragment_shader = fragment.handle
                    info.vertex_input_state.vertex_buffer_descriptions = bufferPtr
                    info.vertex_input_state.num_vertex_buffers = 1
                    info.vertex_input_state.vertex_attributes = attrPtr.baseAddress
                    info.vertex_input_state.num_vertex_attributes = UInt32(attrPtr.count)
                    info.primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLELIST
                    info.target_info.color_target_descriptions = colorPtr
                    info.target_info.num_color_targets = 1
                    guard let pipe = SDL_CreateGPUGraphicsPipeline(handle, &info) else {
                        throw GPUError.createPipeline(lastSDLError())
                    }
                    return GraphicsPipeline(handle: pipe, device: handle)
                }
            }
        }
    }
}
