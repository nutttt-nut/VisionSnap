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
    let maximumDistanceRatio: CGFloat
    let releaseDistanceRatio: CGFloat
    let holdDuration: TimeInterval
    let releaseDuration: TimeInterval
    let rearmDuration: TimeInterval

    private var candidateStartedAt: TimeInterval?
    private var releaseStartedAt: TimeInterval?
    private var isPinching = false
    private var openStartedAt: TimeInterval?
    private var isArmed = false
    private var trackingLostAt: TimeInterval?
    private(set) var diagnosticConfidence: Float = 0
    private(set) var diagnosticHoldMilliseconds = 0

    init(
        minimumConfidence: Float = 0.4,
        maximumDistanceRatio: CGFloat = 0.28,
        releaseDistanceRatio: CGFloat = 0.36,
        holdDuration: TimeInterval = 0.2,
        releaseDuration: TimeInterval = 0.15,
        rearmDuration: TimeInterval = 0.2
    ) {
        self.minimumConfidence = minimumConfidence
        self.maximumDistanceRatio = maximumDistanceRatio
        self.releaseDistanceRatio = releaseDistanceRatio
        self.holdDuration = holdDuration
        self.releaseDuration = releaseDuration
        self.rearmDuration = rearmDuration
    }

    mutating func update(
        thumbTip: CGPoint?,
        thumbConfidence: Float,
        indexTip: CGPoint?,
        indexConfidence: Float,
        handScale: CGFloat?,
        at timestamp: TimeInterval
    ) -> PinchPhase {
        diagnosticConfidence = min(thumbConfidence, indexConfidence)
        diagnosticHoldMilliseconds = 0

        guard let thumbTip, let indexTip, let handScale, handScale > 0 else {
            candidateStartedAt = nil
            releaseStartedAt = nil
            if isPinching {
                let lostAt = trackingLostAt ?? timestamp
                trackingLostAt = lostAt
                if timestamp - lostAt >= 0.3 {
                    isPinching = false
                    isArmed = false
                }
            } else {
                openStartedAt = nil
                isArmed = false
            }
            return .noHand
        }

        guard thumbConfidence >= minimumConfidence,
              indexConfidence >= minimumConfidence else {
            candidateStartedAt = nil
            releaseStartedAt = nil
            if isPinching {
                let lostAt = trackingLostAt ?? timestamp
                trackingLostAt = lostAt
                if timestamp - lostAt >= 0.3 {
                    isPinching = false
                    isArmed = false
                }
            } else {
                openStartedAt = nil
                isArmed = false
            }
            return .lowConfidence
        }
        trackingLostAt = nil

        let distanceRatio = hypot(thumbTip.x - indexTip.x, thumbTip.y - indexTip.y) / handScale
        if isPinching {
            diagnosticHoldMilliseconds = Int((holdDuration * 1_000).rounded())
            if distanceRatio <= releaseDistanceRatio {
                releaseStartedAt = nil
                return .pinching
            }
            let startedAt = releaseStartedAt ?? timestamp
            releaseStartedAt = startedAt
            guard timestamp - startedAt >= releaseDuration else {
                return .pinching
            }
            candidateStartedAt = nil
            releaseStartedAt = nil
            isPinching = false
            isArmed = false
            openStartedAt = timestamp
            return .open
        }

        guard distanceRatio <= maximumDistanceRatio else {
            candidateStartedAt = nil
            let startedAt = openStartedAt ?? timestamp
            openStartedAt = startedAt
            if timestamp - startedAt >= rearmDuration {
                isArmed = true
            }
            return .open
        }
        guard isArmed else {
            openStartedAt = nil
            return .open
        }
        openStartedAt = nil

        let startedAt = candidateStartedAt ?? timestamp
        candidateStartedAt = startedAt
        let elapsed = max(0, timestamp - startedAt)
        diagnosticHoldMilliseconds = Int((elapsed * 1_000).rounded())

        if elapsed >= holdDuration {
            isPinching = true
            return .pinching
        }

        return .candidate(progress: min(1, elapsed / holdDuration))
    }

    mutating func reset() {
        candidateStartedAt = nil
        releaseStartedAt = nil
        isPinching = false
        openStartedAt = nil
        isArmed = false
        trackingLostAt = nil
        diagnosticConfidence = 0
        diagnosticHoldMilliseconds = 0
    }
}
