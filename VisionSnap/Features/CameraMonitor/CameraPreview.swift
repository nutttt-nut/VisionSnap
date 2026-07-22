import AVFoundation
import SwiftUI
import Vision

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    let landmarks: [HandLandmark]
    let phase: PinchPhase

    func makeNSView(context: Context) -> CameraPreviewContainerView {
        CameraPreviewContainerView(
            session: session,
            landmarks: landmarks,
            phase: phase
        )
    }

    func updateNSView(_ nsView: CameraPreviewContainerView, context: Context) {
        nsView.previewLayer.session = session
        nsView.updateOverlay(landmarks: landmarks, phase: phase)
    }
}

final class CameraPreviewContainerView: NSView {
    let previewLayer: AVCaptureVideoPreviewLayer
    private let overlayLayer = CAShapeLayer()
    private var landmarks: [HandLandmark]
    private var phase: PinchPhase

    init(session: AVCaptureSession, landmarks: [HandLandmark], phase: PinchPhase) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        self.landmarks = landmarks
        self.phase = phase
        super.init(frame: .zero)

        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.black.cgColor
        previewLayer.videoGravity = .resizeAspect
        layer?.addSublayer(previewLayer)
        overlayLayer.fillColor = NSColor.clear.cgColor
        overlayLayer.lineWidth = 2
        layer?.addSublayer(overlayLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
        overlayLayer.frame = bounds

        if let connection = previewLayer.connection,
           connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
        redrawOverlay()
    }

    func updateOverlay(landmarks: [HandLandmark], phase: PinchPhase) {
        self.landmarks = landmarks
        self.phase = phase
        redrawOverlay()
    }

    private func redrawOverlay() {
        let points = Dictionary(uniqueKeysWithValues: landmarks.map {
            (
                $0.name,
                previewLayer.layerPointConverted(
                    fromCaptureDevicePoint: CGPoint(x: $0.point.x, y: 1 - $0.point.y)
                )
            )
        })
        let path = CGMutablePath()

        for jointChain in handSkeleton {
            var hasStarted = false
            for joint in jointChain {
                guard let point = points[joint] else {
                    hasStarted = false
                    continue
                }
                if hasStarted {
                    path.addLine(to: point)
                } else {
                    path.move(to: point)
                    hasStarted = true
                }
            }
        }
        for point in points.values {
            path.addEllipse(in: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6))
        }

        overlayLayer.path = path
        overlayLayer.strokeColor = (
            phase == .pinching ? NSColor.systemGreen : NSColor.systemCyan
        ).cgColor
    }
}

private let handSkeleton: [[VNHumanHandPoseObservation.JointName]] = [
    [.wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip],
    [.wrist, .indexMCP, .indexPIP, .indexDIP, .indexTip],
    [.wrist, .middleMCP, .middlePIP, .middleDIP, .middleTip],
    [.wrist, .ringMCP, .ringPIP, .ringDIP, .ringTip],
    [.wrist, .littleMCP, .littlePIP, .littleDIP, .littleTip],
    [.indexMCP, .middleMCP, .ringMCP, .littleMCP],
]
