import Foundation
import AVFoundation
import Speech

// MARK: - Speech Recognition Service (Build 1 Step 5)
// Push-to-talk wrapper around SFSpeechRecognizer + AVAudioEngine. The session
// holds the mic button down, watches `transcript` update live, and on release
// reads the final transcript and submits it to Cyrano.

@MainActor
@Observable
final class SpeechService: NSObject {
    static let shared = SpeechService()

    var transcript: String = ""
    var isRecording = false
    var authStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private var recognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    override private init() {
        super.init()
        authStatus = SFSpeechRecognizer.authorizationStatus()
    }

    // Asks for both speech-recognition and microphone permissions on first use.
    // Returns true only when both are granted.
    func requestAuthorization() async -> Bool {
        let speechGranted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in self.authStatus = status }
                cont.resume(returning: status == .authorized)
            }
        }
        guard speechGranted else { return false }
        let micGranted = await AVAudioApplication.requestRecordPermission()
        return micGranted
    }

    // Begins live transcription. The caller is responsible for calling stop()
    // when the user releases the mic button — that finalizes the transcript.
    func start() throws {
        guard !isRecording else { return }
        guard let recognizer, recognizer.isAvailable else { throw RWError.api }

        // Reset state
        transcript = ""
        task?.cancel()
        task = nil

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: [.notifyOthersOnDeactivation])

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.cleanup()
                }
            }
        }

        isRecording = true
    }

    // Stops capture and returns the final transcript at the moment of release.
    @discardableResult
    func stop() -> String {
        request?.endAudio()
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        isRecording = false
        return transcript
    }

    private func cleanup() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request = nil
        task = nil
        isRecording = false
    }
}
