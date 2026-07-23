import CoreFoundation
import CoreGraphics
import Darwin
import Foundation

enum TrackpadInputError: LocalizedError {
    case frameworkUnavailable
    case symbolUnavailable(String)
    case deviceUnavailable

    var errorDescription: String? {
        switch self {
        case .frameworkUnavailable:
            "Trackpad support is unavailable on this macOS version."
        case let .symbolUnavailable(symbol):
            "Trackpad support is missing the \(symbol) symbol."
        case .deviceUnavailable:
            "No compatible trackpad was found."
        }
    }
}

final class TrackpadInputService {
    static let shared = TrackpadInputService()

    typealias Device = UnsafeMutableRawPointer
    typealias ContactCallback = @convention(c) (
        Device?,
        UnsafeMutableRawPointer?,
        Int32,
        Double,
        Int32
    ) -> Int32
    private typealias CreateList = @convention(c) () -> Unmanaged<CFArray>?
    private typealias CreateDefault = @convention(c) () -> Device?
    private typealias RegisterCallback = @convention(c) (Device?, ContactCallback?) -> Void
    private typealias UnregisterCallback = @convention(c) (Device?, ContactCallback?) -> Void
    private typealias StartDevice = @convention(c) (Device?, Int32) -> Void
    private typealias StopDevice = @convention(c) (Device?) -> Void
    private typealias IsDeviceRunning = @convention(c) (Device?) -> Bool

    var onFrame: ((WorkspaceGestureFrame, TimeInterval) -> Void)?

    private var framework: UnsafeMutableRawPointer?
    private var devices: [Device] = []
    private var createList: CreateList?
    private var createDefault: CreateDefault?
    private var registerCallback: RegisterCallback?
    private var unregisterCallback: UnregisterCallback?
    private var startDevice: StartDevice?
    private var stopDevice: StopDevice?
    private var isDeviceRunning: IsDeviceRunning?
    private(set) var isRunning = false

    private init() {}

    func start() throws {
        guard !isRunning else { return }
        try loadFramework()
        devices = availableDevices()
        guard !devices.isEmpty else {
            throw TrackpadInputError.deviceUnavailable
        }

        for device in devices {
            registerCallback?(device, trackpadContactCallback)
            startDevice?(device, 0)
        }
        isRunning = true
        let runningCount = devices.filter { isDeviceRunning?($0) == true }.count
        print("[TRACKPAD] started devices=\(devices.count) running=\(runningCount)")
    }

    func stop() {
        guard isRunning else { return }
        for device in devices {
            unregisterCallback?(device, trackpadContactCallback)
            stopDevice?(device)
        }
        devices = []
        isRunning = false
        print("[TRACKPAD] stopped")
    }

    fileprivate func receive(
        contacts: UnsafeMutableRawPointer?,
        count: Int,
        timestamp: TimeInterval
    ) {
        let frame = TrackpadContactParser.frame(contacts: contacts, count: count)
        DispatchQueue.main.async { [weak self] in
            self?.onFrame?(frame, timestamp)
        }
    }

    private func loadFramework() throws {
        guard framework == nil else { return }
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let framework = dlopen(path, RTLD_NOW) else {
            throw TrackpadInputError.frameworkUnavailable
        }
        self.framework = framework
        createList = try symbol("MTDeviceCreateList", in: framework)
        createDefault = try symbol("MTDeviceCreateDefault", in: framework)
        registerCallback = try symbol("MTRegisterContactFrameCallback", in: framework)
        unregisterCallback = try symbol("MTUnregisterContactFrameCallback", in: framework)
        startDevice = try symbol("MTDeviceStart", in: framework)
        stopDevice = try symbol("MTDeviceStop", in: framework)
        isDeviceRunning = try symbol("MTDeviceIsRunning", in: framework)
    }

    private func symbol<T>(_ name: String, in framework: UnsafeMutableRawPointer) throws -> T {
        guard let raw = dlsym(framework, name) else {
            throw TrackpadInputError.symbolUnavailable(name)
        }
        return unsafeBitCast(raw, to: T.self)
    }

    private func availableDevices() -> [Device] {
        if let device = createDefault?() {
            return [device]
        }
        if let list = createList?()?.takeRetainedValue() {
            let count = CFArrayGetCount(list)
            let devices = (0..<count).compactMap { index -> Device? in
                guard let value = CFArrayGetValueAtIndex(list, index) else { return nil }
                return UnsafeMutableRawPointer(mutating: value)
            }
            if !devices.isEmpty { return devices }
        }
        return []
    }
}

enum TrackpadContactParser {
    private static let contactStride = 96
    private static let normalizedXOffset = 32
    private static let normalizedYOffset = 36

    static func frame(
        contacts: UnsafeMutableRawPointer?,
        count: Int
    ) -> WorkspaceGestureFrame {
        guard let contacts, count > 0, count <= 10 else {
            return WorkspaceGestureFrame(
                extendedFingerCount: count,
                palmCenter: nil,
                isPinching: false
            )
        }

        var totalX: CGFloat = 0
        var totalY: CGFloat = 0
        for index in 0..<count {
            let base = index * contactStride
            totalX += CGFloat(contacts.load(
                fromByteOffset: base + normalizedXOffset,
                as: Float.self
            ))
            totalY += CGFloat(contacts.load(
                fromByteOffset: base + normalizedYOffset,
                as: Float.self
            ))
        }
        return WorkspaceGestureFrame(
            extendedFingerCount: count,
            palmCenter: CGPoint(
                x: totalX / CGFloat(count),
                y: totalY / CGFloat(count)
            ),
            isPinching: false
        )
    }
}

private let trackpadContactCallback: TrackpadInputService.ContactCallback = {
    _, contacts, count, timestamp, _ in
    TrackpadInputService.shared.receive(
        contacts: contacts,
        count: Int(count),
        timestamp: timestamp
    )
    return 0
}
