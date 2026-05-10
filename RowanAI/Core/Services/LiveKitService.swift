import Foundation
import UIKit
import LiveKit

@MainActor
@Observable
final class LiveKitService: NSObject {
    static let shared = LiveKitService()

    var isConnected: Bool = false
    var isConnecting: Bool = false
    var connectionError: String? = nil
    var isLocalAudioEnabled: Bool = true

    private var room: Room?

    private let supabaseURL = "https://rvdzakkvggqxqrrvtfiq.supabase.co"

    /// Returns the Supabase user id for use in roomName helpers and
    /// participant naming. Performs anonymous sign-in on first call.
    static func userID() async throws -> String {
        try await SupabaseAuth.shared.ensureUserID()
    }

    func fetchToken(roomName: String, name: String) async throws -> (token: String, url: String) {
        guard let url = URL(string: "\(supabaseURL)/functions/v1/livekit-token") else {
            throw LiveKitServiceError.invalidURL
        }

        let userJWT = try await SupabaseAuth.shared.currentAccessToken()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(userJWT)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Identity is derived server-side from the JWT — we no longer trust
        // the client to specify it. Server also validates roomName matches
        // the authenticated user.
        let body: [String: Any] = [
            "roomName": roomName,
            "participantName": name,
            "canPublish": true,
            "canSubscribe": true,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LiveKitServiceError.tokenFetchFailed
        }

        do {
            let parsed = try JSONDecoder().decode(TokenResponse.self, from: data)
            return (parsed.token, parsed.url)
        } catch {
            throw LiveKitServiceError.invalidResponse
        }
    }

    private struct TokenResponse: Codable {
        let token: String
        let url: String
    }

    func connect(roomName: String, displayName: String) async {
        guard !isConnected, !isConnecting else { return }
        isConnecting = true
        connectionError = nil

        do {
            let (token, url) = try await fetchToken(roomName: roomName, name: displayName)

            let connectOptions = ConnectOptions(autoSubscribe: true)
            let roomOptions = RoomOptions(
                defaultAudioCaptureOptions: AudioCaptureOptions(
                    echoCancellation: true,
                    autoGainControl: true,
                    noiseSuppression: true
                ),
                defaultAudioPublishOptions: AudioPublishOptions(
                    encoding: AudioEncoding(maxBitrate: 32_000)
                )
            )

            let newRoom = Room(delegate: self,
                               connectOptions: connectOptions,
                               roomOptions: roomOptions)

            try await newRoom.connect(url: url, token: token)
            try await newRoom.localParticipant.setMicrophone(enabled: true)

            self.room = newRoom
            self.isConnected = true
            self.isConnecting = false
        } catch {
            self.connectionError = error.localizedDescription
            self.isConnecting = false
        }
    }

    func disconnect() async {
        await room?.disconnect()
        room = nil
        isConnected = false
        isConnecting = false
    }

    func setMicrophoneEnabled(_ enabled: Bool) async {
        isLocalAudioEnabled = enabled
        _ = try? await room?.localParticipant.setMicrophone(enabled: enabled)
    }

    static func simRoomName(avatarID: String, userID: String) -> String {
        "sim-\(avatarID)-\(userID)-\(Int(Date().timeIntervalSince1970))"
    }

    static func cyranoLiveRoomName(userID: String) -> String {
        "cyrano-live-\(userID)-\(Int(Date().timeIntervalSince1970))"
    }
}

extension LiveKitService: RoomDelegate {
    nonisolated func room(_ room: Room,
                          didUpdateConnectionState connectionState: ConnectionState,
                          from oldConnectionState: ConnectionState) {
        Task { @MainActor in
            self.isConnected = (connectionState == .connected)
        }
    }

    nonisolated func room(_ room: Room,
                          participant: RemoteParticipant,
                          didSubscribeTrack publication: RemoteTrackPublication) {
        // Remote track subscribed — agent voice will play through here.
    }

    nonisolated func room(_ room: Room, didDisconnectWithError error: LiveKitError?) {
        Task { @MainActor in
            self.isConnected = false
            if let error { self.connectionError = error.localizedDescription }
        }
    }
}

enum LiveKitServiceError: LocalizedError {
    case invalidURL
    case tokenFetchFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .tokenFetchFailed: return "Could not get session token"
        case .invalidResponse: return "Invalid server response"
        }
    }
}
