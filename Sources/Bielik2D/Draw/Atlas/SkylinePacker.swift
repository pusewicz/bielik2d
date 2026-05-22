/// A skyline bottom-left rectangle packer — the bookkeeping behind one atlas page.
/// Tracks the upper "skyline" profile of placed rectangles and drops each new one
/// into the lowest spot it fits, left-aligned. Pure integer math, no GPU: the
/// `SpriteBatch` owns the texture and applies any gutter by inflating sizes.
///
/// There is no free-region reclaim — packed space is never given back (v1 has no
/// atlas decay), so a page only ever grows upward until `insert` returns nil.
struct SkylinePacker {
    /// A horizontal segment of the skyline: everything in `[x, x+width)` is filled
    /// up to height `y`.
    private struct Node {
        var x: Int
        var y: Int
        var width: Int
    }

    let width: Int
    let height: Int
    private var nodes: [Node]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.nodes = [Node(x: 0, y: 0, width: width)]
    }

    /// Reserves a `width`×`height` region and returns its bottom-left corner, or
    /// nil if it doesn't fit. On success the skyline is updated to include it.
    mutating func insert(width w: Int, height h: Int) -> (x: Int, y: Int)? {
        var bestIndex: Int? = nil
        var bestX = 0
        var bestY = Int.max

        for i in nodes.indices {
            guard let y = fits(at: i, width: w, height: h) else { continue }
            // Bottom-left: lowest y wins, then leftmost x.
            if y < bestY || (y == bestY && nodes[i].x < bestX) {
                bestY = y
                bestX = nodes[i].x
                bestIndex = i
            }
        }

        guard let i = bestIndex else { return nil }
        addLevel(at: i, x: bestX, y: bestY, width: w, height: h)
        return (x: bestX, y: bestY)
    }

    /// The skyline height a `w`×`h` rect would rest at if its left edge sits on
    /// node `i`, or nil if it would run off the right edge or top.
    private func fits(at i: Int, width w: Int, height h: Int) -> Int? {
        let x = nodes[i].x
        if x + w > width { return nil }
        var widthLeft = w
        var j = i
        var y = nodes[i].y
        while widthLeft > 0 {
            y = max(y, nodes[j].y)
            if y + h > height { return nil }
            widthLeft -= nodes[j].width
            j += 1
        }
        return y
    }

    /// Places a rect at (x, y) of size (w, h): inserts a new skyline node at its
    /// top, then trims/removes the nodes it now covers and merges flat neighbours.
    private mutating func addLevel(at i: Int, x: Int, y: Int, width w: Int, height h: Int) {
        nodes.insert(Node(x: x, y: y + h, width: w), at: i)

        var j = i + 1
        while j < nodes.count {
            let prevRight = nodes[j - 1].x + nodes[j - 1].width
            guard nodes[j].x < prevRight else { break }
            let shrink = prevRight - nodes[j].x
            nodes[j].x += shrink
            nodes[j].width -= shrink
            if nodes[j].width <= 0 {
                nodes.remove(at: j)
            } else {
                break
            }
        }

        merge()
    }

    /// Collapses adjacent nodes that ended up at the same height.
    private mutating func merge() {
        var i = 0
        while i < nodes.count - 1 {
            if nodes[i].y == nodes[i + 1].y {
                nodes[i].width += nodes[i + 1].width
                nodes.remove(at: i + 1)
            } else {
                i += 1
            }
        }
    }
}
