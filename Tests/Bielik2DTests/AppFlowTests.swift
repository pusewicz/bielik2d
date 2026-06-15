import AppKit
import Foundation
import Testing
import CSDL3
@testable import Bielik2D

private final class Mover {
    var x: Float = 0
}

@Suite(.serialized)
@MainActor
struct AppFlowTests {
    init() { _ = NSApplication.shared }

    @Test func appInstallsItsFlowAsTheAmbientRunner() throws {
        let app = try App(title: "flow-ambient", width: 64, height: 64)
        defer { app.destroy() }
        #expect(Flow.current === app.flow)
    }

    @Test func updateDrivesTheFlowRunnerAndAdvancesTime() throws {
        let app = try App(title: "flow-drive", width: 64, height: 64)
        defer { app.destroy() }
        let m = Mover()
        app.flow.tween(m, \.x, to: 100, over: 0)  // instant — completes on first step
        app.update()
        #expect(m.x == 100)
        #expect(app.flow.activeCount == 0)
        #expect(app.deltaTime >= 0)
        #expect(app.time >= 0)
    }

    @Test func deltaTimeIsClampedToTheFrameCeiling() throws {
        let app = try App(title: "flow-clamp", width: 64, height: 64)
        defer { app.destroy() }
        app.update()  // first delta spans construction + load; must be clamped
        #expect(app.deltaTime <= 0.1)
    }

    @Test func destroyClearsTheAmbientFlow() throws {
        let app = try App(title: "flow-teardown", width: 64, height: 64)
        app.destroy()
        #expect(Flow.current == nil)
    }
}
