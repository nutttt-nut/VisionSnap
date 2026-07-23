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
    private var lastHandSeenAt: TimeInterval?
    private var cancellables = Set<AnyCancellable>()

    init() {
        let handTrackingService = HandTrackingService()
        let settings = VisionSnapSettings()
        self.handTrackingService = handTrackingService
        self.settings = settings
        cameraService = CameraService(frameDelegate: handTrackingService)
        gestureEngine = GestureEngine(trackingService: handTrackingService)
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
