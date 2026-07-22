import AVFoundation
import Combine
import CoreGraphics
import Vision

struct HandLandmark: Identifiable {
    let name: VNHumanHandPoseObservation.JointName
    let point: CGPoint
    let confidence: Float

    var id: String { name.rawValue.rawValue }
}

struct HandTrackingSnapshot {
    let landmarks: [HandLandmark]
    let phase: PinchPhase

    static let empty = HandTrackingSnapshot(landmarks: [], phase: .noHand)
}

final class HandTrackingService: NSObject, ObservableObject {
    @Published private(set) var snapshot = HandTrackingSnapshot.empty

    private let request: VNDetectHumanHandPoseRequest
    private var pinchDetector = PinchDetector()

    override init() {
        request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        super.init()
    }

    func reset() {
        pinchDetector.reset()
        DispatchQueue.main.async { [weak self] in
            self?.snapshot = .empty
        }
    }

    private func process(_ sampleBuffer: CMSampleBuffer) {
        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            try handler.perform([request])
            guard let observation = request.results?.first else {
                publish(landmarks: [], phase: pinchDetector.update(
                    thumbTip: nil,
                    thumbConfidence: 0,
                    indexTip: nil,
                    indexConfidence: 0,
                    at: CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
                ))
                return
            }

            let points = try observation.recognizedPoints(.all)
            let landmarks = trackedJointNames.compactMap { name -> HandLandmark? in
                guard let point = points[name], point.confidence >= 0.6 else {
                    return nil
                }
                return HandLandmark(
                    name: name,
                    point: point.location,
                    confidence: point.confidence
                )
            }

            let thumbTip = points[.thumbTip]
            let indexTip = points[.indexTip]
            let phase = pinchDetector.update(
                thumbTip: thumbTip?.location,
                thumbConfidence: thumbTip?.confidence ?? 0,
                indexTip: indexTip?.location,
                indexConfidence: indexTip?.confidence ?? 0,
                at: CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            )
            publish(landmarks: landmarks, phase: phase)
        } catch {
            pinchDetector.reset()
            publish(landmarks: [], phase: .noHand)
        }
    }

    private func publish(landmarks: [HandLandmark], phase: PinchPhase) {
        let nextSnapshot = HandTrackingSnapshot(landmarks: landmarks, phase: phase)
        DispatchQueue.main.async { [weak self] in
            self?.snapshot = nextSnapshot
        }
    }
}

extension HandTrackingService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        process(sampleBuffer)
    }
}

private let trackedJointNames: [VNHumanHandPoseObservation.JointName] = [
    .wrist,
    .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
    .indexMCP, .indexPIP, .indexDIP, .indexTip,
    .middleMCP, .middlePIP, .middleDIP, .middleTip,
    .ringMCP, .ringPIP, .ringDIP, .ringTip,
    .littleMCP, .littlePIP, .littleDIP, .littleTip,
]
