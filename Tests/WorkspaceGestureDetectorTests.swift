import CoreGraphics
import Foundation

@main
struct WorkspaceGestureDetectorTests {
    static func main() {
        expect(
            HandInteractionModeResolver.resolve(
                fingerCount: 5,
                phase: .open,
                isDragging: false,
                isFist: false
            ) == .workspace,
            "five fingers must enter workspace mode"
        )
        expect(
            HandInteractionModeResolver.resolve(
                fingerCount: 4,
                phase: .open,
                isDragging: false,
                isFist: false
            ) == .workspace,
            "four fingers must not control the mouse"
        )
        expect(
            HandInteractionModeResolver.resolve(
                fingerCount: 1,
                phase: .open,
                isDragging: false,
                isFist: false
            ) == .inactive,
            "hand must not control the pointer before pinching"
        )
        expect(
            HandInteractionModeResolver.resolve(
                fingerCount: 3,
                phase: .open,
                isDragging: false,
                isFist: false
            ) == .inactive,
            "three fingers must remain inactive"
        )
        expect(
            HandInteractionModeResolver.resolve(
                fingerCount: 0,
                phase: .pinching,
                isDragging: false,
                isFist: true
            ) == .pointer,
            "pinching must override fist classification"
        )
        expect(
            HandInteractionModeResolver.resolve(
                fingerCount: 0,
                phase: .candidate(progress: 0.5),
                isDragging: false,
                isFist: true
            ) == .pointer,
            "pinch candidate must override fist classification"
        )

        expect(
            pointsEqual(
                PointerMapper.screenNormalized(fromCamera: CGPoint(x: 0.5, y: 0.5)),
                CGPoint(x: 0.5, y: 0.5)
            ),
            "camera center must map to screen center"
        )
        expect(
            PointerMapper.screenNormalized(fromCamera: CGPoint(x: 0.2, y: 0.2))
                == CGPoint(x: 1, y: 1),
            "active-region minimum must map to the opposite screen edge"
        )
        expect(
            PointerMapper.screenNormalized(fromCamera: CGPoint(x: 0.8, y: 0.8))
                == CGPoint(x: 0, y: 0),
            "active-region maximum must map to the opposite screen edge"
        )
        expect(
            PointerMapper.screenNormalized(fromCamera: CGPoint(x: 0, y: 1))
                == CGPoint(x: 1, y: 0),
            "points outside the active region must clamp to screen edges"
        )

        let snapEngine = SnapEngine()
        let screenFrame = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let visibleFrame = CGRect(x: 0, y: 24, width: 1200, height: 776)
        expect(snapEngine.target(at: CGPoint(x: 20, y: 400), in: screenFrame) == .leftHalf)
        expect(snapEngine.target(at: CGPoint(x: 1180, y: 400), in: screenFrame) == .rightHalf)
        expect(snapEngine.target(at: CGPoint(x: 20, y: 20), in: screenFrame) == .topLeft)
        expect(snapEngine.target(at: CGPoint(x: 1180, y: 20), in: screenFrame) == .topRight)
        expect(snapEngine.target(at: CGPoint(x: 20, y: 780), in: screenFrame) == .bottomLeft)
        expect(snapEngine.target(at: CGPoint(x: 1180, y: 780), in: screenFrame) == .bottomRight)
        expect(snapEngine.target(at: CGPoint(x: 600, y: 780), in: screenFrame) == .bottomHalf)
        expect(snapEngine.target(at: CGPoint(x: 600, y: 20), in: screenFrame) == .fullScreen)
        expect(snapEngine.target(at: CGPoint(x: 600, y: 400), in: screenFrame) == nil)
        expect(
            snapEngine.frame(for: .leftHalf, in: visibleFrame)
                == CGRect(x: 0, y: 24, width: 600, height: 776)
        )
        expect(
            snapEngine.frame(for: .rightHalf, in: visibleFrame)
                == CGRect(x: 600, y: 24, width: 600, height: 776)
        )
        expect(snapEngine.frame(for: .fullScreen, in: visibleFrame) == visibleFrame)
        expect(
            snapEngine.frame(for: .topLeft, in: visibleFrame)
                == CGRect(x: 0, y: 24, width: 600, height: 388)
        )
        expect(
            snapEngine.frame(for: .bottomRight, in: visibleFrame)
                == CGRect(x: 600, y: 412, width: 600, height: 388)
        )
        expect(snapEngine.gridFrames(in: visibleFrame).count == 8)

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

        _ = detector.update(frame: frame(3, x: 0.5, y: 0.5), at: 3.0)
        _ = detector.update(frame: frame(4, x: 0.3, y: 0.5, pinching: true), at: 3.1)
        expect(
            detector.update(frame: frame(4, x: 0.7, y: 0.5, pinching: true), at: 3.3) == nil,
            "pinching must suppress workspace gestures"
        )

        detector.reset()
        expect(detector.update(frame: frame(5, x: 0.5, y: 0.3), at: 4.0) == nil)
        expect(
            detector.update(frame: frame(5, x: 0.5, y: 0.45), at: 4.2) == .missionControl,
            "five-finger upward swipe must open Mission Control"
        )

        detector.reset()
        expect(detector.update(frame: frame(4, x: 0.5, y: 0.5), at: 4.5) == nil)
        expect(
            detector.update(frame: frame(5, x: 0.5, y: 0.65), at: 4.55) == nil,
            "finger-count transition must restart recognition"
        )
        expect(
            detector.update(frame: frame(5, x: 0.5, y: 0.66), at: 4.60) == nil,
            "finger count must remain stable before recognition"
        )
        expect(
            detector.update(frame: frame(5, x: 0.5, y: 0.80), at: 4.75) == .missionControl,
            "stable five-finger movement must still trigger"
        )

        detector.reset()
        expect(detector.update(frame: frame(6, x: 0.5, y: 0.4), at: 4.8) == nil)
        expect(
            detector.update(frame: frame(5, x: 0.5, y: 0.55), at: 4.9) == .missionControl,
            "five-or-more contacts must stay in one Mission Control gesture"
        )
        expect(detector.update(frame: frame(4, x: 0.5, y: 0.55), at: 5.0) == nil)
        expect(
            detector.update(frame: frame(4, x: 0.3, y: 0.55), at: 5.2) == nil,
            "four-finger dropout after five fingers must not trigger Desktop"
        )
        expect(detector.update(frame: frame(5, x: 0.5, y: 0.4), at: 5.3) == nil)
        expect(
            detector.update(frame: frame(5, x: 0.5, y: 0.7), at: 5.4) == nil,
            "one touch sequence must trigger only once despite count flicker"
        )
        _ = detector.update(frame: frame(2, x: 0.5, y: 0.5), at: 5.5)
        expect(detector.update(frame: frame(5, x: 0.5, y: 0.4), at: 5.8) == nil)
        expect(
            detector.update(frame: frame(5, x: 0.5, y: 0.7), at: 6.0) == .missionControl,
            "lifting below four fingers must unlock the next sequence"
        )

        detector.reset()
        expect(detector.update(
            frame: frame(4, x: 0.4, y: 0.5),
            source: .camera,
            at: 7.0
        ) == nil)
        expect(detector.update(
            frame: frame(4, x: 0.6, y: 0.5),
            source: .camera,
            at: 7.2
        ) == .switchDesktopLeft)
        expect(detector.update(
            frame: frame(4, x: 0.6, y: 0.5),
            source: .trackpad,
            at: 7.3
        ) == nil)
        expect(
            detector.update(
                frame: frame(4, x: 0.4, y: 0.5),
                source: .trackpad,
                at: 7.5
            ) == nil,
            "camera and trackpad must share one action cooldown"
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

    private static func pointsEqual(_ first: CGPoint, _ second: CGPoint) -> Bool {
        abs(first.x - second.x) < 0.0001 && abs(first.y - second.y) < 0.0001
    }
}
