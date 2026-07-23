import AppKit
import SwiftUI

@MainActor
final class GestureOverlayModel: ObservableObject {
    @Published var cursorPoint: CGPoint?
    @Published var gazePoint: CGPoint?
    @Published var gesturePoint: CGPoint?
    @Published var selectedWindow: TargetWindow?
    @Published var snapPreviewFrame: CGRect?
    @Published var snapGridFrames: [CGRect] = []
    @Published var isGrabbing = false
    @Published var statusText: String?
}

@MainActor
final class GestureOverlayPresenter {
    let model = GestureOverlayModel()

    private var window: NSPanel?

    func show() {
        guard window == nil, let screen = NSScreen.screens.first else { return }
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let hostingView = NSHostingView(rootView: GestureOverlayView(model: model))
        hostingView.frame = CGRect(origin: .zero, size: screen.frame.size)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        panel.setContentSize(screen.frame.size)
        panel.setFrameOrigin(screen.frame.origin)
        panel.contentMinSize = screen.frame.size
        panel.contentMaxSize = screen.frame.size
        panel.orderFrontRegardless()
        window = panel
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        model.cursorPoint = nil
        model.gazePoint = nil
        model.gesturePoint = nil
        model.selectedWindow = nil
        model.snapPreviewFrame = nil
        model.snapGridFrames = []
        model.isGrabbing = false
        model.statusText = nil
    }
}

private struct GestureOverlayView: View {
    @ObservedObject var model: GestureOverlayModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(model.snapGridFrames.enumerated()), id: \.offset) { _, frame in
                Rectangle()
                    .stroke(.cyan.opacity(0.45), lineWidth: 2)
                    .background(.cyan.opacity(0.04))
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }

            if let frame = model.snapPreviewFrame {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.cyan.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.cyan, lineWidth: 4)
                    )
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }

            if let window = model.selectedWindow, !model.isGrabbing {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.yellow, lineWidth: 4)
                    .frame(width: window.frame.width, height: window.frame.height)
                    .position(x: window.frame.midX, y: window.frame.midY)

                Text(window.displayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.yellow, in: RoundedRectangle(cornerRadius: 7))
                    .position(
                        x: max(100, window.frame.minX + 100),
                        y: max(20, window.frame.minY - 18)
                    )
            }

            if let cursor = model.cursorPoint {
                Circle()
                    .fill(model.isGrabbing ? .green : .black.opacity(0.35))
                    .overlay(
                        Circle().stroke(model.isGrabbing ? .white : .cyan, lineWidth: 4)
                    )
                    .frame(width: model.isGrabbing ? 40 : 30, height: model.isGrabbing ? 40 : 30)
                    .position(cursor)
            }

            if model.isGrabbing {
                Text("จับอยู่ — ปล่อยนิ้วเพื่อวาง")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.green.opacity(0.9), in: Capsule())
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.top, 24)
            }

            if let gaze = model.gazePoint {
                ZStack {
                    Circle().stroke(.pink, lineWidth: 3)
                    Circle().fill(.pink).frame(width: 5, height: 5)
                }
                .frame(width: 18, height: 18)
                .position(gaze)
            }

            if let gesturePoint = model.gesturePoint {
                ZStack {
                    Circle().fill(.purple.opacity(0.85))
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(.white)
                }
                .frame(width: 38, height: 38)
                .position(gesturePoint)
            }

            if let statusText = model.statusText,
               let anchor = model.cursorPoint ?? model.gesturePoint ?? model.gazePoint {
                Text(statusText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 6))
                    .position(x: anchor.x + 85, y: anchor.y + 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()
    }
}
