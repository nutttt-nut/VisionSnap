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
    let gazePoint: CGPoint?
    let pinchConfidence: Float
    let pinchHoldMilliseconds: Int

    static let empty = HandTrackingSnapshot(
        landmarks: [],
        phase: .noHand,
        gazePoint: nil,
        pinchConfidence: 0,
        pinchHoldMilliseconds: 0
    )
}

final class HandTrackingService: NSObject, ObservableObject {
    @Published private(set) var snapshot = HandTrackingSnapshot.empty

    private let request: VNDetectHumanHandPoseRequest
    private let faceRequest = VNDetectFaceLandmarksRequest()
    private var pinchDetector = PinchDetector()
    private var gazeCalibrator = GazeCalibrator()
    private var gazePausedUntil = -Double.infinity

    override init() {
        request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        super.init()
    }

    func reset() {
        pinchDetector.reset()
        gazeCalibrator.reset()
        gazePausedUntil = -Double.infinity
        DispatchQueue.main.async { [weak self] in
            self?.snapshot = .empty
        }
    }

    private func process(_ sampleBuffer: CMSampleBuffer) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let shouldTrackGaze = timestamp >= gazePausedUntil
        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            let requests: [VNRequest] = shouldTrackGaze ? [request, faceRequest] : [request]
            try handler.perform(requests)
            var gazePoint = shouldTrackGaze ? gazePoint(from: faceRequest.results?.first) : nil
            guard let observation = request.results?.first else {
                publish(landmarks: [], phase: pinchDetector.update(
                    thumbTip: nil,
                    thumbConfidence: 0,
                    indexTip: nil,
                    indexConfidence: 0,
                    handScale: nil,
                    at: timestamp
                ), gazePoint: gazePoint)
                return
            }

            let points = try observation.recognizedPoints(.all)
            let landmarks = trackedJointNames.compactMap { name -> HandLandmark? in
                guard let point = points[name], point.confidence >= 0.4 else {
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
            let handScale: CGFloat? = {
                guard let wrist = points[.wrist]?.location,
                      let middleMCP = points[.middleMCP]?.location else { return nil }
                return hypot(middleMCP.x - wrist.x, middleMCP.y - wrist.y)
            }()
            let phase = pinchDetector.update(
                thumbTip: thumbTip?.location,
                thumbConfidence: thumbTip?.confidence ?? 0,
                indexTip: indexTip?.location,
                indexConfidence: indexTip?.confidence ?? 0,
                handScale: handScale,
                at: timestamp
            )
            if phase == .pinching || isCandidate(phase) {
                gazePausedUntil = timestamp + 0.7
                gazePoint = nil
            }
            publish(landmarks: landmarks, phase: phase, gazePoint: gazePoint)
        } catch {
            pinchDetector.reset()
            publish(landmarks: [], phase: .noHand, gazePoint: nil)
        }
    }

    private func isCandidate(_ phase: PinchPhase) -> Bool {
        if case .candidate = phase { return true }
        return false
    }

    private func gazePoint(from observation: VNFaceObservation?) -> CGPoint? {
        guard let observation,
              let landmarks = observation.landmarks,
              let leftEye = landmarks.leftEye?.normalizedPoints,
              let rightEye = landmarks.rightEye?.normalizedPoints,
              let leftPupil = landmarks.leftPupil?.normalizedPoints.first,
              let rightPupil = landmarks.rightPupil?.normalizedPoints.first else {
            return nil
        }
        guard let signal = GazeEstimator.signal(
            leftEye: leftEye,
            leftPupil: leftPupil,
            rightEye: rightEye,
            rightPupil: rightPupil,
            yaw: CGFloat(truncating: observation.yaw ?? 0),
            pitch: CGFloat(truncating: observation.pitch ?? 0)
        ) else {
            return nil
        }
        return gazeCalibrator.update(signal: signal)
    }

    private func publish(
        landmarks: [HandLandmark],
        phase: PinchPhase,
        gazePoint: CGPoint?
    ) {
        let nextSnapshot = HandTrackingSnapshot(
            landmarks: landmarks,
            phase: phase,
            gazePoint: gazePoint,
            pinchConfidence: pinchDetector.diagnosticConfidence,
            pinchHoldMilliseconds: pinchDetector.diagnosticHoldMilliseconds
        )
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
