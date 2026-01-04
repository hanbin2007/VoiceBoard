//
//  LogsView.swift
//  VoiceBoard
//
//  Shared logs display view for debugging
//

import SwiftUI

/// A shared view for displaying log messages
struct LogsView: View {
    @ObservedObject var viewModel: ConnectionViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        #if os(iOS)
        NavigationStack {
            logsContent
                .navigationTitle("日志")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("清除") {
                            viewModel.clearLogs()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            dismiss()
                        }
                    }
                }
        }
        #else
        logsContent
        #endif
    }
    
    private var logsContent: some View {
        List {
            ForEach(viewModel.logMessages, id: \.self) { log in
                Text(log)
                    .font(.system(.caption, design: .monospaced))
            }
        }
    }
}
