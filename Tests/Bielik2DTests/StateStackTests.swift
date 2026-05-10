import Testing
@testable import Bielik2D

@Test func stateStackPushPopPeek() {
    var s = StateStack(initial: 1)
    #expect(s.peek == 1)
    s.push(2)
    #expect(s.peek == 2)
    s.push(3)
    #expect(s.peek == 3)
    #expect(s.pop() == 3)
    #expect(s.peek == 2)
    #expect(s.pop() == 2)
    #expect(s.peek == 1)
}

@Test func stateStackPopBelowInitialReturnsNil() {
    var s = StateStack(initial: 0)
    #expect(s.pop() == nil)
    #expect(s.peek == 0)
}
