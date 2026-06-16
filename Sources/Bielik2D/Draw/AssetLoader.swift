/// Loads image bytes/textures for sprites. Native loads synchronously from disk;
/// web fetches asynchronously. The demo preloads through `prefetch` before its
/// loop so per-frame scene code reads from the populated cache synchronously.
public protocol AssetLoader: AnyObject {
    /// Asynchronously ensure `paths` are resident. On native this may complete
    /// immediately; on web it awaits `fetch`/`createImageBitmap`.
    func prefetch(_ paths: [String]) async throws
    /// Synchronous lookup of an already-prefetched image's decoded RGBA bytes
    /// and size, or nil if not yet resident.
    func image(_ path: String) -> LoadedImage?
}

/// Decoded image pixels handed across the asset seam. RGBA8, tightly packed,
/// top-left origin.
public struct LoadedImage: Sendable {
    public let width: Int
    public let height: Int
    public let rgba: [UInt8]
    public init(width: Int, height: Int, rgba: [UInt8]) {
        self.width = width
        self.height = height
        self.rgba = rgba
    }
}
