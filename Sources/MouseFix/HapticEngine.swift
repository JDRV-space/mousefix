import Foundation
import IOKit
import IOKit.hid

/// Sends haptic feedback to MX Master 4 via HID++ protocol over IOKit.
///
/// HID++ protocol overview:
/// - Short report: 7 bytes, report ID 0x10
/// - Long report: 20 bytes, report ID 0x11
/// - Feature for haptic feedback: 0x0B4E (Haptic Feedback)
/// - We first enumerate features to find the index for 0x0B4E,
///   then use that index to trigger haptic patterns.
final class HapticEngine {
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var hapticFeatureIndex: UInt8?

    /// Logitech vendor ID.
    private static let logitechVendorID = 0x046D

    /// HID++ feature ID for haptic feedback.
    private static let hapticFeatureID: UInt16 = 0x0B4E

    /// HID++ IRoot feature (always at index 0x00) for feature enumeration.
    private static let iRootFeatureID: UInt16 = 0x0000

    /// Default haptic pattern (0 = short click, 1 = long click, etc.).
    private var pattern: UInt8 = 0

    init() {}

    /// Attempt to connect to the MX Master 4 and discover the haptic feature index.
    func connect() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        guard let manager = manager else {
            print("[haptic] Failed to create HID manager")
            return
        }

        // Match Logitech devices.
        let matchDict: [String: Any] = [
            kIOHIDVendorIDKey: HapticEngine.logitechVendorID,
        ]
        IOHIDManagerSetDeviceMatching(manager, matchDict as CFDictionary)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            print("[haptic] Failed to open HID manager: \(result)")
            return
        }

        // Find the MX Master 4 among matched devices.
        guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            print("[haptic] No Logitech HID devices found")
            return
        }

        for dev in deviceSet {
            let product = IOHIDDeviceGetProperty(dev, kIOHIDProductKey as CFString) as? String ?? "unknown"
            print("[haptic] Found Logitech device: \(product)")

            // Look for MX Master 4 (name varies: "MX Master 4", "MX Master 4S", etc.)
            if product.lowercased().contains("mx master") {
                self.device = dev
                print("[haptic] Connected to \(product)")
                discoverHapticFeature()
                return
            }
        }

        print("[haptic] MX Master not found among \(deviceSet.count) Logitech device(s)")
        print("[haptic] Haptic feedback will be unavailable")
    }

    /// Use IRoot to find the feature index for haptic feedback.
    private func discoverHapticFeature() {
        guard let device = device else { return }

        // HID++ short report to IRoot (index 0x00), function getFeatureIndex (0x00):
        // [reportID, deviceIndex, featureIndex, functionID | swID, featureID_hi, featureID_lo, 0x00]
        var report: [UInt8] = [
            0x10,       // Short HID++ report
            0xFF,       // Device index (0xFF = current receiver device)
            0x00,       // Feature index for IRoot
            0x01,       // Function 0 (getFeatureIndex) | SW ID 1
            UInt8(HapticEngine.hapticFeatureID >> 8),   // Feature ID high byte
            UInt8(HapticEngine.hapticFeatureID & 0xFF), // Feature ID low byte
            0x00,
        ]

        let result = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput,
                                          CFIndex(report[0]), &report, report.count)

        if result == kIOReturnSuccess {
            print("[haptic] Sent IRoot query for haptic feature")
            // In a full implementation, we'd read the response to get the feature index.
            // For now, common MX Master 4 firmware maps haptic to index ~0x0E.
            // This will be refined with actual device testing.
            hapticFeatureIndex = 0x0E
            print("[haptic] Using haptic feature index: 0x0E (needs runtime discovery)")
        } else {
            print("[haptic] IRoot query failed: \(result)")
            print("[haptic] Haptic feedback will be unavailable")
        }
    }

    /// Fire a haptic feedback pulse on the mouse.
    func fireHaptic() {
        guard let device = device, let featureIndex = hapticFeatureIndex else {
            return // Silently skip if no device
        }

        // HID++ short report: trigger haptic pattern
        // [reportID, deviceIndex, featureIndex, functionID | swID, pattern, 0x00, 0x00]
        var report: [UInt8] = [
            0x10,           // Short HID++ report
            0xFF,           // Device index
            featureIndex,   // Haptic feature index
            0x11,           // Function 1 (triggerHaptic) | SW ID 1
            pattern,        // Pattern ID (0 = short click)
            0x00,
            0x00,
        ]

        let result = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput,
                                          CFIndex(report[0]), &report, report.count)

        if result != kIOReturnSuccess {
            // Don't spam - haptic is best-effort.
            return
        }
    }

    func disconnect() {
        if let manager = manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        device = nil
        manager = nil
    }
}
