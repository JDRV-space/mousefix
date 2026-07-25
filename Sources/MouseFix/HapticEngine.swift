import Foundation

/// Reserved interface for future MX Master haptic support.
///
/// Haptic output stays disabled until the device's feature index is discovered
/// from a verified runtime response. Sending reports to a guessed feature
/// index can invoke an unrelated command on another firmware revision.
final class HapticEngine {
    func fireHaptic() {}
    func disconnect() {}
}
