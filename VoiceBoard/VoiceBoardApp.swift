//
//  VoiceBoardApp.swift
//  VoiceBoard
//
//  Main app entry point
//

import SwiftUI
import Combine

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
        // Menu Bar Extra
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

// MARK: - macOS App State

#if os(macOS)
class AppState: ObservableObject {
    @Published var isWindowVisible: Bool = true
    
    func hideWindow() {
        if let window = NSApplication.shared.windows.first(where: { $0.title.contains("VoiceBoard") || $0.isKeyWindow }) {
            window.orderOut(nil)
            isWindowVisible = false
        }
    }
    
    func showWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
            isWindowVisible = true
        }
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VoiceBoard")
                .font(.headline)
            
            Divider()
            
            Button(action: {
                appState.showWindow()
            }) {
                Label("显示主窗口", systemImage: "macwindow")
            }
            
            Divider()
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("退出", systemImage: "power")
            }
        }
        .padding()
        .frame(width: 200)
    }
}
#endif
