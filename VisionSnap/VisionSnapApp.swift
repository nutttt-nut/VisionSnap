import ApplicationServices
import SwiftUI

@main
struct VisionSnapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var menuBarController = MenuBarController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(controller: menuBarController)
        } label: {
            Label(
                menuBarController.isGestureModeEnabled ? "VisionSnap On" : "VisionSnap Off",
                systemImage: menuBarController.isGestureModeEnabled
                    ? "hand.raised.fill"
                    : "hand.raised.slash"
            )
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[GESTURE] AXIsProcessTrusted=\(AXIsProcessTrusted())")
        let showConflicts = {
            let conflicts = ConflictDetector().detect()
            ConflictWarningPresenter.shared.showIfNeeded(conflicts: conflicts)
        }

        let didShowOnboarding = PermissionsWindowPresenter.shared.showIfNeeded(
            onFinish: showConflicts
        )
        if !didShowOnboarding {
            showConflicts()
        }
    }
}
