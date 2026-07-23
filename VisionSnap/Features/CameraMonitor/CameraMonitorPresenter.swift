import AppKit
import SwiftUI
import Vision

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
    @ObservedObject private var handTrackingService: HandTrackingService

    init(controller: MenuBarController) {
        self.controller = controller
        handTrackingService = controller.handTrackingService
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                CameraPreview(
                    session: controller.captureSession,
                    landmarks: handTrackingService.snapshot.landmarks,
                    phase: handTrackingService.snapshot.phase
                )
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
                        Text("Detection: \(detectionText)")
                            .font(.caption)
                            .foregroundStyle(detectionColor)
                        Text("Mode: \(interactionModeText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Accessibility: \(AXIsProcessTrusted() ? "Granted" : "Missing")")
                            .font(.caption)
                            .foregroundStyle(AXIsProcessTrusted() ? Color.secondary : Color.red)
                        Text("Gaze: \(gazeText)")
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

    private var detectionText: String {
        switch handTrackingService.snapshot.phase {
        case .noHand:
            "No hand"
        case .lowConfidence:
            "Low confidence"
        case .open:
            fingerCount.map { "Hand detected · \($0) fingers" } ?? "Hand detected"
        case let .candidate(progress):
            "Pinch candidate \(Int(progress * 100))%"
        case .pinching:
            "PINCHING"
        }
    }

    private var fingerCount: Int? {
        let points = Dictionary(uniqueKeysWithValues: handTrackingService.snapshot.landmarks.map {
            ($0.name, $0.point)
        })
        return HandPoseAnalyzer.analyze(points).extendedFingerCount
    }

    private var interactionModeText: String {
        let points = Dictionary(uniqueKeysWithValues: handTrackingService.snapshot.landmarks.map {
            ($0.name, $0.point)
        })
        let pose = HandPoseAnalyzer.analyze(points)
        switch HandInteractionModeResolver.resolve(
            fingerCount: pose.extendedFingerCount,
            phase: handTrackingService.snapshot.phase,
            isDragging: false,
            isFist: pose.isFist
        ) {
        case .pointer:
            return "Pointer"
        case .workspace:
            return "Workspace gesture"
        case .inactive:
            return "Inactive"
        }
    }

    private var detectionColor: Color {
        handTrackingService.snapshot.phase == .pinching ? .green : .secondary
    }

    private var gazeText: String {
        guard let point = handTrackingService.snapshot.gazePoint else {
            return "Not detected"
        }
        return String(format: "x %.2f · y %.2f", point.x, point.y)
    }
}
