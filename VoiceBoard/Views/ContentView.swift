//
//  ContentView.swift
//  VoiceBoard
//
//  Router view that displays platform-specific content
//

import SwiftUI

/// Main content view that routes to platform-specific views
struct ContentView: View {
    #if os(iOS)
    @StateObject private var viewModel = ConnectionViewModel()
    @State private var showConnectionSheet = false
    #else
    @EnvironmentObject var viewModel: ConnectionViewModel
    #endif
    
    var body: some View {
        #if os(iOS)
        iOSContentView(
            viewModel: viewModel,
            showConnectionSheet: $showConnectionSheet
        )
        #else
        macOSContentView(viewModel: viewModel)
        #endif
    }
}

#Preview {
    ContentView()
}
