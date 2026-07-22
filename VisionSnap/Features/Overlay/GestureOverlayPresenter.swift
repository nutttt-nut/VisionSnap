import AppKit
import SwiftUI

@MainActor
final class GestureOverlayModel: ObservableObject {
    @Published var cursorPoint: CGPoint?
    @Published var selectedWindow: TargetWindow?
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
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: GestureOverlayView(model: model))
        panel.orderFrontRegardless()
        window = panel
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        model.cursorPoint = nil
        model.selectedWindow = nil
        model.statusText = nil
    }
}

private struct GestureOverlayView: View {
    @ObservedObject var model: GestureOverlayModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let window = model.selectedWindow {
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
                    .stroke(.cyan, lineWidth: 4)
                    .background(Circle().fill(.black.opacity(0.35)))
                    .frame(width: 30, height: 30)
                    .position(cursor)

                if let statusText = model.statusText {
                    Text(statusText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 6))
                        .position(x: cursor.x + 75, y: cursor.y + 28)
                }
            }
        }
        .ignoresSafeArea()
    }
}
