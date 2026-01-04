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
    @StateObject private var viewModel = ConnectionViewModel()
    #endif
    
    var body: some Scene {
        WindowGroup {
            ContentView()
            #if os(macOS)
                .environmentObject(appState)
                .environmentObject(viewModel)
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
                .environmentObject(viewModel)
        } label: {
            Image(systemName: viewModel.isConnected ? "mic.fill" : "mic.badge.xmark")
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
