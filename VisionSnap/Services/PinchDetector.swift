import CoreGraphics
import Foundation

enum PinchPhase: Equatable {
    case noHand
    case lowConfidence
    case open
    case candidate(progress: Double)
    case pinching
}

struct PinchDetector {
    let minimumConfidence: Float
    let maximumDistance: CGFloat
    let holdDuration: TimeInterval

    private var candidateStartedAt: TimeInterval?

    init(
        minimumConfidence: Float = 0.6,
        maximumDistance: CGFloat = 0.08,
        holdDuration: TimeInterval = 0.15
    ) {
        self.minimumConfidence = minimumConfidence
        self.maximumDistance = maximumDistance
        self.holdDuration = holdDuration
    }

    mutating func update(
        thumbTip: CGPoint?,
        thumbConfidence: Float,
        indexTip: CGPoint?,
        indexConfidence: Float,
        at timestamp: TimeInterval
    ) -> PinchPhase {
        guard let thumbTip, let indexTip else {
            candidateStartedAt = nil
            return .noHand
        }

        guard thumbConfidence >= minimumConfidence,
              indexConfidence >= minimumConfidence else {
            candidateStartedAt = nil
            return .lowConfidence
        }

        let distance = hypot(thumbTip.x - indexTip.x, thumbTip.y - indexTip.y)
        guard distance <= maximumDistance else {
            candidateStartedAt = nil
            return .open
        }

        let startedAt = candidateStartedAt ?? timestamp
        candidateStartedAt = startedAt
        let elapsed = max(0, timestamp - startedAt)

        if elapsed >= holdDuration {
            return .pinching
        }

        return .candidate(progress: min(1, elapsed / holdDuration))
    }

    mutating func reset() {
        candidateStartedAt = nil
    }
}
