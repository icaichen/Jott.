import AppKit

@MainActor
final class WindowInteractionsInstaller {
    private weak var installedOn: NSWindow?
    private var recognizer: NSClickGestureRecognizer?
    private var onDoubleClick: (() -> Void)?

    func installTitlebarDoubleClick(on window: NSWindow, onDoubleClick: @escaping () -> Void) {
        if installedOn === window { return }
        uninstall()

        installedOn = window
        self.onDoubleClick = onDoubleClick

        let view = titlebarContainerView(for: window)
        let rec = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick))
        rec.numberOfClicksRequired = 2
        rec.buttonMask = 0x1
        view.addGestureRecognizer(rec)
        view.allowedTouchTypes = [.direct, .indirect]
        recognizer = rec
    }

    func uninstall() {
        if let view = recognizer?.view, let recognizer {
            view.removeGestureRecognizer(recognizer)
        }
        recognizer = nil
        installedOn = nil
        onDoubleClick = nil
    }

    @objc private func handleDoubleClick() {
        onDoubleClick?()
    }

    private func titlebarContainerView(for window: NSWindow) -> NSView {
        if let titlebar = window.standardWindowButton(.closeButton)?.superview {
            return titlebar
        }
        // Fallback to the root container view if titlebar is not found
        return window.contentView?.superview ?? window.contentView ?? NSView()
    }
}

