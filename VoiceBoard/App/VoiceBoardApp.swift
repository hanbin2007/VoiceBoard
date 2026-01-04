//
//  VoiceBoardApp.swift
//  VoiceBoard
//
//  Main app entry point
//

import SwiftUI

@main
struct VoiceBoardApp: App {
    #if os(macOS)
    @StateObject private var appState = AppState()
    #endif
    
    var body: some Scene {
        WindowGroup {
            ContentView()
            #if os(macOS)
                .environmentObject(appState)
            #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 700, height: 500)
        #endif
        
        #if os(macOS)
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: "mic.badge.xmark")
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
