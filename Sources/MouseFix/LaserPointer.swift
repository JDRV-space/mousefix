import AppKit
import CoreGraphics
import Foundation

/// Draws a colored circle overlay that follows the mouse cursor.
/// Activated by holding the scroll button (below-scroll on MX Master 4).
final class LaserPointer {
    private var window: NSWindow?
    private(set) var isVisible = false

    /// Circle diameter in points.
    private let diameter: CGFloat = 60
    /// Circle color.
    private let color = NSColor(red: 1.0, green: 0.2, blue: 0.1, alpha: 0.45)

    init() {}

    /// Create the overlay window. Must be called after NSApplication is running.
    func setup() {
        let frame = NSRect(x: 0, y: 0, width: diameter, height: diameter)

        let window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.hasShadow = false

        // Draw the circle.
        let circleView = CircleView(frame: frame, color: color)
        window.contentView = circleView

        self.window = window
    }

    func show() {
        guard let window = window else { return }
        isVisible = true

        // Position at current mouse location.
        let pos = NSEvent.mouseLocation
        centerWindow(at: pos)
        window.orderFront(nil)
    }

    func hide() {
        isVisible = false
        window?.orderOut(nil)
    }

    func updatePosition(event: CGEvent) {
        guard isVisible else { return }
        // CGEvent location is in top-left origin; NSWindow uses bottom-left.
        let cgPoint = event.location
        guard let screen = NSScreen.main else { return }
        let flippedY = screen.frame.height - cgPoint.y
        centerWindow(at: NSPoint(x: cgPoint.x, y: flippedY))
    }

    private func centerWindow(at point: NSPoint) {
        let half = diameter / 2
        window?.setFrameOrigin(NSPoint(x: point.x - half, y: point.y - half))
    }
}

// MARK: - Circle View

private class CircleView: NSView {
    private let color: NSColor

    init(frame: NSRect, color: NSColor) {
        self.color = color
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        let path = NSBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2))
        path.fill()

        // Bright border
        NSColor(red: 1.0, green: 0.3, blue: 0.1, alpha: 0.8).setStroke()
        path.lineWidth = 2
        path.stroke()
    }
}
