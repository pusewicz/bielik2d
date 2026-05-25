import Testing
@testable import Bielik2D

// Pure device-layer tests: no SDL device needed. Hot-plug routing is exercised
// by the demo; here we prove the state machine and the SDL axis-range math.

@Test func disconnectedGamepadAnswersFalseAndZero() {
    let g = Gamepad.disconnected
    #expect(!g.isConnected)
    #expect(!g.down(.south))
    #expect(g.leftStick == SIMD2<Float>.zero)
    #expect(g.leftTrigger == 0)
}

@Test func gamepadButtonTransitionsTrackPressAndRelease() {
    let g = Gamepad(connected: true)
    g.beginFrame()
    g.press(.south)
    #expect(g.pressed(.south))
    #expect(g.down(.south))
    g.beginFrame()
    #expect(!g.pressed(.south))  // no longer fresh
    #expect(g.down(.south))       // still held
    g.beginFrame()
    g.release(.south)
    #expect(g.released(.south))
    #expect(!g.down(.south))
}

@Test func gamepadAxesStoreStickAndTriggerValues() {
    let g = Gamepad(connected: true)
    g.setAxis(.leftX, 0.5)
    g.setAxis(.leftY, -0.25)
    g.setAxis(.rightTrigger, 0.75)
    #expect(g.leftStick == SIMD2<Float>(0.5, -0.25))
    #expect(g.rightTrigger == 0.75)
}

@Test func axisNormalizationMapsTheSDLIntegerRange() {
    #expect(abs(Gamepad.normalizedAxis(32767) - 1) < 1e-4)
    #expect(abs(Gamepad.normalizedAxis(-32768) - (-1)) < 1e-4)  // clamped, not -1.00003
    #expect(abs(Gamepad.normalizedAxis(0)) < 1e-4)
    #expect(abs(Gamepad.normalizedTrigger(16384) - 0.5) < 0.01)
    #expect(Gamepad.normalizedTrigger(0) == 0)
}

@Test func inputExposesConnectedGamepadsBySlot() {
    let input = Input()
    #expect(!input.gamepad(0).isConnected)  // none connected yet

    let pad = input.connectGamepad(id: 42)
    pad.beginFrame()
    pad.press(.start)
    #expect(input.gamepad(0).isConnected)
    #expect(input.gamepad(0).down(.start))

    input.disconnectGamepad(id: 42)
    #expect(!input.gamepad(0).isConnected)
}
