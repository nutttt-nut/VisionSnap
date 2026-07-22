import CoreGraphics
import Foundation

@main
struct WorkspaceGestureDetectorTests {
    static func main() {
        var detector = WorkspaceGestureDetector()

        expect(detector.update(frame: frame(4, x: 0.4, y: 0.5), at: 0) == nil)
        expect(
            detector.update(frame: frame(4, x: 0.59, y: 0.5), at: 0.2) == .switchDesktopLeft,
            "four-finger right swipe must switch left"
        )
        expect(
            detector.update(frame: frame(4, x: 0.8, y: 0.5), at: 0.3) == nil,
            "one pose must trigger only once"
        )

        _ = detector.update(frame: frame(3, x: 0.5, y: 0.5), at: 1.0)
        _ = detector.update(frame: frame(4, x: 0.6, y: 0.5), at: 1.1)
        expect(
            detector.update(frame: frame(4, x: 0.4, y: 0.5), at: 1.3) == .switchDesktopRight,
            "four-finger left swipe must switch right"
        )

        _ = detector.update(frame: frame(3, x: 0.5, y: 0.5), at: 2.0)
        _ = detector.update(frame: frame(5, x: 0.5, y: 0.6), at: 2.1)
        expect(
            detector.update(frame: frame(5, x: 0.5, y: 0.4), at: 2.3) == .missionControl,
            "five-finger upward swipe must open Mission Control"
        )

        _ = detector.update(frame: frame(3, x: 0.5, y: 0.5), at: 3.0)
        _ = detector.update(frame: frame(4, x: 0.3, y: 0.5, pinching: true), at: 3.1)
        expect(
            detector.update(frame: frame(4, x: 0.7, y: 0.5, pinching: true), at: 3.3) == nil,
            "pinching must suppress workspace gestures"
        )

        print("WorkspaceGestureDetectorTests: all checks passed")
    }

    private static func frame(
        _ fingerCount: Int,
        x: CGFloat,
        y: CGFloat,
        pinching: Bool = false
    ) -> WorkspaceGestureFrame {
        WorkspaceGestureFrame(
            extendedFingerCount: fingerCount,
            palmCenter: CGPoint(x: x, y: y),
            isPinching: pinching
        )
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String = "unexpected result"
    ) {
        guard condition() else { fatalError(message) }
    }
}
