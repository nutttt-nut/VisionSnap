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
                CameraPreview(session: controller.captureSession)
                    .aspectRatio(16 / 9, contentMode: .fit)

                HandLandmarkOverlay(
                    landmarks: handTrackingService.snapshot.landmarks,
                    phase: handTrackingService.snapshot.phase
                )
                .aspectRatio(16 / 9, contentMode: .fit)
                .allowsHitTesting(false)

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
            "Hand detected"
        case let .candidate(progress):
            "Pinch candidate \(Int(progress * 100))%"
        case .pinching:
            "PINCHING"
        }
    }

    private var detectionColor: Color {
        handTrackingService.snapshot.phase == .pinching ? .green : .secondary
    }
}

private struct HandLandmarkOverlay: View {
    let landmarks: [HandLandmark]
    let phase: PinchPhase

    var body: some View {
        Canvas { context, size in
            let points = Dictionary(uniqueKeysWithValues: landmarks.map {
                ($0.name, CGPoint(
                    x: (1 - $0.point.x) * size.width,
                    y: (1 - $0.point.y) * size.height
                ))
            })
            let color: Color = phase == .pinching ? .green : .cyan

            for jointChain in handSkeleton {
                var path = Path()
                var hasStarted = false
                for joint in jointChain {
                    guard let point = points[joint] else {
                        hasStarted = false
                        continue
                    }
                    if hasStarted {
                        path.addLine(to: point)
                    } else {
                        path.move(to: point)
                        hasStarted = true
                    }
                }
                context.stroke(path, with: .color(color), lineWidth: 2)
            }

            for point in points.values {
                let dot = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: dot), with: .color(color))
            }
        }
    }
}

private let handSkeleton: [[VNHumanHandPoseObservation.JointName]] = [
    [.wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip],
    [.wrist, .indexMCP, .indexPIP, .indexDIP, .indexTip],
    [.wrist, .middleMCP, .middlePIP, .middleDIP, .middleTip],
    [.wrist, .ringMCP, .ringPIP, .ringDIP, .ringTip],
    [.wrist, .littleMCP, .littlePIP, .littleDIP, .littleTip],
    [.indexMCP, .middleMCP, .ringMCP, .littleMCP],
]
