import Darwin
import Foundation

enum TrackpadNativeGestureError: LocalizedError {
    case pendingRecovery
    case commandFailed
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .pendingRecovery:
            "VisionSnap must restore the previous trackpad setting before enabling trackpad mode."
        case .commandFailed:
            "VisionSnap could not update the native trackpad setting."
        case .verificationFailed:
            "macOS did not apply the native trackpad setting."
        }
    }
}

final class TrackpadNativeGestureManager {
    static let shared = TrackpadNativeGestureManager()

    private struct SavedValue: Codable {
        let domain: String
        let value: Int?
    }

    private struct Marker: Codable {
        let values: [SavedValue]
    }

    private let key = "TrackpadFourFingerHorizSwipeGesture"
    private let domains = [
        "com.apple.AppleMultitouchTrackpad",
        "com.apple.driver.AppleBluetoothMultitouch.trackpad",
    ]
    private let markerURL: URL
    private var signalSources: [DispatchSourceSignal] = []

    private init() {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        markerURL = applicationSupport
            .appendingPathComponent("VisionSnap", isDirectory: true)
            .appendingPathComponent("trackpad-restore.json")
        installSignalHandlers()
    }

    var hasPendingRestore: Bool {
        FileManager.default.fileExists(atPath: markerURL.path)
    }

    @discardableResult
    func restorePendingAtLaunch() -> Bool {
        guard hasPendingRestore else { return false }
        let restored = restore()
        print("[TRACKPAD] crashRecovery=\(restored ? "restored" : "failed")")
        return restored
    }

    func disableNativeSwipe() throws {
        guard !hasPendingRestore else {
            throw TrackpadNativeGestureError.pendingRecovery
        }

        let marker = Marker(values: domains.map {
            SavedValue(domain: $0, value: read(domain: $0))
        })
        try FileManager.default.createDirectory(
            at: markerURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(marker).write(to: markerURL, options: .atomic)

        for domain in domains {
            guard write(value: 0, domain: domain) else {
                _ = restore()
                throw TrackpadNativeGestureError.commandFailed
            }
        }
        guard domains.allSatisfy({ read(domain: $0) == 0 }) else {
            _ = restore()
            throw TrackpadNativeGestureError.verificationFailed
        }
        print("[TRACKPAD] nativeFourFingerSwipe=disabled")
    }

    @discardableResult
    func restore() -> Bool {
        guard let data = try? Data(contentsOf: markerURL),
              let marker = try? JSONDecoder().decode(Marker.self, from: data) else {
            return !hasPendingRestore
        }

        let restored = marker.values.allSatisfy { savedValue in
            if let value = savedValue.value {
                return write(value: value, domain: savedValue.domain)
                    && read(domain: savedValue.domain) == value
            }
            return delete(domain: savedValue.domain) && read(domain: savedValue.domain) == nil
        }
        guard restored else { return false }
        try? FileManager.default.removeItem(at: markerURL)
        print("[TRACKPAD] nativeFourFingerSwipe=restored")
        return true
    }

    private func read(domain: String) -> Int? {
        let result = runDefaults(["read", domain, key])
        guard result.exitCode == 0 else { return nil }
        return Int(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func write(value: Int, domain: String) -> Bool {
        runDefaults(["write", domain, key, "-int", String(value)]).exitCode == 0
    }

    private func delete(domain: String) -> Bool {
        let result = runDefaults(["delete", domain, key])
        return result.exitCode == 0 || read(domain: domain) == nil
    }

    private func runDefaults(_ arguments: [String]) -> (exitCode: Int32, output: String) {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            return (process.terminationStatus, String(decoding: data, as: UTF8.self))
        } catch {
            return (-1, "")
        }
    }

    private func installSignalHandlers() {
        for signalNumber in [SIGTERM, SIGINT] {
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(
                signal: signalNumber,
                queue: .main
            )
            source.setEventHandler { [weak self] in
                _ = self?.restore()
                Darwin.exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
    }
}
