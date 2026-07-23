import AppKit
import AVFoundation
import Combine
import SwiftUI

@MainActor
final class MenuBarController: ObservableObject {
    @Published private(set) var isGestureModeEnabled = false
    @Published private(set) var errorMessage: String?

    let handTrackingService: HandTrackingService
    let settings: VisionSnapSettings
    private let cameraService: CameraService
    private let gestureEngine: GestureEngine
    private let hotkeyMonitor = GestureHotkeyMonitor()
    private let trackpadInputService = TrackpadInputService.shared
    private let trackpadNativeGestureManager = TrackpadNativeGestureManager.shared
    private var lastHandSeenAt: TimeInterval?
    private var cancellables = Set<AnyCancellable>()

    init() {
        let handTrackingService = HandTrackingService()
        let settings = VisionSnapSettings.shared
        self.handTrackingService = handTrackingService
        self.settings = settings
        cameraService = CameraService(frameDelegate: handTrackingService)
        gestureEngine = GestureEngine(trackingService: handTrackingService)
        trackpadInputService.onFrame = { [weak gestureEngine] frame, timestamp in
            gestureEngine?.handleTrackpadFrame(frame, at: timestamp)
        }
        if trackpadNativeGestureManager.hasPendingRestore {
            let restored = trackpadNativeGestureManager.restorePendingAtLaunch()
            settings.trackpadEnabled = false
            errorMessage = restored
                ? "Recovered the native trackpad setting after an interrupted session."
                : "Could not restore the native trackpad setting. Trackpad mode remains off."
        }
        observeSettingsAndTracking()
    }

    var captureSession: AVCaptureSession { cameraService.captureSession }

    func toggleGestureMode() {
        if isGestureModeEnabled {
            stopGestureMode()
            return
        }

        do {
            try cameraService.start()
            gestureEngine.start()
            isGestureModeEnabled = true
            errorMessage = nil
            lastHandSeenAt = ProcessInfo.processInfo.systemUptime
            showCameraMonitor()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func showCameraMonitor() {
        CameraMonitorPresenter.shared.show(controller: self)
    }

    private func observeSettingsAndTracking() {
        settings.$hotkey
            .sink { [weak self] hotkey in
                guard let self else { return }
                hotkeyMonitor.update(hotkey: hotkey) { [weak self] in
                    self?.toggleGestureMode()
                }
            }
            .store(in: &cancellables)

        settings.$trackpadEnabled
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                self?.setTrackpadModeEnabled(isEnabled)
            }
            .store(in: &cancellables)

        handTrackingService.$snapshot
            .sink { [weak self] snapshot in
                guard !snapshot.landmarks.isEmpty else { return }
                self?.lastHandSeenAt = ProcessInfo.processInfo.systemUptime
            }
            .store(in: &cancellables)

        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.stopCameraIfIdle()
            }
            .store(in: &cancellables)
    }

    private func stopCameraIfIdle() {
        let timeout = TimeInterval(settings.cameraAutoOff.rawValue)
        guard CameraAutoOffPolicy.shouldStop(
            isGestureModeEnabled: isGestureModeEnabled,
            lastHandSeenAt: lastHandSeenAt,
            now: ProcessInfo.processInfo.systemUptime,
            timeout: timeout
        ) else {
            return
        }
        stopGestureMode()
        errorMessage = "Gesture mode turned off after \(settings.cameraAutoOff.title) without a hand."
    }

    private func setTrackpadModeEnabled(_ isEnabled: Bool) {
        if !isEnabled {
            trackpadInputService.stop()
            guard trackpadNativeGestureManager.restore() else {
                errorMessage = "Could not restore the native trackpad setting."
                return
            }
            return
        }

        do {
            try trackpadNativeGestureManager.disableNativeSwipe()
            try trackpadInputService.start()
            errorMessage = nil
        } catch {
            trackpadInputService.stop()
            _ = trackpadNativeGestureManager.restore()
            errorMessage = error.localizedDescription
            if settings.trackpadEnabled {
                settings.trackpadEnabled = false
            }
        }
    }

    private func stopGestureMode() {
        gestureEngine.stop()
        cameraService.stop()
        handTrackingService.reset()
        isGestureModeEnabled = false
        lastHandSeenAt = nil
    }
}

struct MenuBarContent: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        Button(controller.isGestureModeEnabled ? "Turn Gesture Mode Off" : "Turn Gesture Mode On") {
            controller.toggleGestureMode()
        }

        if let errorMessage = controller.errorMessage {
            Text(errorMessage)
        }

        Divider()

        Button("Show Camera Monitor…") {
            controller.showCameraMonitor()
        }

        Button("Permissions…") {
            PermissionsWindowPresenter.shared.show(force: true)
        }

        Button("Settings…") {
            SettingsWindowPresenter.shared.show(settings: controller.settings)
        }

        Button("Quit VisionSnap") {
            NSApp.terminate(nil)
        }
    }
}
