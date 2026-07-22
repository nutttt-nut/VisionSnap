import AppKit
import SwiftUI

@MainActor
final class CameraMonitorPresenter {
    static let shared = CameraMonitorPresenter()

    private var windowController: NSWindowController?

    func show(controller: MenuBarController) {
        if let windowController {
            windowController.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VisionSnap Camera Monitor"
        window.contentMinSize = NSSize(width: 360, height: 280)
        window.contentView = NSHostingView(
            rootView: CameraMonitorView(controller: controller)
        )
        window.isReleasedWhenClosed = false

        let newWindowController = NSWindowController(window: window)
        windowController = newWindowController
        newWindowController.showWindow(nil)
        window.center()
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct CameraMonitorView: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                CameraPreview(session: controller.captureSession)
                    .aspectRatio(16 / 9, contentMode: .fit)

                Label(
                    controller.isGestureModeEnabled ? "Camera ON" : "Camera OFF",
                    systemImage: controller.isGestureModeEnabled
                        ? "circle.fill"
                        : "circle"
                )
                .font(.caption.bold())
                .foregroundStyle(controller.isGestureModeEnabled ? .green : .secondary)
                .padding(8)
                .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
                .padding(10)
            }
            .background(.black)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Input: Built-in camera")
                            .font(.callout.bold())
                        Text("Detection: Not implemented yet (Phase 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(controller.isGestureModeEnabled ? "Turn Off" : "Turn On") {
                        controller.toggleGestureMode()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let errorMessage = controller.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(14)
        }
        .frame(minWidth: 360, minHeight: 280)
    }
}
