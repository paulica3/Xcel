import SwiftUI
import Speech
import AVFoundation

// On-device speech-to-text for the evening log. One engine per field; starting
// a new one stops any other so two mics never record at once.
@Observable
final class DictationEngine {
    var isRecording = false
    var available = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))?.isAvailable ?? false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var baseText = ""
    private var onUpdate: ((String) -> Void)?

    static weak var active: DictationEngine?

    func start(current: String, onUpdate: @escaping (String) -> Void) {
        DictationEngine.active?.stop()
        DictationEngine.active = self
        self.onUpdate = onUpdate
        self.baseText = current.trimmingCharacters(in: .whitespacesAndNewlines)

        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                guard granted else { return }
                DispatchQueue.main.async { self.beginAudio() }
            }
        }
    }

    func stop() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if DictationEngine.active === self { DictationEngine.active = nil }
    }

    private func beginAudio() {
        guard let recognizer, recognizer.isAvailable else { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do { try audioEngine.start() } catch { return }
        isRecording = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let spoken = result.bestTranscription.formattedString
                let combined = self.baseText.isEmpty ? spoken : "\(self.baseText) \(spoken)"
                DispatchQueue.main.async { self.onUpdate?(combined) }
            }
            if error != nil || (result?.isFinal ?? false) {
                DispatchQueue.main.async { self.stop() }
            }
        }
    }
}

// A mic toggle that dictates into a bound string. Hidden when unavailable.
struct MicButton: View {
    @Binding var text: String
    let accent: Color
    @State private var engine = DictationEngine()

    var body: some View {
        if engine.available {
            Button {
                if engine.isRecording {
                    engine.stop()
                } else {
                    engine.start(current: text) { text = $0 }
                }
            } label: {
                Image(systemName: engine.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(engine.isRecording ? Color.eliminationRed : accent.opacity(0.8))
                    .frame(width: 34, height: 34)
                    .background(Color(white: 0.1))
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(engine.isRecording ? Color.eliminationRed : .clear, lineWidth: 1.5)
                            .scaleEffect(engine.isRecording ? 1.15 : 1)
                            .opacity(engine.isRecording ? 0.6 : 0)
                            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                                       value: engine.isRecording)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}
