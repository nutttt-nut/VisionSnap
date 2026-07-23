import Foundation

struct CameraAutoOffPolicy {
    static func shouldStop(
        isGestureModeEnabled: Bool,
        lastHandSeenAt: TimeInterval?,
        now: TimeInterval,
        timeout: TimeInterval
    ) -> Bool {
        guard isGestureModeEnabled,
              timeout > 0,
              let lastHandSeenAt else {
            return false
        }
        return now - lastHandSeenAt >= timeout
    }
}
