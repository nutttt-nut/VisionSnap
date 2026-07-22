import AppKit
import AVFoundation
import SwiftUI

@MainActor
final class MenuBarController: ObservableObject {
    @Published private(set) var isGestureModeEnabled = false
    @Published private(set) var errorMessage: String?

    private let cameraService = CameraService()

    var captureSession: AVCaptureSession { cameraService.captureSession }

    func toggleGestureMode() {
        if isGestureModeEnabled {
            cameraService.stop()
            isGestureModeEnabled = false
            return
        }

        do {
            try cameraService.start()
            isGestureModeEnabled = true
            errorMessage = nil
            showCameraMonitor()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func showCameraMonitor() {
        CameraMonitorPresenter.shared.show(controller: self)
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

        Button("Quit VisionSnap") {
            NSApp.terminate(nil)
        }
    }
}
