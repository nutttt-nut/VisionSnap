import AppKit
import Combine
import Vision

@MainActor
final class GestureEngine {
    private struct GestureDebugAttempt {
        var confidence: Float = 0
        var holdMilliseconds = 0
        var enteredGrab = false
        var axElement: String?
        var targetDelta = CGPoint.zero
        var axSetPositionResult: AXError?
    }

    private let trackingService: HandTrackingService
    private let windowControlService = WindowControlService()
    private let overlayPresenter = GestureOverlayPresenter()
    private let snapEngine = SnapEngine()

    private var workspaceGestureDetector = WorkspaceGestureDetector()
    private var trackingSubscription: AnyCancellable?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var selectedWindow: TargetWindow?
    private var smoothedCursorPoint: CGPoint?
    private var smoothedGazePoint: CGPoint?
    private var gazeCandidate: TargetWindow?
    private var gazeCandidateSince = -Double.infinity
    private var pendingSnapTarget: SnapTarget?
    private var lastGazeHitTestTime = -Double.infinity
    private var actionStatus: (text: String, expiresAt: TimeInterval)?
    private var dragTrackingLostSince: TimeInterval?
    private var dragPalmAnchor: CGPoint?
    private var dragCursorAnchor: CGPoint?
    private var gazePausedUntil = -Double.infinity
    private var gestureDebugAttempt: GestureDebugAttempt?

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
        clearSnapPreview()
        workspaceGestureDetector.reset()
        smoothedCursorPoint = nil
        smoothedGazePoint = nil
        dragTrackingLostSince = nil
        gazePausedUntil = -Double.infinity
        clearDragAnchors()
        gazeCandidate = nil
        selectedWindow = nil
        overlayPresenter.hide()
    }

    private func handle(_ snapshot: HandTrackingSnapshot) {
        let timestamp = ProcessInfo.processInfo.systemUptime
        updateGestureDebugAttempt(with: snapshot)
        let points = Dictionary(uniqueKeysWithValues: snapshot.landmarks.map { ($0.name, $0.point) })
        let pose = HandPoseAnalyzer.analyze(points)
        if timestamp >= gazePausedUntil,
           !isPinchInteraction(snapshot.phase),
           !windowControlService.isDragging {
            updateGazeSelection(snapshot.gazePoint, at: timestamp)
        }
        let interactionMode = HandInteractionModeResolver.resolve(
            fingerCount: pose.extendedFingerCount,
            phase: snapshot.phase,
            isDragging: windowControlService.isDragging,
            isFist: pose.isFist
        )

        if pose.isFist, !isPinchInteraction(snapshot.phase) {
            if windowControlService.isDragging {
                windowControlService.cancelDrag()
                clearDragAnchors()
                gazePausedUntil = timestamp + 0.7
                showActionStatus("ยกเลิก — คืนตำแหน่งเดิม", at: timestamp)
            }
            clearSnapPreview()
            smoothedCursorPoint = nil
            workspaceGestureDetector.reset()
            overlayPresenter.model.cursorPoint = nil
            overlayPresenter.model.gesturePoint = screenPoint(from: pose.palmCenter)
            overlayPresenter.model.statusText = "กำหมัด: ยกเลิก"
            return
        }

        if interactionMode != .pointer {
            smoothedCursorPoint = nil
            overlayPresenter.model.cursorPoint = nil
            overlayPresenter.model.gesturePoint = interactionMode == .workspace
                ? screenPoint(from: pose.palmCenter)
                : nil

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

        if windowControlService.isDragging,
           (snapshot.phase == .noHand || snapshot.phase == .lowConfidence) {
            handleDragTrackingLoss(at: timestamp)
            return
        }

        guard let cursor = cursorPoint(from: pose.palmCenter) else {
            if windowControlService.isDragging {
                handleDragTrackingLoss(at: timestamp)
                return
            }
            clearSnapPreview()
            smoothedCursorPoint = nil
            overlayPresenter.model.cursorPoint = nil
            overlayPresenter.model.gesturePoint = nil
            overlayPresenter.model.statusText = "ไม่พบมือ"
            workspaceGestureDetector.reset()
            return
        }
        dragTrackingLostSince = nil

        overlayPresenter.model.cursorPoint = cursor
        handlePinch(
            snapshot.phase,
            cursor: cursor,
            palmCenter: pose.palmCenter,
            timestamp: timestamp
        )
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
        palmCenter: CGPoint?,
        timestamp: TimeInterval
    ) {
        switch phase {
        case .pinching:
            if !windowControlService.isDragging {
                guard let selectedWindow else {
                    overlayPresenter.model.statusText = "ยังไม่ได้เลือกหน้าต่าง"
                    return
                }
                guard windowControlService.beginDrag(target: selectedWindow, cursor: cursor) else {
                    gestureDebugAttempt?.axElement = nil
                    overlayPresenter.model.statusText = "จับไม่ได้ — เช็ค Accessibility"
                    return
                }
                gestureDebugAttempt?.axElement = windowControlService.lastAXElementDescription
                dragPalmAnchor = palmCenter
                dragCursorAnchor = cursor
                smoothedCursorPoint = cursor
                overlayPresenter.model.isGrabbing = true
                showActionStatus("จับ \(selectedWindow.appName)", at: timestamp)
            }
            if let dragCursorAnchor {
                let delta = CGPoint(
                    x: cursor.x - dragCursorAnchor.x,
                    y: cursor.y - dragCursorAnchor.y
                )
                if hypot(delta.x, delta.y) > hypot(
                    gestureDebugAttempt?.targetDelta.x ?? 0,
                    gestureDebugAttempt?.targetDelta.y ?? 0
                ) {
                    gestureDebugAttempt?.targetDelta = delta
                }
            }
            gestureDebugAttempt?.axSetPositionResult = windowControlService.updateDrag(cursor: cursor)
            updateSnapPreview(at: cursor)
        case .open:
            if windowControlService.isDragging {
                if let pendingSnapTarget,
                   let targetWindow = selectedWindow,
                   let screen = NSScreen.screens.first {
                    let frame = snapEngine.frame(
                        for: pendingSnapTarget,
                        in: visibleFrameInQuartzCoordinates(screen)
                    )
                    let didSnap = windowControlService.endDrag(snappingTo: frame)
                    if didSnap {
                        selectedWindow = TargetWindow(
                            windowNumber: targetWindow.windowNumber,
                            processIdentifier: targetWindow.processIdentifier,
                            appName: targetWindow.appName,
                            title: targetWindow.title,
                            frame: frame
                        )
                        overlayPresenter.model.selectedWindow = selectedWindow
                    }
                    showActionStatus(didSnap ? snapStatus(for: pendingSnapTarget) : "Snap ไม่สำเร็จ", at: timestamp)
                } else {
                    windowControlService.endDrag()
                    showActionStatus("วางหน้าต่าง", at: timestamp)
                }
                clearDragAnchors()
                gazePausedUntil = timestamp + 0.7
                clearSnapPreview()
                finishGestureDebugAttempt()
            }
        case .noHand, .lowConfidence:
            clearSnapPreview()
        case .candidate:
            break
        }
    }

    private func handleDragTrackingLoss(at timestamp: TimeInterval) {
        let lostSince = dragTrackingLostSince ?? timestamp
        dragTrackingLostSince = lostSince
        guard timestamp - lostSince >= 0.3 else {
            overlayPresenter.model.statusText = "กำลังหา hand tracking…"
            return
        }
        windowControlService.cancelDrag()
        dragTrackingLostSince = nil
        clearDragAnchors()
        gazePausedUntil = timestamp + 0.7
        clearSnapPreview()
        finishGestureDebugAttempt()
        showActionStatus("Tracking หลุด — คืนตำแหน่งเดิม", at: timestamp)
    }

    private func cursorPoint(from palmCenter: CGPoint?) -> CGPoint? {
        guard let palmCenter, let screen = NSScreen.screens.first else {
            return nil
        }
        let target: CGPoint
        if windowControlService.isDragging,
           let dragPalmAnchor,
           let dragCursorAnchor {
            let movementGain: CGFloat = 1.6
            target = CGPoint(
                x: min(max(
                    dragCursorAnchor.x - (palmCenter.x - dragPalmAnchor.x) * screen.frame.width * movementGain,
                    screen.frame.minX + 20
                ), screen.frame.maxX - 20),
                y: min(max(
                    dragCursorAnchor.y - (palmCenter.y - dragPalmAnchor.y) * screen.frame.height * movementGain,
                    screen.frame.minY + 20
                ), screen.frame.maxY - 20)
            )
        } else {
            let normalized = PointerMapper.screenNormalized(fromCamera: palmCenter)
            target = CGPoint(
                x: screen.frame.minX + normalized.x * screen.frame.width,
                y: screen.frame.minY + normalized.y * screen.frame.height
            )
        }
        guard let previous = smoothedCursorPoint else {
            smoothedCursorPoint = target
            return target
        }
        let distance = hypot(target.x - previous.x, target.y - previous.y)
        if distance < 4 { return previous }
        let smoothing: CGFloat = 0.18
        let smoothed = CGPoint(
            x: previous.x + (target.x - previous.x) * smoothing,
            y: previous.y + (target.y - previous.y) * smoothing
        )
        smoothedCursorPoint = smoothed
        return smoothed
    }

    private func clearDragAnchors() {
        dragPalmAnchor = nil
        dragCursorAnchor = nil
        overlayPresenter.model.isGrabbing = false
    }

    private func isPinchInteraction(_ phase: PinchPhase) -> Bool {
        if phase == .pinching { return true }
        if case .candidate = phase { return true }
        return false
    }

    private func updateGestureDebugAttempt(with snapshot: HandTrackingSnapshot) {
        let isAttemptFrame: Bool
        switch snapshot.phase {
        case .candidate, .pinching:
            isAttemptFrame = true
        default:
            isAttemptFrame = false
        }

        if isAttemptFrame {
            var attempt = gestureDebugAttempt ?? GestureDebugAttempt()
            attempt.confidence = max(attempt.confidence, snapshot.pinchConfidence)
            attempt.holdMilliseconds = max(
                attempt.holdMilliseconds,
                snapshot.pinchHoldMilliseconds
            )
            if snapshot.phase == .pinching {
                attempt.enteredGrab = true
            }
            gestureDebugAttempt = attempt
            return
        }

        if windowControlService.isDragging {
            return
        }
        finishGestureDebugAttempt()
    }

    private func finishGestureDebugAttempt() {
        guard let attempt = gestureDebugAttempt else { return }
        print(
            String(
                format: "[GESTURE] conf=%.2f holdMs=%d enteredGRAB=%@ axElem=%@ targetDelta=(%.1f,%.1f) axSetPosResult=%@",
                attempt.confidence,
                attempt.holdMilliseconds,
                attempt.enteredGrab ? "y" : "n",
                attempt.axElement ?? "nil",
                attempt.targetDelta.x,
                attempt.targetDelta.y,
                attempt.axSetPositionResult.map { String($0.rawValue) } ?? "nil"
            )
        )
        gestureDebugAttempt = nil
    }

    private func updateGazeSelection(_ gazePoint: CGPoint?, at timestamp: TimeInterval) {
        guard let gazePoint, let screen = NSScreen.screens.first else {
            overlayPresenter.model.gazePoint = nil
            gazeCandidate = nil
            return
        }
        let target = CGPoint(
            x: screen.frame.minX + (1 - gazePoint.x) * screen.frame.width,
            y: screen.frame.minY + (1 - gazePoint.y) * screen.frame.height
        )
        let smoothed: CGPoint
        if let previous = smoothedGazePoint {
            let distance = hypot(target.x - previous.x, target.y - previous.y)
            if distance < 28 {
                smoothed = previous
            } else {
                let smoothing: CGFloat = distance > 240 ? 0.22 : 0.1
                smoothed = CGPoint(
                    x: previous.x + (target.x - previous.x) * smoothing,
                    y: previous.y + (target.y - previous.y) * smoothing
                )
            }
        } else {
            smoothed = target
        }
        smoothedGazePoint = smoothed
        overlayPresenter.model.gazePoint = smoothed

        guard !windowControlService.isDragging,
              timestamp - lastGazeHitTestTime >= 0.08 else {
            return
        }
        lastGazeHitTestTime = timestamp
        let candidate = windowControlService.window(at: smoothed)
        if candidate?.windowNumber == gazeCandidate?.windowNumber {
            if timestamp - gazeCandidateSince >= 0.35, let candidate {
                selectedWindow = candidate
                overlayPresenter.model.selectedWindow = candidate
            }
        } else {
            gazeCandidate = candidate
            gazeCandidateSince = timestamp
        }
    }

    private func updateSnapPreview(at cursor: CGPoint) {
        guard windowControlService.isDragging, let screen = NSScreen.screens.first else {
            clearSnapPreview()
            return
        }
        let visibleFrame = visibleFrameInQuartzCoordinates(screen)
        overlayPresenter.model.snapGridFrames = snapEngine.gridFrames(in: visibleFrame)
        let target = snapEngine.target(at: cursor, in: screen.frame)
        pendingSnapTarget = target
        overlayPresenter.model.snapPreviewFrame = target.map {
            snapEngine.frame(for: $0, in: visibleFrame)
        }
    }

    private func clearSnapPreview() {
        pendingSnapTarget = nil
        overlayPresenter.model.snapPreviewFrame = nil
        overlayPresenter.model.snapGridFrames = []
    }

    private func visibleFrameInQuartzCoordinates(_ screen: NSScreen) -> CGRect {
        let frame = screen.frame
        let visibleFrame = screen.visibleFrame
        return CGRect(
            x: visibleFrame.minX,
            y: frame.maxY - visibleFrame.maxY,
            width: visibleFrame.width,
            height: visibleFrame.height
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

        if windowControlService.isDragging {
            if let pendingSnapTarget {
                return "ปล่อยเพื่อ \(snapStatus(for: pendingSnapTarget))"
            }
            return "กำลังย้าย — ปล่อย pinch เพื่อวาง"
        }
        switch phase {
        case let .candidate(progress):
            return "Pinch เพื่อจับ \(Int(progress * 100))%"
        case .pinching:
            return selectedWindow == nil ? "มองหน้าต่างก่อน pinch" : "กำลังจับ"
        default:
            break
        }
        if fingerCount == 4 {
            return "4 นิ้ว: เลื่อนซ้าย/ขวา"
        }
        if fingerCount == 3 {
            return "3 นิ้ว: ไม่มีคำสั่ง"
        }
        if let selectedWindow {
            return "เลือก \(selectedWindow.appName) — Pinch เพื่อจับ"
        }
        return "มองหน้าต่างเพื่อเลือก"
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
        }
    }

    private func snapStatus(for target: SnapTarget) -> String {
        switch target {
        case .leftHalf:
            "Snap ครึ่งซ้าย"
        case .rightHalf:
            "Snap ครึ่งขวา"
        case .topLeft:
            "Snap มุมซ้ายบน"
        case .topRight:
            "Snap มุมขวาบน"
        case .bottomLeft:
            "Snap มุมซ้ายล่าง"
        case .bottomRight:
            "Snap มุมขวาล่าง"
        case .bottomHalf:
            "Snap ครึ่งล่าง"
        case .fullScreen:
            "Snap เต็มจอ"
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
        clearDragAnchors()
        gazePausedUntil = ProcessInfo.processInfo.systemUptime + 0.7
        clearSnapPreview()
        showActionStatus("Escape — คืนตำแหน่งเดิม", at: ProcessInfo.processInfo.systemUptime)
    }
}
