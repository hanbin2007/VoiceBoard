//
//  MenuBarView.swift
//  VoiceBoard
//
//  Menu bar extra view for macOS
//

#if os(macOS)
import SwiftUI

/// Menu bar dropdown view for quick access
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
