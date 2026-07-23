import ApplicationServices
import AppKit

struct TargetWindow: Equatable {
    let windowNumber: CGWindowID
    let processIdentifier: pid_t
    let appName: String
    let title: String
    let frame: CGRect

    var displayName: String {
        title.isEmpty ? appName : "\(appName) — \(title)"
    }
}

final class WindowControlService {
    private struct DragSession {
        let window: AXUIElement
        let originalPosition: CGPoint
        let grabOffset: CGPoint
    }

    private var dragSession: DragSession?

    var isDragging: Bool { dragSession != nil }
    private(set) var lastAXElementDescription: String?

    func window(at point: CGPoint) -> TargetWindow? {
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        for window in windows {
            guard let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let processIdentifier = window[kCGWindowOwnerPID as String] as? pid_t,
                  processIdentifier != ownProcessIdentifier,
                  let windowNumber = window[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDictionary = window[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary),
                  frame.contains(point) else {
                continue
            }

            return TargetWindow(
                windowNumber: windowNumber,
                processIdentifier: processIdentifier,
                appName: window[kCGWindowOwnerName as String] as? String ?? "Unknown app",
                title: window[kCGWindowName as String] as? String ?? "",
                frame: frame
            )
        }
        return nil
    }

    func beginDrag(target: TargetWindow, cursor: CGPoint) -> Bool {
        lastAXElementDescription = nil
        guard AXIsProcessTrusted(), let window = accessibilityWindow(for: target) else {
            return false
        }
        lastAXElementDescription = "\(target.processIdentifier):\(target.title.isEmpty ? target.appName : target.title)"

        let originalPosition = position(of: window) ?? target.frame.origin
        dragSession = DragSession(
            window: window,
            originalPosition: originalPosition,
            grabOffset: CGPoint(
                x: cursor.x - target.frame.minX,
                y: cursor.y - target.frame.minY
            )
        )
        return true
    }

    func updateDrag(cursor: CGPoint) -> AXError? {
        guard let dragSession else { return nil }
        var position = CGPoint(
            x: cursor.x - dragSession.grabOffset.x,
            y: cursor.y - dragSession.grabOffset.y
        )
        guard let value = AXValueCreate(.cgPoint, &position) else { return .failure }
        return AXUIElementSetAttributeValue(
            dragSession.window,
            kAXPositionAttribute as CFString,
            value
        )
    }

    @discardableResult
    func endDrag(snappingTo frame: CGRect? = nil) -> Bool {
        guard let dragSession else { return false }
        defer { self.dragSession = nil }
        guard let frame else { return true }
        return setFrame(frame, on: dragSession.window)
    }

    func cancelDrag() {
        guard let dragSession else { return }
        var originalPosition = dragSession.originalPosition
        if let value = AXValueCreate(.cgPoint, &originalPosition) {
            AXUIElementSetAttributeValue(
                dragSession.window,
                kAXPositionAttribute as CFString,
                value
            )
        }
        self.dragSession = nil
    }

    func perform(_ action: WorkspaceGestureAction) {
        let keyCode: CGKeyCode
        switch action {
        case .switchDesktopLeft:
            keyCode = 123
        case .switchDesktopRight:
            keyCode = 124
        case .missionControl:
            keyCode = 126
        }

        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        keyDown.flags = .maskControl
        keyUp.flags = .maskControl
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    func setFrame(_ frame: CGRect, for target: TargetWindow) -> Bool {
        guard AXIsProcessTrusted(), let window = accessibilityWindow(for: target) else {
            return false
        }
        return setFrame(frame, on: window)
    }

    private func setFrame(_ frame: CGRect, on window: AXUIElement) -> Bool {
        var position = frame.origin
        var size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            return false
        }
        let positionResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            positionValue
        )
        let sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )
        return positionResult == .success && sizeResult == .success
    }

    private func accessibilityWindow(for target: TargetWindow) -> AXUIElement? {
        let application = AXUIElementCreateApplication(target.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application,
            kAXWindowsAttribute as CFString,
            &value
        ) == .success,
              let windows = value as? [AXUIElement] else {
            return nil
        }

        return windows.min { first, second in
            frameDistance(frame(of: first), target.frame) < frameDistance(frame(of: second), target.frame)
        }
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        guard let position = position(of: window), let size = size(of: window) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func position(of window: AXUIElement) -> CGPoint? {
        copyValue(kAXPositionAttribute, from: window, type: .cgPoint)
    }

    private func size(of window: AXUIElement) -> CGSize? {
        copyValue(kAXSizeAttribute, from: window, type: .cgSize)
    }

    private func copyValue<T>(
        _ attribute: String,
        from element: AXUIElement,
        type: AXValueType
    ) -> T? {
        var rawValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &rawValue
        ) == .success,
              let rawValue,
              CFGetTypeID(rawValue) == AXValueGetTypeID() else {
            return nil
        }
        let value = unsafeBitCast(rawValue, to: AXValue.self)
        guard
              AXValueGetType(value) == type else {
            return nil
        }

        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        guard AXValueGetValue(value, type, pointer) else { return nil }
        return pointer.pointee
    }

    private func frameDistance(_ candidate: CGRect?, _ target: CGRect) -> CGFloat {
        guard let candidate else { return .greatestFiniteMagnitude }
        return abs(candidate.minX - target.minX)
            + abs(candidate.minY - target.minY)
            + abs(candidate.width - target.width)
            + abs(candidate.height - target.height)
    }
}
