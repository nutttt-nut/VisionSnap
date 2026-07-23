import AppKit
import AVFoundation
import ApplicationServices
import SwiftUI

@MainActor
final class PermissionsWindowPresenter {
    static let shared = PermissionsWindowPresenter()

    private let completedKey = "onboardingCompleted"
    private var windowController: NSWindowController?

    @discardableResult
    func showIfNeeded(onFinish: (() -> Void)? = nil) -> Bool {
        let permissionsAreReady = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
            && AXIsProcessTrusted()
        guard !UserDefaults.standard.bool(forKey: completedKey) || !permissionsAreReady else {
            return false
        }

        show(force: true, onFinish: onFinish)
        return true
    }

    func show(force: Bool, onFinish: (() -> Void)? = nil) {
        if let windowController {
            windowController.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard force || !UserDefaults.standard.bool(forKey: completedKey) else {
            return
        }

        let view = PermissionsOnboarding(settings: VisionSnapSettings.shared) { [weak self] in
            guard let self else { return }
            UserDefaults.standard.set(true, forKey: completedKey)
            windowController?.close()
            windowController = nil
            onFinish?()
        }

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "VisionSnap Setup"
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        windowController = controller
        controller.showWindow(nil)
        window.center()
        NSApp.activate(ignoringOtherApps: true)
    }
}
