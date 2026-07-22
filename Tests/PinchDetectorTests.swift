import CoreGraphics
import Foundation

@main
struct PinchDetectorTests {
    static func main() {
        var detector = PinchDetector()
        let thumb = CGPoint(x: 0.4, y: 0.5)
        let nearIndex = CGPoint(x: 0.45, y: 0.5)
        let farIndex = CGPoint(x: 0.6, y: 0.5)

        expect(
            detector.update(
                thumbTip: nil,
                thumbConfidence: 0,
                indexTip: nil,
                indexConfidence: 0,
                at: 0
            ) == .noHand,
            "missing landmarks must report no hand"
        )
        expect(
            detector.update(
                thumbTip: thumb,
                thumbConfidence: 0.59,
                indexTip: nearIndex,
                indexConfidence: 0.9,
                at: 0
            ) == .lowConfidence,
            "confidence below 0.6 must be rejected"
        )
        expect(
            detector.update(
                thumbTip: thumb,
                thumbConfidence: 0.6,
                indexTip: farIndex,
                indexConfidence: 0.6,
                at: 0
            ) == .open,
            "confidence exactly 0.6 must be accepted"
        )

        _ = detector.update(
            thumbTip: thumb,
            thumbConfidence: 0.9,
            indexTip: nearIndex,
            indexConfidence: 0.9,
            at: 1
        )
        expect(
            detector.update(
                thumbTip: thumb,
                thumbConfidence: 0.9,
                indexTip: nearIndex,
                indexConfidence: 0.9,
                at: 1.149
            ) != .pinching,
            "pinch must not activate before 150ms"
        )
        expect(
            detector.update(
                thumbTip: thumb,
                thumbConfidence: 0.9,
                indexTip: nearIndex,
                indexConfidence: 0.9,
                at: 1.151
            ) == .pinching,
            "pinch must activate after 150ms"
        )
        expect(
            detector.update(
                thumbTip: thumb,
                thumbConfidence: 0.9,
                indexTip: farIndex,
                indexConfidence: 0.9,
                at: 1.2
            ) == .open,
            "opening the hand must reset the pinch"
        )

        print("PinchDetectorTests: all checks passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fatalError(message)
        }
    }
}
