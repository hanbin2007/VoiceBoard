//
//  iOSSettingsView.swift
//  VoiceBoard
//
//  Settings page for iOS with app preferences
//

#if os(iOS)
import SwiftUI
import Combine

/// Settings manager for iOS app preferences
class iOSSettings: ObservableObject {
    static let shared = iOSSettings()
    
    private let keepScreenAwakeKey = "VoiceBoard.KeepScreenAwake"
    
    @Published var keepScreenAwake: Bool {
        didSet {
            UserDefaults.standard.set(keepScreenAwake, forKey: keepScreenAwakeKey)
            updateIdleTimer()
        }
    }
    
    private init() {
        // Default to true for keep screen awake
        keepScreenAwake = UserDefaults.standard.object(forKey: keepScreenAwakeKey) as? Bool ?? true
        updateIdleTimer()
    }
    
    func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = keepScreenAwake
    }
}

/// iOS Settings View
struct iOSSettingsView: View {
    @ObservedObject var settings = iOSSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $settings.keepScreenAwake) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("保持屏幕常亮")
                                Text("防止设备在使用时自动熄屏")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "sun.max.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                } header: {
                    Text("显示")
                }
                
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
#endif
