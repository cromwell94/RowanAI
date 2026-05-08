import Foundation
import AVFoundation

// MARK: - ElevenLabs TTS Service
// POSTs text to the `eleven` Supabase edge function (which holds the
// ElevenLabs API key server-side), persists the audio/mpeg body to a temp
// file, and plays it back with AVAudioPlayer.
//
// AUTH: Supabase publishable (anon) key on Authorization + apikey headers.
// The real ElevenLabs key never ships in the app binary; the edge function
// injects it server-side and validates voice_id/model_id/text length.
//
// Logging: every step prints "[ElevenLabs]" — enabled in DEBUG and Release
// so we can diagnose voice issues from console logs without a separate build.
// Sensitive values (publishable key body) are masked.

// MARK: - Per-voice settings

struct VoiceSettings: Codable, Equatable {
    var stability: Double
    var similarityBoost: Double
    var style: Double
    var useSpeakerBoost: Bool = true
}

@MainActor
@Observable
final class ElevenLabsService {
    static let shared = ElevenLabsService()

    // Supabase edge function — holds the real ElevenLabs key server-side.
    // The publishable (anon) key below is public by design; the function
    // gate-keeps voice_id, model_id, and text length.
    private let url = "https://rvdzakkvggqxqrrvtfiq.supabase.co/functions/v1/eleven"
    private let publishableKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ2ZHpha2t2Z2dxeHFycnZ0ZmlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc4MTk2NzYsImV4cCI6MjA5MzM5NTY3Nn0.eZlJis8p-o4LtD9i7-GGjuV9AE86ZzWseGmjWaOCZlY"

    // Streaming model — fast, low-latency, English-tuned. Allowlisted
    // server-side; keep in sync with the eleven function.
    private let modelID = "eleven_flash_v2_5"

    private var player: AVAudioPlayer?
    private var playbackProxy: PlaybackProxy?
    private var lastTempFile: URL?
    private var audioSessionConfigured = false

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    var isPlaying: Bool { player?.isPlaying ?? false }

    private init() {
        // Configure the shared audio session ONCE at first init. Subsequent
        // speak() calls reactivate but don't reconfigure. Safe to do at init
        // time — `playback` doesn't ask the user for any permission.
        configureAudioSession()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.defaultToSpeaker, .mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            audioSessionConfigured = true
            Self.log("audio session configured: .playback + .defaultToSpeaker + .mixWithOthers")
        } catch {
            audioSessionConfigured = false
            Self.log("audio session config FAILED — \(error.localizedDescription)")
        }
    }

    // MARK: - Speak

    /// Synthesizes `text` with `voiceID` + `settings` through the Supabase
    /// proxy, writes the audio to a temp .mp3, and plays it. Returns when
    /// playback completes or `stop()` is called. Throws on HTTP / network /
    /// decoding failure so the caller can fall back to Apple TTS.
    func speak(_ text: String,
               voiceID: String,
               settings: VoiceSettings) async throws {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            Self.log("skip — empty text")
            return
        }
        guard !voiceID.isEmpty else {
            Self.log("voice ID empty — falling back to Apple TTS")
            throw RWError.api
        }

        // Re-activate the session in case another audio source deactivated it.
        if !audioSessionConfigured { configureAudioSession() } else {
            try? AVAudioSession.sharedInstance().setActive(true)
        }

        guard let endpoint = URL(string: url) else {
            Self.log("bad endpoint URL — \(url)")
            throw RWError.api
        }

        Self.log("REQUEST → \(url)  voice=\(voiceID)  model=\(modelID)  textLen=\(cleanText.count)")

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("audio/mpeg",       forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
        req.setValue(publishableKey,             forHTTPHeaderField: "apikey")

        let body: [String: Any] = [
            "voice_id": voiceID,
            "text": cleanText,
            "model_id": modelID,
            "voice_settings": [
                "stability": settings.stability,
                "similarity_boost": settings.similarityBoost,
                "style": settings.style,
                "use_speaker_boost": settings.useSpeakerBoost
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            Self.log("NETWORK ERROR — \(error.localizedDescription)")
            throw error
        }

        guard let http = resp as? HTTPURLResponse else {
            Self.log("non-HTTP response from \(url)")
            throw RWError.api
        }

        if http.statusCode != 200 {
            let preview = String(data: data, encoding: .utf8)?.prefix(200) ?? "<binary>"
            Self.log("HTTP \(http.statusCode) for voice \(voiceID) — body: \(preview)")
            throw RWError.api
        }

        let bytes = data.count
        Self.log("RESPONSE 200  bytes=\(bytes)")

        guard bytes > 256 else {
            // Anything under ~256 bytes for a TTS response is suspicious —
            // probably a JSON error blob with a 200 from a permissive proxy.
            Self.log("response too small (\(bytes) bytes) — likely not audio; falling back")
            throw RWError.api
        }

        // Persist to a temp .mp3. AVAudioPlayer(contentsOf:) is more
        // forgiving than AVAudioPlayer(data:) with partial blobs.
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("eleven-\(UUID().uuidString).mp3")
        do {
            try data.write(to: tempURL, options: .atomic)
        } catch {
            Self.log("write temp file FAILED — \(error.localizedDescription)")
            throw error
        }
        Self.log("wrote temp file → \(tempURL.lastPathComponent)")
        cleanupTempFile()
        lastTempFile = tempURL

        let player: AVAudioPlayer
        do {
            player = try AVAudioPlayer(contentsOf: tempURL)
        } catch {
            Self.log("AVAudioPlayer init FAILED — \(error.localizedDescription)")
            throw error
        }
        self.player = player

        // Bridge AVAudioPlayerDelegate completion into a continuation so the
        // caller's `await speak(...)` blocks for the full audio duration.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let proxy = PlaybackProxy { cont.resume() }
            self.playbackProxy = proxy
            player.delegate = proxy
            player.prepareToPlay()
            if !player.play() {
                Self.log("player.play() returned false — resuming continuation immediately")
                proxy.signalFinished()
            } else {
                Self.log("playing  duration=\(String(format: "%.2f", player.duration))s")
            }
        }

        Self.log("playback finished")
        self.player = nil
        self.playbackProxy = nil
        cleanupTempFile()
    }

    // MARK: - Stop

    func stop() {
        if let p = player, p.isPlaying {
            Self.log("stop() — was playing")
        }
        player?.stop()
        player = nil
        playbackProxy?.signalFinished()
        playbackProxy = nil
        cleanupTempFile()
    }

    // MARK: - Test hooks

    /// Synthesizes a 2-second sample using `avatar`'s ElevenLabs voice.
    /// Used by the picker's per-avatar speaker button to preview a voice
    /// before starting a session. Returns nil on success, or a short error
    /// message that callers can surface in a toast.
    func testVoice(avatar: SimAvatar, line: String? = nil) async -> String? {
        let sample = line ?? Self.sampleLine(for: avatar)
        Self.log("testVoice(\(avatar.id) / \(avatar.voiceLabel))")
        do {
            try await speak(sample,
                            voiceID: avatar.elevenLabsVoiceID,
                            settings: avatar.voiceSettings)
            return nil
        } catch {
            return "Voice test failed: \(error.localizedDescription)"
        }
    }

    /// Diagnostic — synthesizes Jordan's voice with the canonical sample line
    /// and plays it. Returns nil on success, or a short error message.
    func testJordanVoice() async -> String? {
        guard let jordan = SimAvatars.find("jordan") else {
            return "Jordan avatar not found in SimAvatars catalog"
        }
        return await testVoice(avatar: jordan)
    }

    // Per-avatar two-second sample line. Short, in-character, recognizable.
    private static func sampleLine(for avatar: SimAvatar) -> String {
        switch avatar.id {
        case "jordan": return "Hey — didn't expect to see anyone interesting here. What's your deal?"
        case "maya":   return "Okay, you've got my attention. Don't waste it."
        case "alex":   return "Tell me something I haven't heard before."
        case "sam":    return "Try me. Bet you can't make me laugh in one line."
        case "riley":  return "Hi. I was just thinking about something — what brings you here?"
        case "casey":  return "Alright, I'm curious. Convince me."
        default:       return "Hey there. Nice to hear my own voice."
        }
    }

    // MARK: - Internals

    private func cleanupTempFile() {
        guard let url = lastTempFile else { return }
        try? FileManager.default.removeItem(at: url)
        lastTempFile = nil
    }

    /// Always prints — TTS issues happen on real devices in Release builds
    /// too, so the log path stays open. Body is short, no PII, no key.
    private static func log(_ message: String) {
        print("[ElevenLabs] \(message)")
    }
}

// MARK: - Playback delegate proxy
// AVAudioPlayerDelegate requires NSObject conformance, but ElevenLabsService
// is @MainActor @Observable. A small NSObject proxy keeps responsibilities
// clean without forcing the service into the NSObject hierarchy.

private final class PlaybackProxy: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    private var onFinish: (() -> Void)?

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        signalFinished()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        signalFinished()
    }

    /// Idempotent — safe to call from both the delegate callback and stop().
    func signalFinished() {
        let cb = onFinish
        onFinish = nil
        cb?()
    }
}

// MARK: - Apple TTS Fallback
// Used when ElevenLabs returns a non-200 OR throws a network error OR the
// user is on free tier (and the DEBUG override is not in play). Tuned for
// natural delivery — slightly slower, slightly higher pitch, with the
// enhanced English voice when available.

@MainActor
@Observable
final class AppleTTSService {
    static let shared = AppleTTSService()
    private let synthesizer = AVSpeechSynthesizer()

    /// Speaks `text`. `reason` is logged so we can see in the console exactly
    /// why we're not using ElevenLabs — empty for free-tier users, the error
    /// description otherwise.
    func speak(_ text: String, reason: String? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let why = reason ?? "user is not Pro / no ElevenLabs voice"
        print("[ElevenLabs] FALLING BACK TO APPLE TTS: \(why)")

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = Self.bestEnglishVoice()
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.05
        utterance.volume = 0.9

        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    /// Prefers an enhanced/premium English voice if installed; falls back to
    /// the device default. Enhanced voices sound noticeably less robotic.
    private static func bestEnglishVoice() -> AVSpeechSynthesisVoice? {
        let englishVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }

        if let premium = englishVoices.first(where: { $0.quality == .premium && $0.language == "en-US" }) {
            return premium
        }
        if let enhanced = englishVoices.first(where: { $0.quality == .enhanced && $0.language == "en-US" }) {
            return enhanced
        }
        if let premium = englishVoices.first(where: { $0.quality == .premium }) {
            return premium
        }
        if let enhanced = englishVoices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        return AVSpeechSynthesisVoice(language: "en-US")
            ?? AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    }
}
