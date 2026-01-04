//
//  SpeechRecognizer.swift
//  VoiceBoard
//
//  Handles speech recognition using Apple's Speech framework (iOS only)
//

#if os(iOS)
import Foundation
import Speech
import AVFoundation
import Combine

/// Manages real-time speech recognition
@MainActor
class SpeechRecognizer: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The recognized transcript text
    @Published var transcript: String = ""
    
    /// Whether currently recording
    @Published var isRecording: Bool = false
    
    /// Error message if any
    @Published var errorMessage: String?
    
    /// Authorization status
    @Published var isAuthorized: Bool = false
    
    // MARK: - Private Properties
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Initialization
    
    init() {
        // Use Chinese (Simplified) as default, fallback to device locale
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
            ?? SFSpeechRecognizer(locale: Locale.current)
        
        requestAuthorization()
    }
    
    // MARK: - Authorization
    
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                switch status {
                case .authorized:
                    self?.isAuthorized = true
                case .denied:
                    self?.errorMessage = "语音识别权限被拒绝"
                    self?.isAuthorized = false
                case .restricted:
                    self?.errorMessage = "语音识别在此设备上受限"
                    self?.isAuthorized = false
                case .notDetermined:
                    self?.isAuthorized = false
                @unknown default:
                    self?.isAuthorized = false
                }
            }
        }
    }
    
    // MARK: - Recording Control
    
    /// Start speech recognition
    func startRecording() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "语音识别不可用"
            return
        }
        
        // Stop any existing task
        stopRecording()
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "无法配置音频会话: \(error.localizedDescription)"
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "无法创建识别请求"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        
        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    self?.transcript = result.bestTranscription.formattedString
                }
                
                if error != nil {
                    self?.stopRecording()
                }
            }
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            transcript = ""
            errorMessage = nil
        } catch {
            errorMessage = "无法启动音频引擎: \(error.localizedDescription)"
        }
    }
    
    /// Stop speech recognition
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRecording = false
    }
    
    /// Toggle recording state
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
}
#endif
