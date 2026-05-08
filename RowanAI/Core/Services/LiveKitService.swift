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
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ2ZHpha2t2Z2dxeHFycnZ0ZmlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc4MTk2NzYsImV4cCI6MjA5MzM5NTY3Nn0.eZlJis8p-o4LtD9i7-GGjuV9AE86ZzWseGmjWaOCZlY"

    static var deviceIdentity: String {
        if let id = UIDevice.current.identifierForVendor?.uuidString { return id }
        return "anon-\(UUID().uuidString)"
    }

    func fetchToken(roomName: String, identity: String, name: String) async throws -> (token: String, url: String) {
        guard let url = URL(string: "\(supabaseURL)/functions/v1/livekit-token") else {
            throw LiveKitServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "roomName": roomName,
            "participantIdentity": identity,
            "participantName": name,
            "canPublish": true,
            "canSubscribe": true,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LiveKitServiceError.tokenFetchFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String,
              let livekitURL = json["url"] as? String else {
            throw LiveKitServiceError.invalidResponse
        }
        return (token, livekitURL)
    }

    func connect(roomName: String, identity: String, displayName: String) async {
        guard !isConnected, !isConnecting else { return }
        isConnecting = true
        connectionError = nil

        do {
            let (token, url) = try await fetchToken(roomName: roomName, identity: identity, name: displayName)

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
        try? await room?.localParticipant.setMicrophone(enabled: enabled)
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
