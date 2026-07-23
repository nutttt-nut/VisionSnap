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
                handScale: nil,
                at: 0
            ) == .noHand,
            "missing landmarks must report no hand"
        )
        expect(
            detector.update(
                thumbTip: thumb,
                thumbConfidence: 0.39,
                indexTip: nearIndex,
                indexConfidence: 0.9,
                handScale: 0.2,
                at: 0
            ) == .lowConfidence,
            "confidence below 0.4 must be rejected"
        )
        expect(
            detector.update(
                thumbTip: thumb,
                thumbConfidence: 0.4,
                indexTip: farIndex,
                indexConfidence: 0.4,
                handScale: 0.2,
                at: 0
            ) == .open,
            "confidence exactly 0.4 must be accepted"
        )
        expect(
            detector.update(
                thumbTip: thumb,
                thumbConfidence: 0.9,
                indexTip: farIndex,
                indexConfidence: 0.9,
                handScale: 0.2,
                at: 0.21
            ) == .open,
            "open hand must re-arm pinch after 200ms"
        )

        _ = detector.update(
            thumbTip: thumb,
            thumbConfidence: 0.9,
            indexTip: nearIndex,
            indexConfidence: 0.9,
            handScale: 0.2,
            at: 1
        )
        expect(
            detector.update(
                thumbTip: thumb,
                thumbConfidence: 0.9,
                indexTip: nearIndex,
                indexConfidence: 0.9,
                handScale: 0.2,
                at: 1.149
            ) != .pinching,
            "pinch must not activate before 200ms"
        )
        expect(
            detector.update(
                thumbTip: thumb,
                thumbConfidence: 0.9,
                indexTip: nearIndex,
                indexConfidence: 0.9,
                handScale: 0.2,
                at: 1.201
            ) == .pinching,
            "pinch must activate after 200ms"
        )
        expect(
            detector.update(
                thumbTip: thumb,
                thumbConfidence: 0.9,
                indexTip: CGPoint(x: 0.47, y: 0.5),
                indexConfidence: 0.9,
                handScale: 0.2,
                at: 1.22
            ) == .pinching,
            "release hysteresis must keep a near pinch active"
        )
        expect(
            detector.update(
                thumbTip: thumb,
                thumbConfidence: 0.9,
                indexTip: farIndex,
                indexConfidence: 0.9,
                handScale: 0.2,
                at: 1.3
            ) == .pinching,
            "one open frame must not release an active pinch"
        )
        expect(
            detector.update(
                thumbTip: thumb,
                thumbConfidence: 0.9,
                indexTip: farIndex,
                indexConfidence: 0.9,
                handScale: 0.2,
                at: 1.451
            ) == .open,
            "opening the hand for 150ms must release the pinch"
        )
        expect(
            detector.update(
                thumbTip: thumb,
                thumbConfidence: 0.9,
                indexTip: nearIndex,
                indexConfidence: 0.9,
                handScale: 0.2,
                at: 1.31
            ) == .open,
            "pinch must not re-arm until the hand is visibly open"
        )

        print("PinchDetectorTests: all checks passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fatalError(message)
        }
    }
}
