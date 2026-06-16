#if os(WASI)
import JavaScriptKit
import Bielik2D

public enum WebAssetError: Error, CustomStringConvertible {
    case fetchFailed(String)
    case decodeFailed(String)

    public var description: String {
        switch self {
        case .fetchFailed(let url): "fetch failed for \(url)"
        case .decodeFailed(let url): "createImageBitmap failed for \(url)"
        }
    }
}

/// Web-side `AssetLoader`: `prefetch` fetches each path, decodes it to an
/// `ImageBitmap`, then reads back tightly-packed RGBA8 bytes into a cached
/// `LoadedImage`; `image` serves that cache synchronously for per-frame scene
/// code (mirroring how the native loader reads from disk). The decode draws the
/// `ImageBitmap` onto an `OffscreenCanvas` 2D context and pulls `getImageData`,
/// which yields top-left-origin RGBA8 — exactly the `LoadedImage` contract.
public final class WebAssetLoader: AssetLoader, @unchecked Sendable {
    private var cache: [String: LoadedImage] = [:]

    public init() {}

    public func prefetch(_ paths: [String]) async throws {
        for path in paths {
            if cache[path] != nil { continue }
            let bitmap = try await WebAssetLoader.loadImageBitmap(url: path)
            cache[path] = try WebAssetLoader.decode(bitmap, url: path)
        }
    }

    public func image(_ path: String) -> LoadedImage? { cache[path] }

    /// Fetches `url` and decodes the response body as an `ImageBitmap` ready
    /// to upload into a WebGPU texture via `queue.copyExternalImageToTexture`.
    public static func loadImageBitmap(url: String) async throws -> JSObject {
        let fetchResult = try await WebJS.await_(JSObject.global.fetch.function!(url))
        guard let response = fetchResult.object else {
            throw WebAssetError.fetchFailed(url)
        }
        let ok = response["ok"].boolean ?? false
        if !ok { throw WebAssetError.fetchFailed(url) }

        let blobResult = try await WebJS.await_(response.blob!())
        guard let blob = blobResult.object else {
            throw WebAssetError.fetchFailed(url)
        }
        let bitmapResult = try await WebJS.await_(JSObject.global.createImageBitmap.function!(blob))
        guard let bitmap = bitmapResult.object else {
            throw WebAssetError.decodeFailed(url)
        }
        return bitmap
    }

    /// Draws `bitmap` onto an offscreen 2D canvas and reads its pixels back as a
    /// tightly-packed top-left-origin RGBA8 `LoadedImage`.
    static func decode(_ bitmap: JSObject, url: String) throws -> LoadedImage {
        let width = Int(bitmap["width"].number ?? 0)
        let height = Int(bitmap["height"].number ?? 0)
        guard width > 0, height > 0 else { throw WebAssetError.decodeFailed(url) }

        guard let canvasClass = JSObject.global.OffscreenCanvas.function else {
            throw WebAssetError.decodeFailed(url)
        }
        let canvasObj = canvasClass.new(Double(width), Double(height))
        guard let ctx = canvasObj.getContext!("2d").object else {
            throw WebAssetError.decodeFailed(url)
        }
        _ = ctx.drawImage!(bitmap, 0, 0)
        // `getImageData().data` is a `Uint8ClampedArray`; wrap its backing buffer
        // in a plain `Uint8Array` so JavaScriptKit's `JSTypedArray<UInt8>` can view
        // it, then copy the tightly-packed RGBA8 bytes out.
        guard let imageData = ctx.getImageData!(0, 0, Double(width), Double(height)).object,
              let buffer = imageData["data"].object?["buffer"].object,
              let u8class = JSObject.global.Uint8Array.function else {
            throw WebAssetError.decodeFailed(url)
        }
        let view = u8class.new(buffer)
        let typed = JSTypedArray<UInt8>(unsafelyWrapping: view)
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        rgba.withUnsafeMutableBufferPointer { dst in
            typed.copyMemory(to: dst)
        }
        return LoadedImage(width: width, height: height, rgba: rgba)
    }
}
#endif
