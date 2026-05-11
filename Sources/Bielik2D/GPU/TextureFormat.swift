public enum TextureFormat: Hashable, Sendable {
    case rgba8Unorm
    case bgra8Unorm

    public var bytesPerPixel: Int {
        switch self {
        case .rgba8Unorm, .bgra8Unorm: 4
        }
    }
}
