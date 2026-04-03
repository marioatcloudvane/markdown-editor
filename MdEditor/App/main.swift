import AppKit

// Explicitly create the delegate and register it before starting the run loop.
// @main on an NSApplicationDelegate class with no NIB does NOT auto-register
// the delegate, so applicationWillFinishLaunching is never called.
// MainActor.assumeIsolated is safe here — main.swift runs on the main thread.
MainActor.assumeIsolated {
    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
    NSApplication.shared.run()
}
