import Foundation
import Testing
@testable import Bielik2D

// Every easing maps the unit interval onto itself: f(0) == 0 and f(1) == 1.
private let allEasings: [Easing] = [
    .linear,
    .inQuad, .outQuad, .inOutQuad,
    .inCubic, .outCubic, .inOutCubic,
    .inQuart, .outQuart, .inOutQuart,
    .inQuint, .outQuint, .inOutQuint,
    .inSine, .outSine, .inOutSine,
    .inExpo, .outExpo, .inOutExpo,
    .inCirc, .outCirc, .inOutCirc,
    .inBack, .outBack, .inOutBack,
    .inElastic, .outElastic, .inOutElastic,
    .inBounce, .outBounce, .inOutBounce,
]

@Test func everyEasingPinsTheEndpoints() {
    for e in allEasings {
        #expect(abs(e.value(at: 0) - 0) < 1e-5, "\(e) at 0")
        #expect(abs(e.value(at: 1) - 1) < 1e-5, "\(e) at 1")
    }
}

@Test func linearIsIdentity() {
    #expect(Easing.linear.value(at: 0.25) == 0.25)
    #expect(Easing.linear.value(at: 0.5) == 0.5)
    #expect(Easing.linear.value(at: 0.75) == 0.75)
}

@Test func quadKnownValues() {
    #expect(abs(Easing.inQuad.value(at: 0.5) - 0.25) < 1e-6)
    #expect(abs(Easing.outQuad.value(at: 0.5) - 0.75) < 1e-6)
    #expect(abs(Easing.inOutQuad.value(at: 0.5) - 0.5) < 1e-6)
}

@Test func cubicKnownValues() {
    #expect(abs(Easing.inCubic.value(at: 0.5) - 0.125) < 1e-6)
    #expect(abs(Easing.outCubic.value(at: 0.5) - 0.875) < 1e-6)
}

// out(t) is the mirror of in(t): out(t) == 1 - in(1 - t).
@Test func outIsTheMirrorOfIn() {
    let pairs: [(Easing, Easing)] = [
        (.inQuad, .outQuad), (.inCubic, .outCubic), (.inQuint, .outQuint),
        (.inSine, .outSine), (.inCirc, .outCirc), (.inBounce, .outBounce),
    ]
    for (inE, outE) in pairs {
        for t in stride(from: Float(0), through: 1, by: 0.1) {
            #expect(abs(outE.value(at: t) - (1 - inE.value(at: 1 - t))) < 1e-5, "\(outE) vs \(inE) at \(t)")
        }
    }
}

// inOut variants cross the midpoint at exactly 0.5.
@Test func inOutVariantsCrossTheMidpoint() {
    let inOuts: [Easing] = [.inOutQuad, .inOutCubic, .inOutQuart, .inOutQuint,
                            .inOutSine, .inOutExpo, .inOutCirc]
    for e in inOuts {
        #expect(abs(e.value(at: 0.5) - 0.5) < 1e-5, "\(e) at 0.5")
    }
}

@Test func backEasingOvershoots() {
    // outBack rises above 1 before settling — the signature overshoot.
    #expect(Easing.outBack.value(at: 0.7) > 1.0)
}
