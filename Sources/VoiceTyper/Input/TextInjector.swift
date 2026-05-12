import AppKit
import Foundation

enum TextInjector {
    static func inject(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let savedItems = snapshot(pasteboard: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        postCmdV()

        // Restore original pasteboard after the paste has been delivered.
        // 150ms is enough for almost every target app; raise if needed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            restore(items: savedItems, into: pasteboard)
        }
    }

    private static func postCmdV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 9 // 'v'
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private static func snapshot(pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }
    }

    private static func restore(items: [[NSPasteboard.PasteboardType: Data]], into pasteboard: NSPasteboard) {
        guard !items.isEmpty else { return }
        pasteboard.clearContents()
        let pbItems = items.map { dict -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in dict {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(pbItems)
    }
}
