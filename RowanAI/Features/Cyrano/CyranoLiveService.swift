import Foundation

@MainActor
@Observable
final class CyranoLiveService {
    static let shared = CyranoLiveService()

    var isActive: Bool = false

    private init() {}

    func startLiveKitSession() async {
        do {
            let userID = try await LiveKitService.userID()
            let roomName = LiveKitService.cyranoLiveRoomName(userID: userID)
            await LiveKitService.shared.connect(
                roomName: roomName,
                displayName: "User"
            )
            isActive = LiveKitService.shared.isConnected
        } catch {
            isActive = false
        }
    }

    func endLiveKitSession() async {
        await LiveKitService.shared.disconnect()
        isActive = false
    }
}
