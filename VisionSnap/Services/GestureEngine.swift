import AppKit
import Combine
import Vision

@MainActor
final class GestureEngine {
    private let trackingService: HandTrackingService
    private let windowControlService = WindowControlService()
    private let overlayPresenter = GestureOverlayPresenter()

    private var workspaceGestureDetector = WorkspaceGestureDetector()
    private var trackingSubscription: AnyCancellable?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var selectedWindow: TargetWindow?
    private var isMouseDown = false
    private var lastCursorPoint: CGPoint?
    private var lastSelectionTime = -Double.infinity
    private var actionStatus: (text: String, expiresAt: TimeInterval)?

    init(trackingService: HandTrackingService) {
        self.trackingService = trackingService
    }

    func start() {
        guard trackingSubscription == nil else { return }
        overlayPresenter.show()
        trackingSubscription = trackingService.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.handle(snapshot)
            }
        installEscapeMonitors()
    }

    func stop() {
        trackingSubscription = nil
        removeEscapeMonitors()
        releaseMouseIfNeeded()
        workspaceGestureDetector.reset()
        selectedWindow = nil
        overlayPresenter.hide()
    }

    private func handle(_ snapshot: HandTrackingSnapshot) {
        let timestamp = ProcessInfo.processInfo.systemUptime
        let points = Dictionary(uniqueKeysWithValues: snapshot.landmarks.map { ($0.name, $0.point) })
        let pose = HandPoseAnalyzer.analyze(points)
        let interactionMode = HandInteractionModeResolver.resolve(
            fingerCount: pose.extendedFingerCount,
            isIndexPointing: pose.isIndexPointing,
            phase: snapshot.phase,
            isDragging: isMouseDown,
            isFist: pose.isFist
        )

        if pose.isFist {
            releaseMouseIfNeeded()
            selectedWindow = nil
            workspaceGestureDetector.reset()
            overlayPresenter.model.cursorPoint = nil
            overlayPresenter.model.gesturePoint = screenPoint(from: pose.palmCenter)
            overlayPresenter.model.selectedWindow = nil
            overlayPresenter.model.statusText = "กำหมัด: ยกเลิก"
            return
        }

        if interactionMode != .pointer {
            selectedWindow = nil
            overlayPresenter.model.cursorPoint = nil
            overlayPresenter.model.gesturePoint = screenPoint(from: pose.palmCenter)
            overlayPresenter.model.selectedWindow = nil

            if let action = workspaceGestureDetector.update(
                frame: WorkspaceGestureFrame(
                    extendedFingerCount: pose.extendedFingerCount,
                    palmCenter: screenNormalized(pose.palmCenter),
                    isPinching: false
                ),
                at: timestamp
            ) {
                windowControlService.perform(action)
                showActionStatus(statusText(for: action), at: timestamp)
            }
            overlayPresenter.model.statusText = currentStatus(
                phase: snapshot.phase,
                fingerCount: pose.extendedFingerCount,
                timestamp: timestamp
            )
            return
        }

        _ = workspaceGestureDetector.update(
            frame: WorkspaceGestureFrame(
                extendedFingerCount: pose.extendedFingerCount,
                palmCenter: screenNormalized(pose.palmCenter),
                isPinching: true
            ),
            at: timestamp
        )
        overlayPresenter.model.gesturePoint = nil

        guard let cursor = cursorPoint(from: points) else {
            releaseMouseIfNeeded()
            selectedWindow = nil
            overlayPresenter.model.cursorPoint = nil
            overlayPresenter.model.gesturePoint = nil
            overlayPresenter.model.selectedWindow = nil
            overlayPresenter.model.statusText = "ไม่พบมือ"
            workspaceGestureDetector.reset()
            return
        }

        CGWarpMouseCursorPosition(cursor)
        lastCursorPoint = cursor
        overlayPresenter.model.cursorPoint = cursor

        handlePinch(snapshot.phase, cursor: cursor, timestamp: timestamp)

        if !isMouseDown, timestamp - lastSelectionTime >= 0.05 {
            selectedWindow = windowControlService.window(at: cursor)
            lastSelectionTime = timestamp
        }
        overlayPresenter.model.selectedWindow = selectedWindow

        overlayPresenter.model.statusText = currentStatus(
            phase: snapshot.phase,
            fingerCount: pose.extendedFingerCount,
            timestamp: timestamp
        )
    }

    private func handlePinch(
        _ phase: PinchPhase,
        cursor: CGPoint,
        timestamp: TimeInterval
    ) {
        switch phase {
        case .pinching:
            if isMouseDown {
                postMouseEvent(.leftMouseDragged, at: cursor)
            } else {
                postMouseEvent(.leftMouseDown, at: cursor)
                isMouseDown = true
                showActionStatus("คลิกค้าง", at: timestamp)
            }
        case .open:
            if isMouseDown {
                postMouseEvent(.leftMouseUp, at: cursor)
                isMouseDown = false
                showActionStatus("คลิก", at: timestamp)
            }
        case .noHand, .lowConfidence:
            releaseMouseIfNeeded()
        case .candidate:
            break
        }
    }

    private func cursorPoint(
        from points: [VNHumanHandPoseObservation.JointName: CGPoint]
    ) -> CGPoint? {
        guard let indexTip = points[.indexTip], let screen = NSScreen.screens.first else {
            return nil
        }
        return CGPoint(
            x: (1 - indexTip.x) * screen.frame.width,
            y: (1 - indexTip.y) * screen.frame.height
        )
    }

    private func screenNormalized(_ point: CGPoint?) -> CGPoint? {
        guard let point else { return nil }
        return CGPoint(x: point.x, y: 1 - point.y)
    }

    private func screenPoint(from point: CGPoint?) -> CGPoint? {
        guard let point, let screen = NSScreen.screens.first else { return nil }
        return CGPoint(
            x: point.x * screen.frame.width,
            y: (1 - point.y) * screen.frame.height
        )
    }

    private func currentStatus(
        phase: PinchPhase,
        fingerCount: Int?,
        timestamp: TimeInterval
    ) -> String? {
        if let actionStatus, timestamp < actionStatus.expiresAt {
            return actionStatus.text
        }
        self.actionStatus = nil

        if isMouseDown {
            return "คลิกค้าง — ปล่อย pinch เพื่อปล่อยคลิก"
        }
        switch phase {
        case let .candidate(progress):
            return "Pinch เพื่อคลิก \(Int(progress * 100))%"
        case .pinching:
            return "คลิกค้าง"
        default:
            break
        }
        if fingerCount == 4 {
            return "4 นิ้ว: เลื่อนซ้าย/ขวา"
        }
        if fingerCount == 5 {
            return "5 นิ้ว: ปัดขึ้น Mission Control"
        }
        if fingerCount == 3 {
            return "3 นิ้ว: ไม่มีคำสั่ง"
        }
        return "Pinch เพื่อคลิก"
    }

    private func showActionStatus(_ text: String, at timestamp: TimeInterval) {
        actionStatus = (text, timestamp + 1.0)
    }

    private func statusText(for action: WorkspaceGestureAction) -> String {
        switch action {
        case .switchDesktopLeft:
            "Desktop ก่อนหน้า"
        case .switchDesktopRight:
            "Desktop ถัดไป"
        case .missionControl:
            "Mission Control"
        }
    }

    private func installEscapeMonitors() {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            DispatchQueue.main.async {
                self?.cancelDragWithEscape()
            }
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.cancelDragWithEscape()
            return nil
        }
    }

    private func removeEscapeMonitors() {
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        globalKeyMonitor = nil
        localKeyMonitor = nil
    }

    private func cancelDragWithEscape() {
        guard isMouseDown else { return }
        releaseMouseIfNeeded()
        showActionStatus("Escape — ปล่อยคลิก", at: ProcessInfo.processInfo.systemUptime)
    }

    private func postMouseEvent(_ type: CGEventType, at point: CGPoint) {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }

    private func releaseMouseIfNeeded() {
        guard isMouseDown else { return }
        postMouseEvent(.leftMouseUp, at: lastCursorPoint ?? .zero)
        isMouseDown = false
    }
}
