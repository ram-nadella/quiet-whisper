// QuietWhisperApp.swift
// Entry point. Single window, no menubar item, no extra Settings scene.

import SwiftUI
import SwiftData

@main
struct QuietWhisperApp: App {
    init() {
        FontRegistry.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 880, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1180, height: 780)
        .modelContainer(for: [Snippet.self])
    }
}
