#if canImport(CSDL3)
import CSDL3
import Foundation

public struct ImageBytes {
    public let width: Int
    public let height: Int
    /// Tightly-packed RGBA8 pixel data (no row padding).
    public let pixels: Data

    /// Wraps tightly-packed RGBA8 pixels — useful for procedurally generated images.
    public init(width: Int, height: Int, pixels: Data) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }
}

public enum SDL3AssetLoader {
    public static func loadImage(path: String) throws -> ImageBytes {
        guard let surface = IMG_Load(path) else {
            throw SpriteError.loadFailed(lastSDLError())
        }
        defer { SDL_DestroySurface(surface) }

        guard let rgba = SDL_ConvertSurface(surface, SDL_PIXELFORMAT_RGBA32) else {
            throw SpriteError.loadFailed(lastSDLError())
        }
        defer { SDL_DestroySurface(rgba) }

        let w = Int(rgba.pointee.w)
        let h = Int(rgba.pointee.h)
        let pitch = Int(rgba.pointee.pitch)
        let rowBytes = w * 4
        let dst = NSMutableData(length: rowBytes * h)!
        let dstBase = dst.mutableBytes.assumingMemoryBound(to: UInt8.self)
        let srcBase = rgba.pointee.pixels!.assumingMemoryBound(to: UInt8.self)
        for row in 0..<h {
            let srcRow = srcBase.advanced(by: row * pitch)
            let dstRow = dstBase.advanced(by: row * rowBytes)
            dstRow.update(from: srcRow, count: rowBytes)
        }
        return ImageBytes(width: w, height: h, pixels: dst as Data)
    }
}

/// Native `AssetLoader`: decodes images synchronously off disk (via
/// `SDL3AssetLoader.loadImage`) and caches the decoded RGBA for synchronous
/// per-frame lookup. `prefetch` completes immediately on native.
public final class SDL3AssetCache: AssetLoader, @unchecked Sendable {
    private var cache: [String: LoadedImage] = [:]

    public init() {}

    public func prefetch(_ paths: [String]) async throws {
        for path in paths where cache[path] == nil {
            let bytes = try SDL3AssetLoader.loadImage(path: path)
            cache[path] = LoadedImage(
                width: bytes.width,
                height: bytes.height,
                rgba: [UInt8](bytes.pixels)
            )
        }
    }

    public func image(_ path: String) -> LoadedImage? {
        cache[path]
    }
}
#endif
