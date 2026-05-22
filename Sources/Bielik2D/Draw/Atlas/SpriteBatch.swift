#if canImport(CSDL3)

/// The runtime atlas compiler — Bielik2D's take on `cute_spritebatch.h`. Images
/// register their pixels into a RAM store and stay hidden behind a `SpriteID`.
/// Each frame the renderer calls `defrag(used:)` to pack any newly-seen images
/// into rolling atlas pages (uploading them to GPU sub-regions), then `resolve`
/// to turn deferred `SpriteInstance`s into batched quads with atlas UVs.
///
/// v1 has no decay: packed space is never reclaimed, so a page only grows until
/// it's full, at which point the next image opens a new page.
final class SpriteBatch {
    private let device: GPUDevice
    let pageSize: Int
    let gutter: Int

    private var images: [SpriteID: ImageBytes] = [:]   // RAM pixel store
    private var resident: [SpriteID: Placement] = [:]
    private(set) var pages: [AtlasPage] = []
    private var nextID: SpriteID = 0

    init(device: GPUDevice, pageSize: Int = 2048, gutter: Int = 1) {
        self.device = device
        self.pageSize = pageSize
        self.gutter = gutter
    }

    /// Stores an image's pixels and returns its handle. No GPU work happens until
    /// the image is first drawn and `defrag` packs it.
    func register(_ image: ImageBytes) -> SpriteID {
        let id = nextID
        nextID += 1
        images[id] = image
        return id
    }

    /// The original (unpadded) pixel size of a registered image.
    func dimensions(of id: SpriteID) -> (width: Int, height: Int)? {
        images[id].map { ($0.width, $0.height) }
    }

    func placement(of id: SpriteID) -> Placement? { resident[id] }

    /// Drops an image from the RAM store. Its atlas space is not reclaimed (v1 has
    /// no decay), so this only matters for memory of the source pixels.
    func unregister(_ id: SpriteID) {
        images[id] = nil
        resident[id] = nil
    }

    /// Packs every used image that isn't already resident into an atlas page and
    /// uploads its pixels. Runs on its own command buffer so the uploads complete
    /// before the frame's render pass samples them.
    func defrag(used: Set<SpriteID>) throws {
        let pending = used.filter { resident[$0] == nil && images[$0] != nil }.sorted()
        guard !pending.isEmpty else { return }

        // Phase 1: pack, create pages, and stage one transfer buffer per image.
        var staged: [(texture: Texture, region: (x: Int, y: Int, width: Int, height: Int),
                      pixelsPerRow: Int, xfer: TransferBuffer)] = []
        for id in pending {
            let raw = images[id]!
            let padded = raw.padded(by: gutter)
            let slot = try place(paddedWidth: padded.width, paddedHeight: padded.height)
            let bytes = padded.pixels.count
            let xfer = try device.makeTransferBuffer(size: bytes, usage: .upload)
            xfer.withMappedMemory { dst in
                padded.pixels.withUnsafeBytes { src in
                    dst.copyMemory(from: src.baseAddress!, byteCount: bytes)
                }
            }
            staged.append((pages[slot.page].texture,
                           (slot.x, slot.y, padded.width, padded.height),
                           padded.width, xfer))
            resident[id] = Placement.compute(
                slotX: slot.x, slotY: slot.y, imageW: raw.width, imageH: raw.height,
                pageW: pages[slot.page].width, pageH: pages[slot.page].height,
                gutter: gutter, page: slot.page)
        }

        // Phase 2: one copy pass uploads them all, then the staging buffers go.
        let cmd = try device.acquireCommandBuffer()
        cmd.withCopyPass { copy in
            for s in staged {
                copy.upload(from: s.xfer, to: s.texture, region: s.region, pixelsPerRow: s.pixelsPerRow)
            }
        }
        cmd.submit()
        for s in staged { s.xfer.destroy() }
    }

    /// Emits a quad per instance into `batcher` using its image's atlas UVs.
    /// Instances are emitted in order, so consecutive sprites sharing a page (and
    /// layer) merge into a single draw call.
    func resolve(_ instances: [SpriteInstance], into batcher: Batcher) {
        for inst in instances {
            guard let p = resident[inst.id] else { continue }
            batcher.setLayer(inst.layer)
            batcher.setTexture(pages[p.page].texture.handle)
            batcher.emitQuadCorners(p0: inst.p0, p1: inst.p1, p2: inst.p2, p3: inst.p3,
                                    uv: p.uvRect, color: inst.color,
                                    scaleData: inst.scaleData, uvBounds: p.uvBounds)
        }
    }

    func destroy() {
        for page in pages { page.texture.destroy() }
        pages.removeAll()
    }

    /// Finds an existing page that fits a padded rect, or opens a new page sized to
    /// hold it (a standard page, or larger for an oversized image).
    private func place(paddedWidth w: Int, paddedHeight h: Int) throws -> (page: Int, x: Int, y: Int) {
        for i in pages.indices {
            if let (x, y) = pages[i].packer.insert(width: w, height: h) {
                return (i, x, y)
            }
        }
        let pw = max(pageSize, w)
        let ph = max(pageSize, h)
        let tex = try device.makeTexture(width: pw, height: ph, format: .rgba8Unorm, usage: .sampler)
        pages.append(AtlasPage(texture: tex, width: pw, height: ph))
        let i = pages.count - 1
        let (x, y) = pages[i].packer.insert(width: w, height: h)!  // fits by construction
        return (i, x, y)
    }
}
#endif
