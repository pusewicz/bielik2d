/// Per-frame keyboard state. Holds the set of keys down now and the set down on
/// the previous frame, so transitions (`pressed`/`released`) fall out of a diff.
///
/// The mutators (`beginFrame`/`press`/`release`) are internal: the platform's
/// event pump drives them. Game code only queries.
public final class Keyboard {
    private var current: Set<Key> = []
    private var previous: Set<Key> = []

    /// Snapshot the current state as "previous" before this frame's events apply.
    func beginFrame() { previous = current }

    func press(_ key: Key) { current.insert(key) }
    func release(_ key: Key) { current.remove(key) }

    /// True while the key is held.
    public func down(_ key: Key) -> Bool { current.contains(key) }

    /// True only on the frame the key transitioned up → down.
    public func pressed(_ key: Key) -> Bool {
        current.contains(key) && !previous.contains(key)
    }

    /// True only on the frame the key transitioned down → up.
    public func released(_ key: Key) -> Bool {
        !current.contains(key) && previous.contains(key)
    }

    /// The modifier keys currently held.
    public var modifiers: KeyModifiers {
        var m: KeyModifiers = []
        if down(.leftShift) || down(.rightShift) { m.insert(.shift) }
        if down(.leftControl) || down(.rightControl) { m.insert(.control) }
        if down(.leftOption) || down(.rightOption) { m.insert(.option) }
        if down(.leftCommand) || down(.rightCommand) { m.insert(.command) }
        return m
    }
}
