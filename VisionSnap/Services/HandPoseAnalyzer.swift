import CoreGraphics
import Vision

struct HandPoseAnalysis {
    let extendedFingerCount: Int?
    let palmCenter: CGPoint?
    let isFist: Bool
}

enum HandPoseAnalyzer {
    static func analyze(
        _ points: [VNHumanHandPoseObservation.JointName: CGPoint]
    ) -> HandPoseAnalysis {
        guard let wrist = points[.wrist], let middleMCP = points[.middleMCP] else {
            return HandPoseAnalysis(extendedFingerCount: nil, palmCenter: nil, isFist: false)
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
        var extendedFingerCount = 0
        for (tipName, innerName) in fingerJoints {
            guard let tip = points[tipName], let inner = points[innerName] else {
                return HandPoseAnalysis(
                    extendedFingerCount: nil,
                    palmCenter: palmCenter(from: points),
                    isFist: false
                )
            }
            let tipDistance = distance(tip, wrist)
            tipDistances.append(tipDistance)
            if tipDistance > distance(inner, wrist) + palmScale * 0.15 {
                extendedFingerCount += 1
            }
        }

        return HandPoseAnalysis(
            extendedFingerCount: extendedFingerCount,
            palmCenter: palmCenter(from: points),
            isFist: tipDistances.allSatisfy { $0 < palmScale * 1.7 }
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
