import Foundation

/// User-configurable scroll behavior for one physical mouse.
public struct SmoothScrollSettings: Equatable {
    public var enabled = true
    public var deviceName = "mx master"
    public var response = 0.68
    public var speed = 1.0

    public init() {}

    public mutating func applyResponse(_ value: Double) {
        response = value.clamped(to: 0 ... 1)
    }

    public mutating func applySpeed(_ value: Double) {
        speed = value.clamped(to: 0.1 ... 4)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        guard isFinite else {
            return range.lowerBound
        }
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
