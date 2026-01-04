//
//  VoiceBoardApp.swift
//  VoiceBoard
//
//  Main app entry point
//

import SwiftUI

@main
struct VoiceBoardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 500)
        #endif
    }
}
