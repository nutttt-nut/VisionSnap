import CoreGraphics
import Foundation

enum WorkspaceGestureAction: Equatable {
    case switchDesktopLeft
    case switchDesktopRight
    case missionControl
}

enum HandInteractionMode: Equatable {
    case pointer
    case workspace
    case inactive
}

enum HandInteractionModeResolver {
    static func resolve(
        fingerCount: Int?,
        phase: PinchPhase,
        isDragging: Bool,
        isFist: Bool
    ) -> HandInteractionMode {
        if isFist { return .inactive }
        if isDragging || phase == .pinching {
            return .pointer
        }
        if case .candidate = phase {
            return .pointer
        }
        switch fingerCount {
        case 1, 2:
            return .pointer
        case 4, 5:
            return .workspace
        default:
            return .inactive
        }
    }
}

struct WorkspaceGestureFrame {
    let extendedFingerCount: Int?
    let palmCenter: CGPoint?
    let isPinching: Bool
}

struct WorkspaceGestureDetector {
    let swipeThreshold: CGFloat
    let cooldown: TimeInterval

    private var activeFingerCount: Int?
    private var startPoint: CGPoint?
    private var didTrigger = false
    private var lastTriggerTime = -Double.infinity

    init(swipeThreshold: CGFloat = 0.18, cooldown: TimeInterval = 0.8) {
        self.swipeThreshold = swipeThreshold
        self.cooldown = cooldown
    }

    mutating func update(
        frame: WorkspaceGestureFrame,
        at timestamp: TimeInterval
    ) -> WorkspaceGestureAction? {
        guard !frame.isPinching,
              let fingerCount = frame.extendedFingerCount,
              let palmCenter = frame.palmCenter,
              fingerCount == 4 || fingerCount == 5 else {
            resetPose()
            return nil
        }

        if activeFingerCount != fingerCount {
            activeFingerCount = fingerCount
            startPoint = palmCenter
            didTrigger = false
            return nil
        }

        guard !didTrigger,
              timestamp - lastTriggerTime >= cooldown,
              let startPoint else {
            return nil
        }

        let deltaX = palmCenter.x - startPoint.x
        let deltaY = palmCenter.y - startPoint.y
        let action: WorkspaceGestureAction?

        if fingerCount == 4, abs(deltaX) >= swipeThreshold {
            action = deltaX > 0 ? .switchDesktopLeft : .switchDesktopRight
        } else if fingerCount == 5, deltaY <= -swipeThreshold {
            action = .missionControl
        } else {
            action = nil
        }

        if action != nil {
            didTrigger = true
            lastTriggerTime = timestamp
        }
        return action
    }

    mutating func reset() {
        resetPose()
        lastTriggerTime = -Double.infinity
    }

    private mutating func resetPose() {
        activeFingerCount = nil
        startPoint = nil
        didTrigger = false
    }
}
