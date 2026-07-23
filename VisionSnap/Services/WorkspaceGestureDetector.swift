import CoreGraphics
import Foundation

enum WorkspaceGestureAction: Equatable {
    case switchDesktopLeft
    case switchDesktopRight
    case missionControl
}

enum WorkspaceGestureSource: Hashable {
    case camera
    case trackpad
}

enum HandInteractionMode: Equatable {
    case pointer
    case workspace
    case inactive
}

enum PointerMapper {
    private static let activeMinimum: CGFloat = 0.2
    private static let activeMaximum: CGFloat = 0.8

    static func screenNormalized(fromCamera point: CGPoint) -> CGPoint {
        let span = activeMaximum - activeMinimum
        let cameraX = min(max((point.x - activeMinimum) / span, 0), 1)
        let cameraY = min(max((point.y - activeMinimum) / span, 0), 1)
        return CGPoint(x: 1 - cameraX, y: 1 - cameraY)
    }
}

enum SnapTarget: Equatable {
    case leftHalf
    case rightHalf
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case bottomHalf
    case fullScreen
}

struct SnapEngine {
    func target(at cursor: CGPoint, in screenFrame: CGRect) -> SnapTarget? {
        guard screenFrame.contains(cursor) else { return nil }
        let column = min(Int((cursor.x - screenFrame.minX) / (screenFrame.width / 3)), 2)
        let row = min(Int((cursor.y - screenFrame.minY) / (screenFrame.height / 3)), 2)
        let targets: [[SnapTarget?]] = [
            [.topLeft, .fullScreen, .topRight],
            [.leftHalf, nil, .rightHalf],
            [.bottomLeft, .bottomHalf, .bottomRight],
        ]
        return targets[row][column]
    }

    func frame(for target: SnapTarget, in visibleFrame: CGRect) -> CGRect {
        switch target {
        case .leftHalf:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            )
        case .rightHalf:
            return CGRect(
                x: visibleFrame.midX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            )
        case .topLeft:
            return quarter(in: visibleFrame, right: false, bottom: false)
        case .topRight:
            return quarter(in: visibleFrame, right: true, bottom: false)
        case .bottomLeft:
            return quarter(in: visibleFrame, right: false, bottom: true)
        case .bottomRight:
            return quarter(in: visibleFrame, right: true, bottom: true)
        case .bottomHalf:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.midY,
                width: visibleFrame.width,
                height: visibleFrame.height / 2
            )
        case .fullScreen:
            return visibleFrame
        }
    }

    func gridFrames(in visibleFrame: CGRect) -> [CGRect] {
        let cellWidth = visibleFrame.width / 3
        let cellHeight = visibleFrame.height / 3
        return (0..<3).flatMap { row in
            (0..<3).compactMap { column in
                guard row != 1 || column != 1 else { return nil }
                return CGRect(
                    x: visibleFrame.minX + CGFloat(column) * cellWidth,
                    y: visibleFrame.minY + CGFloat(row) * cellHeight,
                    width: cellWidth,
                    height: cellHeight
                )
            }
        }
    }

    private func quarter(in frame: CGRect, right: Bool, bottom: Bool) -> CGRect {
        CGRect(
            x: right ? frame.midX : frame.minX,
            y: bottom ? frame.midY : frame.minY,
            width: frame.width / 2,
            height: frame.height / 2
        )
    }
}

enum HandInteractionModeResolver {
    static func resolve(
        fingerCount: Int?,
        phase: PinchPhase,
        isDragging: Bool,
        isFist: Bool
    ) -> HandInteractionMode {
        if isDragging || phase == .pinching {
            return .pointer
        }
        if case .candidate = phase {
            return .pointer
        }
        if isFist { return .inactive }
        return fingerCount == 4 || fingerCount == 5 ? .workspace : .inactive
    }
}

struct WorkspaceGestureFrame {
    let extendedFingerCount: Int?
    let palmCenter: CGPoint?
    let isPinching: Bool
}

struct WorkspaceGestureDetector {
    private struct PoseState {
        var isActive = false
        var startPoint: CGPoint?
        var didTrigger = false
        var fingerCount = 0
        var stableSince = -Double.infinity
    }

    let swipeThreshold: CGFloat
    let cooldown: TimeInterval
    let stableCountDelay: TimeInterval
    let liftGap: TimeInterval

    private var states: [WorkspaceGestureSource: PoseState] = [:]
    private var suppressFourUntil: [WorkspaceGestureSource: TimeInterval] = [:]
    private var sequenceTriggered: Set<WorkspaceGestureSource> = []
    private var lastRelevantTime: [WorkspaceGestureSource: TimeInterval] = [:]
    private var lastTriggerTime = -Double.infinity

    init(
        swipeThreshold: CGFloat = 0.10,
        cooldown: TimeInterval = 0.8,
        stableCountDelay: TimeInterval = 0.08,
        liftGap: TimeInterval = 0.25
    ) {
        self.swipeThreshold = swipeThreshold
        self.cooldown = cooldown
        self.stableCountDelay = stableCountDelay
        self.liftGap = liftGap
    }

    mutating func update(
        frame: WorkspaceGestureFrame,
        source: WorkspaceGestureSource = .camera,
        at timestamp: TimeInterval
    ) -> WorkspaceGestureAction? {
        guard !frame.isPinching, let palmCenter = frame.palmCenter else {
            resetPose(source: source)
            return nil
        }
        guard let rawFingerCount = frame.extendedFingerCount,
              rawFingerCount >= 4 else {
            resetPose(source: source)
            return nil
        }
        if sequenceTriggered.contains(source),
           timestamp - lastRelevantTime[source, default: -Double.infinity] >= liftGap {
            sequenceTriggered.remove(source)
            resetPose(source: source)
        }
        lastRelevantTime[source] = timestamp
        guard !sequenceTriggered.contains(source) else { return nil }
        let fingerCount = min(rawFingerCount, 5)
        if fingerCount == 5 {
            suppressFourUntil[source] = timestamp + 0.5
        } else if timestamp < suppressFourUntil[source, default: -Double.infinity] {
            resetPose(source: source)
            return nil
        }

        var state = states[source] ?? PoseState()
        if !state.isActive || state.fingerCount != fingerCount {
            state.isActive = true
            state.startPoint = palmCenter
            state.didTrigger = false
            state.fingerCount = fingerCount
            state.stableSince = timestamp
            states[source] = state
            return nil
        }

        guard !state.didTrigger,
              timestamp - state.stableSince >= stableCountDelay,
              timestamp - lastTriggerTime >= cooldown,
              let startPoint = state.startPoint else {
            return nil
        }

        let deltaX = palmCenter.x - startPoint.x
        let deltaY = palmCenter.y - startPoint.y
        let action: WorkspaceGestureAction?

        if fingerCount == 4,
           abs(deltaX) >= swipeThreshold,
           abs(deltaX) > abs(deltaY) {
            action = deltaX > 0 ? .switchDesktopLeft : .switchDesktopRight
        } else if fingerCount == 5,
                  deltaY >= swipeThreshold,
                  abs(deltaY) > abs(deltaX) {
            action = .missionControl
        } else {
            action = nil
        }

        if action != nil {
            state.didTrigger = true
            states[source] = state
            sequenceTriggered.insert(source)
            lastTriggerTime = timestamp
        }
        return action
    }

    mutating func reset() {
        states = [:]
        suppressFourUntil = [:]
        sequenceTriggered = []
        lastRelevantTime = [:]
        lastTriggerTime = -Double.infinity
    }

    private mutating func resetPose(source: WorkspaceGestureSource) {
        states[source] = nil
    }
}
