import AVFoundation
import AppKit
import ApplicationServices
import SwiftUI

@MainActor
final class PermissionsModel: ObservableObject {
    @Published private(set) var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var isAccessibilityTrusted = AXIsProcessTrusted()

    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAccessibilityStatus()
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    func requestCameraPermission() {
        guard cameraStatus == .notDetermined else {
            openCameraSettings()
            return
        }

        AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
            Task { @MainActor in
                self?.cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshAccessibilityStatus()
    }

    func refreshAccessibilityStatus() {
        isAccessibilityTrusted = AXIsProcessTrusted()
    }

    private func openCameraSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

struct PermissionsOnboarding: View {
    @StateObject private var permissions = PermissionsModel()
    @State private var page = 0
    @ObservedObject var settings: VisionSnapSettings
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            if page == 0 {
                cameraPage
            } else if page == 1 {
                accessibilityPage
            } else {
                trackpadPage
            }
        }
        .padding(32)
        .frame(width: 500, height: 340)
    }

    private var cameraPage: some View {
        permissionPage(
            icon: "camera.fill",
            title: "Camera Permission",
            explanation: "VisionSnap uses the camera only while gesture mode is ON. Frames stay in memory and are never recorded, stored, or transmitted.",
            status: cameraStatusText,
            actionTitle: cameraActionTitle,
            action: permissions.requestCameraPermission,
            isNextEnabled: permissions.cameraStatus == .authorized,
            nextTitle: "Continue",
            nextAction: { page = 1 }
        )
    }

    private var accessibilityPage: some View {
        permissionPage(
            icon: "accessibility",
            title: "Accessibility Permission",
            explanation: "Accessibility access lets VisionSnap move and resize windows. It does not read window contents.",
            status: permissions.isAccessibilityTrusted ? "Granted" : "Not granted",
            actionTitle: "Open System Prompt",
            action: permissions.requestAccessibilityPermission,
            isNextEnabled: permissions.isAccessibilityTrusted,
            nextTitle: "Continue",
            nextAction: {
                page = 2
            }
        )
    }

    private var trackpadPage: some View {
        VStack(spacing: 18) {
            Image(systemName: "rectangle.and.hand.point.up.left")
                .font(.system(size: 42))
                .foregroundStyle(.tint)

            Text("Optional Trackpad Gestures")
                .font(.title2.bold())

            Text("If enabled, VisionSnap temporarily turns off macOS’s native 4-finger horizontal swipe while VisionSnap runs, then restores your original setting when disabled or quit.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Toggle("Enable trackpad workspace gestures", isOn: $settings.trackpadEnabled)

            HStack {
                Spacer()
                Button("Finish", action: onFinish)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func permissionPage(
        icon: String,
        title: String,
        explanation: String,
        status: String,
        actionTitle: String,
        action: @escaping () -> Void,
        isNextEnabled: Bool,
        nextTitle: String,
        nextAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundStyle(.tint)

            Text(title)
                .font(.title2.bold())

            Text(explanation)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text("Status: \(status)")
                .font(.callout.monospacedDigit())

            HStack {
                Button(actionTitle, action: action)
                Spacer()
                Button(nextTitle, action: nextAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isNextEnabled)
            }
        }
    }

    private var cameraStatusText: String {
        switch permissions.cameraStatus {
        case .authorized: "Granted"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .notDetermined: "Not requested"
        @unknown default: "Unknown"
        }
    }

    private var cameraActionTitle: String {
        switch permissions.cameraStatus {
        case .notDetermined: "Allow Camera"
        case .authorized: "Camera Settings"
        default: "Open Camera Settings"
        }
    }
}
