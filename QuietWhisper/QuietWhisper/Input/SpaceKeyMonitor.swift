import AppKit

/// Hold-space-to-talk. Mirrors the prototype's behavior in qw-app.jsx
/// (lines 116–146): listen for keyDown/keyUp on space, ignore key repeats,
/// ignore typing targets, and consume the event when we act on it.
@MainActor
final class SpaceKeyMonitor {
    private let onPressDown: () -> Void
    private let onReleaseUp: () -> Void
    private let isEnabled: () -> Bool

    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var held: Bool = false

    private static let spaceKeyCode: UInt16 = 49

    init(onPressDown: @escaping () -> Void,
         onReleaseUp: @escaping () -> Void,
         isEnabled: @escaping () -> Bool) {
        self.onPressDown = onPressDown
        self.onReleaseUp = onReleaseUp
        self.isEnabled = isEnabled
    }

    func start() {
        guard keyDownMonitor == nil, keyUpMonitor == nil else { return }

        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyDown(event)
        }

        keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyUp(event)
        }
    }

    func stop() {
        if let m = keyDownMonitor { NSEvent.removeMonitor(m) }
        if let m = keyUpMonitor { NSEvent.removeMonitor(m) }
        keyDownMonitor = nil
        keyUpMonitor = nil
        held = false
    }

    // MARK: - Handlers

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard event.keyCode == Self.spaceKeyCode else { return event }
        // Holding space repeats keyDown — only the first one starts a take.
        if event.isARepeat { return nil }
        guard isEnabled() else { return event }
        if isTypingResponder() { return event }

        held = true
        onPressDown()
        return nil // consume — don't insert a literal space anywhere
    }

    private func handleKeyUp(_ event: NSEvent) -> NSEvent? {
        guard event.keyCode == Self.spaceKeyCode else { return event }
        if isEnabled() && held {
            held = false
            onReleaseUp()
            return nil
        }
        held = false
        return event
    }

    /// Returns true when the focused responder is a text editor — in which
    /// case the user is typing and space must not be hijacked.
    private func isTypingResponder() -> Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        if responder is NSText || responder is NSTextView || responder is NSTextField {
            return true
        }
        // Field editors and embedded text views show up as descendants of an
        // NSText; walk the responder chain up a few hops to catch them.
        var current: NSResponder? = responder
        var hops = 0
        while let r = current, hops < 6 {
            if r is NSText || r is NSTextView || r is NSTextField { return true }
            current = r.nextResponder
            hops += 1
        }
        return false
    }
}
