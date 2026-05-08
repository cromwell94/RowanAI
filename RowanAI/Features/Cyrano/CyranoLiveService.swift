import Foundation

@MainActor
@Observable
final class CyranoLiveService {
    static let shared = CyranoLiveService()

    var isActive: Bool = false

    private init() {}

    func startLiveKitSession() async {
        let identity = LiveKitService.deviceIdentity
        let roomName = LiveKitService.cyranoLiveRoomName(userID: identity)
        await LiveKitService.shared.connect(
            roomName: roomName,
            identity: identity,
            displayName: "User"
        )
        isActive = LiveKitService.shared.isConnected
    }

    func endLiveKitSession() async {
        await LiveKitService.shared.disconnect()
        isActive = false
    }
}
