import CoreGraphics
import Foundation
import Vision

@main
struct HandPoseAnalyzerTests {
    typealias Joint = VNHumanHandPoseObservation.JointName

    static func main() {
        let openHand = points(thumbTip: CGPoint(x: 0.15, y: 0.4))
        expect(HandPoseAnalyzer.analyze(openHand).extendedFingerCount == 5, "open hand must report 5")

        let fourFingers = points(thumbTip: CGPoint(x: 0.48, y: 0.27))
        expect(HandPoseAnalyzer.analyze(fourFingers).extendedFingerCount == 4, "folded thumb must report 4")

        var pointing = points(
            thumbTip: CGPoint(x: 0.48, y: 0.24),
            fingerTipY: 0.27,
            fingerInnerY: 0.25
        )
        pointing[.indexPIP] = CGPoint(x: 0.4, y: 0.55)
        pointing[.indexTip] = CGPoint(x: 0.4, y: 0.85)
        expect(HandPoseAnalyzer.analyze(pointing).isIndexPointing, "index-only pose must point")

        pointing[.middlePIP] = CGPoint(x: 0.5, y: 0.55)
        pointing[.middleTip] = CGPoint(x: 0.5, y: 0.85)
        expect(!HandPoseAnalyzer.analyze(pointing).isIndexPointing, "V pose must not point")

        let fist = points(
            thumbTip: CGPoint(x: 0.48, y: 0.24),
            fingerTipY: 0.27,
            fingerInnerY: 0.25
        )
        expect(HandPoseAnalyzer.analyze(fist).isFist, "folded fingers must report fist")

        let eye = [
            CGPoint(x: 0.2, y: 0.45),
            CGPoint(x: 0.4, y: 0.45),
            CGPoint(x: 0.4, y: 0.55),
            CGPoint(x: 0.2, y: 0.55),
        ]
        let centeredSignal = GazeEstimator.signal(
            leftEye: eye,
            leftPupil: CGPoint(x: 0.3, y: 0.5),
            rightEye: eye,
            rightPupil: CGPoint(x: 0.3, y: 0.5),
            yaw: 0,
            pitch: 0
        )
        let rightSignal = GazeEstimator.signal(
            leftEye: eye,
            leftPupil: CGPoint(x: 0.34, y: 0.5),
            rightEye: eye,
            rightPupil: CGPoint(x: 0.34, y: 0.5),
            yaw: 0,
            pitch: 0
        )
        expect((rightSignal?.x ?? 0) > (centeredSignal?.x ?? 0), "right pupil movement must change gaze signal")

        var calibrator = GazeCalibrator(requiredSamples: 2, horizontalGain: 2, verticalGain: 2)
        expect(
            calibrator.update(signal: CGPoint(x: 0.2, y: -0.1)) == nil,
            "calibration must wait for enough samples"
        )
        let calibratedCenter = calibrator.update(signal: CGPoint(x: 0.2, y: -0.1))
        expect(pointsEqual(calibratedCenter, CGPoint(x: 0.5, y: 0.5)), "baseline must map to center")
        let calibratedMove = calibrator.update(signal: CGPoint(x: 0.3, y: 0))
        expect(pointsEqual(calibratedMove, CGPoint(x: 0.7, y: 0.7)), "gaze delta must map from baseline")

        print("HandPoseAnalyzerTests: all checks passed")
    }

    private static func points(
        thumbTip: CGPoint,
        fingerTipY: CGFloat = 0.85,
        fingerInnerY: CGFloat = 0.55
    ) -> [Joint: CGPoint] {
        [
            .wrist: CGPoint(x: 0.5, y: 0.1),
            .thumbIP: CGPoint(x: 0.45, y: 0.25),
            .thumbTip: thumbTip,
            .indexMCP: CGPoint(x: 0.4, y: 0.3),
            .indexPIP: CGPoint(x: 0.4, y: fingerInnerY),
            .indexTip: CGPoint(x: 0.4, y: fingerTipY),
            .middleMCP: CGPoint(x: 0.5, y: 0.3),
            .middlePIP: CGPoint(x: 0.5, y: fingerInnerY),
            .middleTip: CGPoint(x: 0.5, y: fingerTipY),
            .ringMCP: CGPoint(x: 0.6, y: 0.3),
            .ringPIP: CGPoint(x: 0.6, y: fingerInnerY),
            .ringTip: CGPoint(x: 0.6, y: fingerTipY),
            .littleMCP: CGPoint(x: 0.7, y: 0.28),
            .littlePIP: CGPoint(x: 0.7, y: fingerInnerY),
            .littleTip: CGPoint(x: 0.7, y: fingerTipY),
        ]
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }

    private static func pointsEqual(_ first: CGPoint?, _ second: CGPoint) -> Bool {
        guard let first else { return false }
        return abs(first.x - second.x) < 0.0001 && abs(first.y - second.y) < 0.0001
    }
}
