import AppKit
import SwiftUI

@MainActor
final class MenuBarController: ObservableObject {
    @Published private(set) var isGestureModeEnabled = false
    @Published private(set) var errorMessage: String?

    private let cameraService = CameraService()

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
        } catch {
            errorMessage = error.localizedDescription
        }
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

        Button("Permissions…") {
            PermissionsWindowPresenter.shared.show(force: true)
        }

        Button("Quit VisionSnap") {
            NSApp.terminate(nil)
        }
    }
}
