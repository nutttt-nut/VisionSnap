import CoreGraphics
import Vision

struct HandPoseAnalysis {
    let extendedFingerCount: Int?
    let palmCenter: CGPoint?
    let isFist: Bool
    let isIndexPointing: Bool
}

enum HandPoseAnalyzer {
    static func analyze(
        _ points: [VNHumanHandPoseObservation.JointName: CGPoint]
    ) -> HandPoseAnalysis {
        guard let wrist = points[.wrist], let middleMCP = points[.middleMCP] else {
            return HandPoseAnalysis(
                extendedFingerCount: nil,
                palmCenter: nil,
                isFist: false,
                isIndexPointing: false
            )
        }
        let palmScale = distance(middleMCP, wrist)
        let fingerJoints: [(VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName)] = [
            (.thumbTip, .thumbIP),
            (.indexTip, .indexPIP),
            (.middleTip, .middlePIP),
            (.ringTip, .ringPIP),
            (.littleTip, .littlePIP),
        ]

        var tipDistances: [CGFloat] = []
        var extendedFingers: Set<VNHumanHandPoseObservation.JointName> = []
        for (tipName, innerName) in fingerJoints {
            guard let tip = points[tipName], let inner = points[innerName] else {
                return HandPoseAnalysis(
                    extendedFingerCount: nil,
                    palmCenter: palmCenter(from: points),
                    isFist: false,
                    isIndexPointing: false
                )
            }
            let tipDistance = distance(tip, wrist)
            tipDistances.append(tipDistance)
            if tipDistance > distance(inner, wrist) + palmScale * 0.15 {
                extendedFingers.insert(tipName)
            }
        }

        return HandPoseAnalysis(
            extendedFingerCount: extendedFingers.count,
            palmCenter: palmCenter(from: points),
            isFist: tipDistances.allSatisfy { $0 < palmScale * 1.7 },
            isIndexPointing: extendedFingers.contains(.indexTip)
                && extendedFingers.isSubset(of: [.thumbTip, .indexTip])
        )
    }

    private static func palmCenter(
        from points: [VNHumanHandPoseObservation.JointName: CGPoint]
    ) -> CGPoint? {
        let names: [VNHumanHandPoseObservation.JointName] = [
            .wrist, .indexMCP, .middleMCP, .ringMCP, .littleMCP,
        ]
        let palmPoints = names.compactMap { points[$0] }
        guard palmPoints.count == names.count else { return nil }
        let total = palmPoints.reduce(CGPoint.zero) {
            CGPoint(x: $0.x + $1.x, y: $0.y + $1.y)
        }
        return CGPoint(
            x: total.x / CGFloat(palmPoints.count),
            y: total.y / CGFloat(palmPoints.count)
        )
    }

    private static func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }
}

enum GazeEstimator {
    static func signal(
        leftEye: [CGPoint],
        leftPupil: CGPoint,
        rightEye: [CGPoint],
        rightPupil: CGPoint,
        yaw: CGFloat,
        pitch: CGFloat
    ) -> CGPoint? {
        guard let leftOffset = normalizedPupilOffset(eye: leftEye, pupil: leftPupil),
              let rightOffset = normalizedPupilOffset(eye: rightEye, pupil: rightPupil) else {
            return nil
        }
        let pupilOffset = CGPoint(
            x: (leftOffset.x + rightOffset.x) / 2,
            y: (leftOffset.y + rightOffset.y) / 2
        )
        return CGPoint(
            x: pupilOffset.x + yaw * 0.15,
            y: pupilOffset.y + pitch * 0.15
        )
    }

    private static func normalizedPupilOffset(
        eye: [CGPoint],
        pupil: CGPoint
    ) -> CGPoint? {
        guard !eye.isEmpty else { return nil }
        let center = eye.reduce(CGPoint.zero) {
            CGPoint(x: $0.x + $1.x, y: $0.y + $1.y)
        }
        let eyeCenter = CGPoint(
            x: center.x / CGFloat(eye.count),
            y: center.y / CGFloat(eye.count)
        )
        let width = (eye.map(\.x).max() ?? 0) - (eye.map(\.x).min() ?? 0)
        let height = (eye.map(\.y).max() ?? 0) - (eye.map(\.y).min() ?? 0)
        guard width > 0, height > 0 else { return nil }
        return CGPoint(
            x: (pupil.x - eyeCenter.x) / width,
            y: (pupil.y - eyeCenter.y) / height
        )
    }
}

struct GazeCalibrator {
    let requiredSamples: Int
    let horizontalGain: CGFloat
    let verticalGain: CGFloat

    private var samples: [CGPoint] = []
    private var baseline: CGPoint?
    private var recentSignals: [CGPoint] = []

    init(
        requiredSamples: Int = 12,
        horizontalGain: CGFloat = 1.6,
        verticalGain: CGFloat = 2.0
    ) {
        self.requiredSamples = requiredSamples
        self.horizontalGain = horizontalGain
        self.verticalGain = verticalGain
    }

    mutating func update(signal: CGPoint) -> CGPoint? {
        if baseline == nil {
            samples.append(signal)
            guard samples.count >= requiredSamples else { return nil }
            let total = samples.reduce(CGPoint.zero) {
                CGPoint(x: $0.x + $1.x, y: $0.y + $1.y)
            }
            baseline = CGPoint(
                x: total.x / CGFloat(samples.count),
                y: total.y / CGFloat(samples.count)
            )
            samples.removeAll(keepingCapacity: false)
        }
        guard let baseline else { return nil }
        recentSignals.append(signal)
        if recentSignals.count > 5 {
            recentSignals.removeFirst()
        }
        let filtered = CGPoint(
            x: median(recentSignals.map(\.x)),
            y: median(recentSignals.map(\.y))
        )
        return CGPoint(
            x: clamp(0.5 + (filtered.x - baseline.x) * horizontalGain),
            y: clamp(0.5 + (filtered.y - baseline.y) * verticalGain)
        )
    }

    mutating func reset() {
        samples.removeAll(keepingCapacity: false)
        recentSignals.removeAll(keepingCapacity: false)
        baseline = nil
    }

    private func median(_ values: [CGFloat]) -> CGFloat {
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}
