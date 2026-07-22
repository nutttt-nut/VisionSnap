import AVFoundation

enum CameraServiceError: LocalizedError {
    case permissionDenied
    case cameraUnavailable
    case inputUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Camera permission is required before gesture mode can start."
        case .cameraUnavailable:
            "No camera is available."
        case .inputUnavailable:
            "VisionSnap could not open the camera."
        }
    }
}

final class CameraService {
    private let session = AVCaptureSession()
    private var isConfigured = false

    var isRunning: Bool { session.isRunning }
    var captureSession: AVCaptureSession { session }

    func start() throws {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw CameraServiceError.permissionDenied
        }

        if !isConfigured {
            try configure()
        }

        if !session.isRunning {
            session.startRunning()
        }
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func configure() throws {
        guard let camera = AVCaptureDevice.default(for: .video) else {
            throw CameraServiceError.cameraUnavailable
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: camera)
        } catch {
            throw CameraServiceError.inputUnavailable
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard session.canAddInput(input) else {
            throw CameraServiceError.inputUnavailable
        }

        session.addInput(input)
        isConfigured = true
    }
}
