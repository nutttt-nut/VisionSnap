import AppKit
import SwiftUI

@MainActor
final class ConflictWarningPresenter {
    static let shared = ConflictWarningPresenter()

    private let dismissedKey = "didDismissWindowManagerConflictWarning"
    private var windowController: NSWindowController?

    func showIfNeeded(conflicts: [WindowManagerConflict]) {
        guard !conflicts.isEmpty,
              !UserDefaults.standard.bool(forKey: dismissedKey) else {
            return
        }

        let view = ConflictWarningView(conflicts: conflicts) { [weak self] in
            guard let self else { return }
            UserDefaults.standard.set(true, forKey: dismissedKey)
            windowController?.close()
            windowController = nil
        }

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "VisionSnap Conflict Warning"
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        windowController = controller
        controller.showWindow(nil)
        window.center()
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct ConflictWarningView: View {
    let conflicts: [WindowManagerConflict]
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Possible window manager conflict", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)

            Text("VisionSnap found \(conflictNames). These apps may compete for window control. Disable overlapping shortcuts in those apps if needed.")
                .fixedSize(horizontal: false, vertical: true)

            Text("VisionSnap will not disable or change other apps.")
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Dismiss", action: dismiss)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private var conflictNames: String {
        conflicts.map(\.name).joined(separator: ", ")
    }
}
