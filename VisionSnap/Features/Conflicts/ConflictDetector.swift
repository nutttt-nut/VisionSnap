import AppKit
import Foundation

struct WindowManagerConflict: Identifiable, Equatable {
    let id: String
    let name: String
}

struct ConflictDetector {
    private struct KnownApplication {
        let name: String
        let bundleIdentifiers: Set<String>
    }

    private let knownApplications = [
        KnownApplication(
            name: "Rectangle",
            bundleIdentifiers: ["com.knollsoft.Rectangle", "com.knollsoft.Rectangle-Pro"]
        ),
        KnownApplication(
            name: "Magnet",
            bundleIdentifiers: ["com.crowdcafe.windowmagnet"]
        ),
        KnownApplication(
            name: "BetterTouchTool",
            bundleIdentifiers: ["com.hegenberg.BetterTouchTool"]
        )
    ]

    func detect() -> [WindowManagerConflict] {
        let runningBundleIdentifiers = Set(
            NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        )
        let installedBundleIdentifiers = Set(
            knownApplications
                .flatMap(\.bundleIdentifiers)
                .filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
        )

        var conflicts = knownApplications.compactMap { application -> WindowManagerConflict? in
            let isDetected = !application.bundleIdentifiers.isDisjoint(with: runningBundleIdentifiers)
                || !application.bundleIdentifiers.isDisjoint(with: installedBundleIdentifiers)
            return isDetected
                ? WindowManagerConflict(id: application.name, name: application.name)
                : nil
        }

        if isProcessRunning(named: "yabai") {
            conflicts.append(WindowManagerConflict(id: "yabai", name: "yabai"))
        }

        return conflicts
    }

    private func isProcessRunning(named processName: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", processName]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
