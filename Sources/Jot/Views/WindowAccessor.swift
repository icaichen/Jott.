import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    var onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            onResolve(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Intentionally no-op: resolve window only once in makeNSView to keep the app light
        // (title/pin updates use resolvedWindow or lookup by identifier)
    }
}

enum StickyNotifications {
    static let titleBarDoubleClick = Notification.Name("StickyTitleBarDoubleClick")
}

/// 覆盖在系统标题栏上的透明视图，拦截双击并发送通知，阻止系统“双击标题栏最小化”。
private final class TitleBarDoubleClickOverlay: NSView {
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2, let window = window {
            NotificationCenter.default.post(name: StickyNotifications.titleBarDoubleClick, object: window)
        }
        // 不调用 super，消费事件，系统就不会执行最小化
    }
}

enum StickyWindowChrome {
    private static let titleBarOverlayHeight: CGFloat = 52

    /// 自定义标题栏：隐藏红黄绿，标题区透明；双击标题区触发折叠，不最小化。
    @MainActor
    static func apply(to window: NSWindow) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].forEach { type in
            window.standardWindowButton(type)?.isHidden = true
        }
        if let titlebar = window.standardWindowButton(.closeButton)?.superview {
            titlebar.alphaValue = 0
        }
        installTitleBarDoubleClickOverlay(on: window)
    }

    @MainActor
    private static func installTitleBarDoubleClickOverlay(on window: NSWindow) {
        guard let themeFrame = window.contentView?.superview else { return }
        let overlay = TitleBarDoubleClickOverlay()
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor.clear.cgColor
        overlay.autoresizingMask = [.minYMargin, .width]
        themeFrame.addSubview(overlay, positioned: .above, relativeTo: nil)
        let bounds = themeFrame.bounds
        overlay.frame = CGRect(x: 0, y: bounds.height - Self.titleBarOverlayHeight, width: bounds.width, height: Self.titleBarOverlayHeight)
    }
}

/// Handles sticky window close: empty → delete and close; has content → Save / Delete / Cancel.
final class StickyWindowCloseDelegate: NSObject, NSWindowDelegate {
    private weak var store: JotStore?
    private let noteID: Note.ID

    init(store: JotStore, noteID: Note.ID) {
        self.store = store
        self.noteID = noteID
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let store = store else { return true }
        guard let note = store.note(id: noteID) else { return true }
        let hasContent = !note.blocks.isEmpty || note.title != Note.defaultTitle

        if !hasContent {
            store.deleteNotes(ids: [noteID])
            return true
        }

        let alert = NSAlert()
        alert.messageText = "Save or delete this note?"
        alert.informativeText = "The note has content."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[2].keyEquivalent = "\u{1B}"

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn: // Save
            store.setNoteInList(id: noteID, inList: true)
            return true
        case .alertSecondButtonReturn: // Delete
            store.deleteNotes(ids: [noteID])
            return true
        default: // Cancel
            return false
        }
    }

    /// 禁止“双击标题栏”触发的系统放大（zoom），只保留我们自己的折叠/展开（与 Apple Stickies 一致）。
    func windowShouldZoom(_ sender: NSWindow, toFrame frame: NSRect) -> Bool { false }
}
