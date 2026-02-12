import AppKit
import SwiftUI

struct NoteView: View {
    @EnvironmentObject private var store: JotStore
    @EnvironmentObject private var purchases: PurchaseStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    let noteID: Note.ID

    @State private var entryText: String = ""
    @FocusState private var focusedField: FocusField?

    @State private var isCollapsed: Bool = false
    @State private var savedExpandedFrame: CGRect?
    @State private var resolvedWindow: NSWindow?
    @State private var hasAppliedWindowChrome = false
    @State private var closeDelegate: StickyWindowCloseDelegate?
    @State private var windowInteractions = WindowInteractionsInstaller()
    @State private var headerHeight: CGFloat = 0

    private let parser = QuickAddParser()
    private let dateParser = NaturalLanguageDateParser()

    var body: some View {
        let note = store.note(id: noteID)
        let pinned = note?.isPinned ?? false
        let title = note?.title ?? Note.defaultTitle

        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                header(title: title, pinned: pinned)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        TapGesture(count: 2)
                            .onEnded {
                                toggleCollapse()
                            }
                    )
                
                if !isCollapsed {
                    blocks(note: note)
                }
            }
            .padding(.top, -geometry.safeAreaInsets.top)
        }
        .background(StickyBackground(color: note?.color ?? .yellow))
        .foregroundStyle(Color.black)
        .ignoresSafeArea(.container, edges: .top)
        .background(
            WindowAccessor { window in
                resolvedWindow = window
                Task { @MainActor in
                    if !hasAppliedWindowChrome {
                        StickyWindowChrome.apply(to: window)
                        closeDelegate = StickyWindowCloseDelegate(store: store, noteID: noteID)
                        window.delegate = closeDelegate
                        hasAppliedWindowChrome = true
                    }
                    applyWindowTitle(title)
                }
                applyPinIfNeeded(pinned: pinned)
            }
            .frame(width: 0, height: 0)
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focusedField = .newEntry }
        }
        .onChange(of: title) { _, newValue in
            applyWindowTitle(newValue)
        }
        .onChange(of: pinned) { _, newValue in
            applyPinIfNeeded(pinned: newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: StickyNotifications.titleBarDoubleClick)) { note in
            guard note.object as? NSWindow === resolvedWindow else { return }
            toggleCollapse()
        }
    }

    private func header(title: String, pinned: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                guard purchases.hasPremiumAccess else {
                    purchases.statusMessage = "7-day trial ended. Upgrade to keep using pin and color commands."
                    openWindow(value: PaywallWindow.show)
                    return
                }
                store.togglePinned(id: noteID)
            } label: {
                Image(systemName: pinned ? "pin.fill" : "pin")
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
            .help("Pin (always on top)")

            Button(role: .destructive) {
                store.deleteNotes(ids: [noteID])
                dismiss()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
            .help("Delete sticky")
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: HeaderHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(HeaderHeightKey.self) { newValue in
            if newValue > 0, abs(newValue - headerHeight) > 0.5 {
                headerHeight = newValue
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.12))
                .frame(height: 1)
        }
    }

    private func blocks(note: Note?) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(note?.blocks ?? []) { block in
                    BlockRow(
                        noteID: noteID,
                        block: block,
                        focusedField: $focusedField,
                        onMoveUp: { moveFocusFrom(blockID: block.id, direction: .up) },
                        onMoveDown: { moveFocusFrom(blockID: block.id, direction: .down) }
                    )
                    .environmentObject(store)
                }

                NewEntryRow(
                    text: $entryText,
                    focusedField: $focusedField,
                    onCommit: submitEntry,
                    useCheckboxSpacing: shouldUseCheckboxSpacing(for: entryText),
                    onMoveUp: { moveFocusFromNewEntry(direction: .up) }
                )
            }
            .padding(.horizontal, 12) // Sync with header padding
            .padding(.vertical, 10)
        }
    }

    private func shouldUseCheckboxSpacing(for text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        return trimmed.hasPrefix("/todo") ||
               trimmed.hasPrefix("/checklist") ||
               trimmed.hasPrefix("- [") ||
               trimmed.hasPrefix("-[]") ||
               trimmed.hasPrefix("[ ]") ||
               trimmed.hasPrefix("[]") ||
               trimmed.hasPrefix("- ") ||
               trimmed.hasPrefix("* ") ||
               trimmed.hasPrefix("• ")
    }

    private func submitEntry() {
        let raw = entryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        defer { entryText = "" }

        switch parser.parse(raw) {
        case .note(let text):
            store.addBlock(to: noteID, block: .note(text))
        case .todo(let rawText):
            if let parsed = dateParser.extractDate(from: rawText) {
                let content = parsed.remainder.isEmpty ? "Todo" : parsed.remainder
                store.addBlock(to: noteID, block: .todo(content, dueAt: parsed.date))
            } else {
                store.addBlock(to: noteID, block: .todo(rawText, dueAt: nil))
            }
        case .checklist(let items):
            store.addChecklist(to: noteID, items: items)
        case .setColor(let color):
            guard purchases.hasPremiumAccess else {
                purchases.statusMessage = "7-day trial ended. Upgrade to keep using pin and color commands."
                openWindow(value: PaywallWindow.show)
                return
            }
            store.setNoteColor(id: noteID, color: color)
        case .togglePin:
            guard purchases.hasPremiumAccess else {
                purchases.statusMessage = "7-day trial ended. Upgrade to keep using pin and color commands."
                openWindow(value: PaywallWindow.show)
                return
            }
            store.togglePinned(id: noteID)
        case .setTitle(let title):
            store.renameNote(id: noteID, title: title)
        case .smart(let text):
            if let parsed = dateParser.extractDate(from: text) {
                store.addBlock(to: noteID, block: .todo(parsed.remainder, dueAt: parsed.date))
            } else {
                store.addBlock(to: noteID, block: .note(text))
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focusedField = .newEntry
        }
    }

    private enum NavigationDirection {
        case up, down
    }

    private func moveFocusFrom(blockID: UUID, direction: NavigationDirection) {
        let blocks = store.note(id: noteID)?.blocks ?? []
        guard let currentIndex = blocks.firstIndex(where: { $0.id == blockID }) else { return }

        switch direction {
        case .up:
            if currentIndex > 0 {
                focusedField = .block(blocks[currentIndex - 1].id)
            }
        case .down:
            if currentIndex < blocks.count - 1 {
                focusedField = .block(blocks[currentIndex + 1].id)
            } else {
                focusedField = .newEntry
            }
        }
    }

    private func moveFocusFromNewEntry(direction: NavigationDirection) {
        if direction == .up {
            let blocks = store.note(id: noteID)?.blocks ?? []
            if let lastBlock = blocks.last {
                focusedField = .block(lastBlock.id)
            }
        }
    }

    private func applyPinIfNeeded(pinned: Bool) {
        guard let window = resolvedWindow else { return }
        Task { @MainActor in
            window.level = pinned ? .floating : .normal
        }
    }

    private func applyWindowTitle(_ title: String?) {
        guard let window = resolvedWindow else { return }
        Task { @MainActor in
            window.title = title ?? Note.defaultTitle
        }
    }

    private func toggleCollapse() {
        guard let window = resolvedWindow else {
            isCollapsed.toggle()
            return
        }
    
        if isCollapsed {
            isCollapsed = false
            if let savedExpandedFrame {
                window.setFrame(savedExpandedFrame, display: true, animate: true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focusedField = .newEntry }
        } else {
            savedExpandedFrame = window.frame
            isCollapsed = true
    
            let currentFrame = window.frame
            // With fullSizeContentView, the collapsed height is simply the header height
            let targetHeight = max(ceil(headerHeight), 32)
    
            var newFrame = currentFrame
            newFrame.origin.y += (newFrame.height - targetHeight)
            newFrame.size.height = targetHeight
            window.setFrame(newFrame, display: true, animate: true)
        }
    }
}

private struct StickyBackground: View {
    let color: NoteColor

    var body: some View {
        LinearGradient(
            colors: gradientColors(for: color),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func gradientColors(for color: NoteColor) -> [Color] {
        switch color {
        case .yellow:
            return [Color(red: 1.00, green: 0.96, blue: 0.64), Color(red: 0.98, green: 0.90, blue: 0.45)]
        case .blue:
            return [Color(red: 0.78, green: 0.91, blue: 1.00), Color(red: 0.55, green: 0.78, blue: 0.98)]
        case .pink:
            return [Color(red: 1.00, green: 0.84, blue: 0.91), Color(red: 0.98, green: 0.66, blue: 0.80)]
        case .green:
            return [Color(red: 0.82, green: 0.97, blue: 0.82), Color(red: 0.62, green: 0.89, blue: 0.62)]
        case .red:
            return [Color(red: 1.00, green: 0.78, blue: 0.74), Color(red: 0.98, green: 0.56, blue: 0.51)]
        }
    }
}

private struct HeaderHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
