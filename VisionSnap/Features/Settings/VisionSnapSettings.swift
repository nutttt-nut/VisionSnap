import AppKit
import Combine
import SwiftUI

enum GestureHotkey: String, CaseIterable, Identifiable {
    case controlOptionV
    case controlOptionG
    case disabled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .controlOptionV: "Control + Option + V"
        case .controlOptionG: "Control + Option + G"
        case .disabled: "Disabled"
        }
    }

    fileprivate var key: String? {
        switch self {
        case .controlOptionV: "v"
        case .controlOptionG: "g"
        case .disabled: nil
        }
    }
}

enum CameraAutoOffInterval: Int, CaseIterable, Identifiable {
    case oneMinute = 60
    case fiveMinutes = 300
    case tenMinutes = 600
    case disabled = 0

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .oneMinute: "1 minute"
        case .fiveMinutes: "5 minutes"
        case .tenMinutes: "10 minutes"
        case .disabled: "Never"
        }
    }
}

@MainActor
final class VisionSnapSettings: ObservableObject {
    static let shared = VisionSnapSettings()

    private enum Key {
        static let hotkey = "gestureModeHotkey"
        static let cameraAutoOff = "cameraAutoOffSeconds"
        static let trackpadEnabled = "trackpadWorkspaceGesturesEnabled"
    }

    @Published var hotkey: GestureHotkey {
        didSet { defaults.set(hotkey.rawValue, forKey: Key.hotkey) }
    }

    @Published var cameraAutoOff: CameraAutoOffInterval {
        didSet { defaults.set(cameraAutoOff.rawValue, forKey: Key.cameraAutoOff) }
    }

    @Published var trackpadEnabled: Bool {
        didSet { defaults.set(trackpadEnabled, forKey: Key.trackpadEnabled) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hotkey = GestureHotkey(
            rawValue: defaults.string(forKey: Key.hotkey) ?? ""
        ) ?? .controlOptionV

        if defaults.object(forKey: Key.cameraAutoOff) == nil {
            cameraAutoOff = .fiveMinutes
        } else {
            cameraAutoOff = CameraAutoOffInterval(
                rawValue: defaults.integer(forKey: Key.cameraAutoOff)
            ) ?? .fiveMinutes
        }
        trackpadEnabled = defaults.bool(forKey: Key.trackpadEnabled)
    }
}

@MainActor
final class GestureHotkeyMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func update(hotkey: GestureHotkey, action: @escaping @MainActor () -> Void) {
        stop()
        guard hotkey != .disabled else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard Self.matches(event, hotkey: hotkey) else { return }
            Task { @MainActor in action() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard Self.matches(event, hotkey: hotkey) else { return event }
            Task { @MainActor in action() }
            return nil
        }
    }

    private func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private static func matches(_ event: NSEvent, hotkey: GestureHotkey) -> Bool {
        guard let key = hotkey.key,
              event.charactersIgnoringModifiers?.lowercased() == key else {
            return false
        }
        let relevantFlags = event.modifierFlags.intersection([
            .command, .control, .option, .shift,
        ])
        return relevantFlags == [.control, .option]
    }
}

@MainActor
final class SettingsWindowPresenter {
    static let shared = SettingsWindowPresenter()

    private var windowController: NSWindowController?

    func show(settings: VisionSnapSettings) {
        if let windowController {
            windowController.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "VisionSnap Settings"
        window.contentView = NSHostingView(
            rootView: VisionSnapSettingsView(settings: settings)
        )
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        windowController = controller
        controller.showWindow(nil)
        window.center()
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct VisionSnapSettingsView: View {
    @ObservedObject var settings: VisionSnapSettings

    var body: some View {
        Form {
            Picker("Toggle gesture mode", selection: $settings.hotkey) {
                ForEach(GestureHotkey.allCases) { hotkey in
                    Text(hotkey.title).tag(hotkey)
                }
            }

            Picker("Turn camera off after no hand", selection: $settings.cameraAutoOff) {
                ForEach(CameraAutoOffInterval.allCases) { interval in
                    Text(interval.title).tag(interval)
                }
            }

            Text("The camera is always off when gesture mode is off.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Toggle("Trackpad workspace gestures", isOn: $settings.trackpadEnabled)

            Text("While enabled, VisionSnap temporarily turns off macOS’s native 4-finger horizontal swipe to prevent double actions, then restores your original setting when disabled or quit.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 420, height: 320)
    }
}
