public struct Rect: Equatable, Sendable {
    public var x: Float
    public var y: Float
    public var width: Float
    public var height: Float

    public init(x: Float, y: Float, width: Float, height: Float) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: Float { x }
    public var minY: Float { y }
    public var maxX: Float { x + width }
    public var maxY: Float { y + height }
}
