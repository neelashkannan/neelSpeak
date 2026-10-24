import AppKit
import Foundation

/// Which modifier key starts dictation while held.
enum HotkeyTrigger: String, CaseIterable, Identifiable {
    case rightOption
    case leftOption
    case eitherOption

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rightOption: return "Right Option"
        case .leftOption: return "Left Option"
        case .eitherOption: return "Either Option"
        }
    }

    /// Short label for key caps, e.g. "Right ⌥".
    var keyCapLabel: String {
        switch self {
        case .rightOption: return "Right ⌥"
        case .leftOption: return "Left ⌥"
        case .eitherOption: return "⌥"
        }
    }

    fileprivate var keyCodes: Set<Int64> {
        switch self {
        case .rightOption: return [HotkeyManager.rightOptionKeyCode]
        case .leftOption: return [HotkeyManager.leftOptionKeyCode]
        case .eitherOption: return [HotkeyManager.leftOptionKeyCode, HotkeyManager.rightOptionKeyCode]
        }
    }

    /// Device-dependent modifier bits (NX_DEVICELALTKEYMASK / NX_DEVICERALTKEYMASK)
    /// that tell the two Option keys apart.
    fileprivate var deviceFlagMask: UInt64 {
        switch self {
        case .rightOption: return 0x40
        case .leftOption: return 0x20
        case .eitherOption: return 0x60
        }
    }
}

/// Watches the global keyboard for the hold-to-dictate key.
///
/// A hold only counts as dictation when the trigger key is pressed on its own:
/// pressing any other key or modifier while it is held (⌥←, ⌥⌘…) cancels it, so
/// ordinary Option shortcuts never paste anything. Escape also cancels.
final class HotkeyManager {
    enum Event { case pressed, released, cancelled }

    fileprivate static let leftOptionKeyCode: Int64 = 58
    fileprivate static let rightOptionKeyCode: Int64 = 61

    /// Command, Control, Shift and Fn — anything other than Option.
    private static let otherModifierMask: UInt64 =
        CGEventFlags.maskCommand.rawValue
        | CGEventFlags.maskControl.rawValue
        | CGEventFlags.maskShift.rawValue
        | CGEventFlags.maskSecondaryFn.rawValue

    var onEvent: ((Event) -> Void)?
    var trigger: HotkeyTrigger = .rightOption {
        didSet {
            if trigger != oldValue { reset() }
        }
    }

    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    private enum Phase { case idle, holding, cancelled }
    private var phase: Phase = .idle

    func start() {
        guard eventTap == nil, globalMonitor == nil, localMonitor == nil else { return }

        startSessionEventTap()

        // The NSEvent monitors back up the event tap. Both may deliver the same
        // keystroke; the phase machine below makes duplicates harmless.
        let handler: (NSEvent) -> Void = { [weak self] event in
            self?.handle(nsEvent: event)
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { event in
            handler(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { event in
            handler(event)
            return event
        }
    }

    func stop() {
        if let source = eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            eventTapSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        reset()
    }

    private func reset() {
        if phase == .holding { onEvent?(.cancelled) }
        phase = .idle
    }

    private func startSessionEventTap() {
        let eventMask = (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
            | (CGEventMask(1) << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                manager.handle(cgType: type, cgEvent: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else { return }
        eventTap = tap
        eventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(nsEvent event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            dispatch { $0.handleFlagsChanged(keyCode: Int64(event.keyCode), flags: UInt64(event.modifierFlags.rawValue)) }
        case .keyDown:
            dispatch { $0.handleKeyDown(keyCode: Int64(event.keyCode)) }
        default:
            break
        }
    }

    private func handle(cgType type: CGEventType, cgEvent event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags.rawValue
        switch type {
        case .flagsChanged:
            dispatch { $0.handleFlagsChanged(keyCode: keyCode, flags: flags) }
        case .keyDown:
            dispatch { $0.handleKeyDown(keyCode: keyCode) }
        default:
            break
        }
    }

    private func dispatch(_ work: @escaping (HotkeyManager) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            work(self)
        }
    }

    // MARK: - Phase machine (main thread)

    private func handleFlagsChanged(keyCode: Int64, flags: UInt64) {
        let triggerDown = flags & trigger.deviceFlagMask != 0
        let otherModifiersDown = flags & Self.otherModifierMask != 0

        switch phase {
        case .idle:
            guard trigger.keyCodes.contains(keyCode), triggerDown, !otherModifiersDown else { return }
            phase = .holding
            onEvent?(.pressed)
        case .holding:
            if !triggerDown {
                phase = .idle
                onEvent?(.released)
            } else if otherModifiersDown {
                phase = .cancelled
                onEvent?(.cancelled)
            }
        case .cancelled:
            if !triggerDown { phase = .idle }
        }
    }

    /// Any key pressed during a hold cancels it: Escape on purpose, anything
    /// else because the hold has turned into an Option shortcut.
    private func handleKeyDown(keyCode: Int64) {
        guard phase == .holding else { return }
        phase = .cancelled
        onEvent?(.cancelled)
    }
}
