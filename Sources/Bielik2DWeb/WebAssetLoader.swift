#if os(WASI)
import JavaScriptKit

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

public enum WebAssetLoader {
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
}
#endif
