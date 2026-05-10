/// A stack that always holds at least the initial value — `peek` is always defined
/// and `pop()` refuses to underflow.
public struct StateStack<T> {
    private var stack: [T]

    public init(initial: T) {
        self.stack = [initial]
    }

    public var peek: T { stack.last! }

    public mutating func push(_ value: T) {
        stack.append(value)
    }

    @discardableResult
    public mutating func pop() -> T? {
        guard stack.count > 1 else { return nil }
        return stack.removeLast()
    }
}
