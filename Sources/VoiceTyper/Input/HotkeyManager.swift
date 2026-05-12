import AppKit
import Foundation

final class HotkeyManager {
    enum Event { case pressed, released }

    // Left Option = 58, Right Option = 61.
    private let triggerKeyCodes: Set<Int64> = [58, 61]
    private let cancelKeyCode: Int64 = 53

    var onEvent: ((Event) -> Void)?

    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isPressed = false

    func start() {
        guard eventTap == nil, globalMonitor == nil, localMonitor == nil else { return }

        startSessionEventTap()

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
        isPressed = false
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
            handleModifierChange(
                keyCode: Int64(event.keyCode),
                optionIsDown: event.modifierFlags.contains(.option)
            )
        case .keyDown:
            handleKeyDown(keyCode: Int64(event.keyCode))
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
        switch type {
        case .flagsChanged:
            handleModifierChange(keyCode: keyCode, optionIsDown: event.flags.contains(.maskAlternate))
        case .keyDown:
            handleKeyDown(keyCode: keyCode)
        default:
            break
        }
    }

    private func handleModifierChange(keyCode: Int64, optionIsDown: Bool) {
        guard triggerKeyCodes.contains(keyCode) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.setPressed(optionIsDown)
        }
    }

    private func handleKeyDown(keyCode: Int64) {
        guard keyCode == cancelKeyCode else { return }
        DispatchQueue.main.async { [weak self] in
            self?.setPressed(false)
        }
    }

    private func setPressed(_ pressed: Bool) {
        guard pressed != isPressed else { return }
        isPressed = pressed
        onEvent?(pressed ? .pressed : .released)
    }
}
