import Foundation

@main
struct CameraAutoOffPolicyTests {
    static func main() {
        expect(!CameraAutoOffPolicy.shouldStop(
            isGestureModeEnabled: false,
            lastHandSeenAt: 0,
            now: 600,
            timeout: 300
        ))
        expect(!CameraAutoOffPolicy.shouldStop(
            isGestureModeEnabled: true,
            lastHandSeenAt: nil,
            now: 600,
            timeout: 300
        ))
        expect(!CameraAutoOffPolicy.shouldStop(
            isGestureModeEnabled: true,
            lastHandSeenAt: 100,
            now: 399,
            timeout: 300
        ))
        expect(CameraAutoOffPolicy.shouldStop(
            isGestureModeEnabled: true,
            lastHandSeenAt: 100,
            now: 400,
            timeout: 300
        ))
        expect(!CameraAutoOffPolicy.shouldStop(
            isGestureModeEnabled: true,
            lastHandSeenAt: 0,
            now: 600,
            timeout: 0
        ))

        print("CameraAutoOffPolicyTests: all checks passed")
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String = "unexpected result"
    ) {
        guard condition() else { fatalError(message) }
    }
}
