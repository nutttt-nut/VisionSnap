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
        windowControlService.cancelDrag()
        workspaceGestureDetector.reset()
        selectedWindow = nil
        overlayPresenter.hide()
    }

    private func handle(_ snapshot: HandTrackingSnapshot) {
        let timestamp = ProcessInfo.processInfo.systemUptime
        let points = Dictionary(uniqueKeysWithValues: snapshot.landmarks.map { ($0.name, $0.point) })

        guard let cursor = cursorPoint(from: points) else {
            if windowControlService.isDragging {
                windowControlService.cancelDrag()
            }
            selectedWindow = nil
            overlayPresenter.model.cursorPoint = nil
            overlayPresenter.model.selectedWindow = nil
            overlayPresenter.model.statusText = "ไม่พบมือ"
            workspaceGestureDetector.reset()
            return
        }

        CGWarpMouseCursorPosition(cursor)
        overlayPresenter.model.cursorPoint = cursor

        let pose = HandPoseAnalyzer.analyze(points)
        if pose.isFist, windowControlService.isDragging {
            windowControlService.cancelDrag()
            showActionStatus("ยกเลิก — คืนตำแหน่งเดิม", at: timestamp)
        }

        handlePinch(snapshot.phase, cursor: cursor, timestamp: timestamp)

        if !windowControlService.isDragging, timestamp - lastSelectionTime >= 0.05 {
            selectedWindow = windowControlService.window(at: cursor)
            lastSelectionTime = timestamp
        }
        overlayPresenter.model.selectedWindow = selectedWindow

        if !windowControlService.isDragging {
            let action = workspaceGestureDetector.update(
                frame: WorkspaceGestureFrame(
                    extendedFingerCount: pose.extendedFingerCount,
                    palmCenter: mirrored(pose.palmCenter),
                    isPinching: snapshot.phase == .pinching
                ),
                at: timestamp
            )
            if let action {
                windowControlService.perform(action)
                showActionStatus(statusText(for: action), at: timestamp)
            }
        }

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
            if !windowControlService.isDragging, let selectedWindow,
               windowControlService.beginDrag(target: selectedWindow, cursor: cursor) {
                showActionStatus("จับ \(selectedWindow.appName)", at: timestamp)
            }
            windowControlService.updateDrag(cursor: cursor)
        case .open:
            if windowControlService.isDragging {
                windowControlService.endDrag()
                showActionStatus("วางหน้าต่าง", at: timestamp)
            }
        case .noHand, .lowConfidence:
            if windowControlService.isDragging {
                windowControlService.cancelDrag()
                showActionStatus("Tracking หลุด — คืนตำแหน่งเดิม", at: timestamp)
            }
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

    private func mirrored(_ point: CGPoint?) -> CGPoint? {
        guard let point else { return nil }
        return CGPoint(x: 1 - point.x, y: 1 - point.y)
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

        if windowControlService.isDragging {
            return "กำลังลาก — ปล่อยนิ้วเพื่อวาง"
        }
        switch phase {
        case let .candidate(progress):
            return "จับหน้าต่าง \(Int(progress * 100))%"
        case .pinching:
            return "กำลังจับ"
        default:
            break
        }
        if fingerCount == 4 {
            return "4 นิ้ว: เลื่อนซ้าย/ขวา"
        }
        if fingerCount == 5 {
            return "5 นิ้ว: ปัดขึ้น Mission Control"
        }
        return selectedWindow == nil ? "ชี้ไปที่หน้าต่าง" : "Pinch เพื่อจับ"
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
        guard windowControlService.isDragging else { return }
        windowControlService.cancelDrag()
        showActionStatus("Escape — คืนตำแหน่งเดิม", at: ProcessInfo.processInfo.systemUptime)
    }
}
