import AppKit
import SwiftUI

struct NoteView: View {
    @EnvironmentObject private var store: JotStore
    @Environment(\.dismiss) private var dismiss

    let noteID: Note.ID

    @State private var entryText: String = ""
    @FocusState private var entryFocused: Bool

    @State private var isCollapsed: Bool = false
    @State private var savedExpandedFrame: CGRect?
    @State private var resolvedWindow: AnyObject?
    @State private var windowInteractions = WindowInteractionsInstaller()
    @State private var headerHeight: CGFloat = 0

    private let parser = QuickAddParser()
    private let dateParser = NaturalLanguageDateParser()

    var body: some View {
        let note = store.note(id: noteID)
        let pinned = note?.isPinned ?? false
        let title = note?.title ?? "Sticky"

        VStack(spacing: 0) {
            header(title: title, pinned: pinned)
            if !isCollapsed {
                blocks(note: note)
            }
        }
        .background(StickyBackground(color: note?.color ?? .yellow))
        .foregroundStyle(Color.black)
        .background(
            WindowAccessor { window in
                resolvedWindow = window
                Task { @MainActor in
                    StickyWindowChrome.apply(to: window)
                    windowInteractions.installTitlebarDoubleClick(on: window) {
                        toggleCollapse()
                    }
                    applyWindowTitle(title)
                }
                applyPinIfNeeded(pinned: pinned)
            }
            .frame(width: 0, height: 0)
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { entryFocused = true }
        }
        .onChange(of: title) { _, newValue in
            applyWindowTitle(newValue)
        }
        .onChange(of: pinned) { _, newValue in
            applyPinIfNeeded(pinned: newValue)
        }
    }

    private func header(title: String, pinned: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
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
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { toggleCollapse() }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private func blocks(note: Note?) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(note?.blocks ?? []) { block in
                    BlockRow(noteID: noteID, block: block)
                        .environmentObject(store)
                }

                NewEntryRow(
                    text: $entryText,
                    focus: $entryFocused,
                    onCommit: submitEntry
                )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
    }

    private func submitEntry() {
        let raw = entryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        defer { entryText = "" }

        switch parser.parse(raw) {
        case .note(let text):
            store.addBlock(to: noteID, block: .note(text))
        case .todo(let text, let dueText):
            let dueAt = dueText.flatMap { dateParser.parse(from: $0)?.date }
            store.addBlock(to: noteID, block: .todo(text, dueAt: dueAt))
        case .checklist(let items):
            store.addChecklist(to: noteID, items: items)
        case .remind(let text, let dueText):
            let dueAt = dueText.flatMap { dateParser.parse(from: $0)?.date }
            store.addReminderTodo(to: noteID, text: text, dueAt: dueAt)
        case .setColor(let color):
            store.setNoteColor(id: noteID, color: color)
        case .togglePin:
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
            entryFocused = true
        }
    }

    private func applyPinIfNeeded(pinned: Bool) {
        guard let window = resolvedWindow as? NSWindow else { return }
        Task { @MainActor in
            window.level = pinned ? .floating : .normal
        }
    }

    private func applyWindowTitle(_ title: String?) {
        guard let window = resolvedWindow as? NSWindow else { return }
        Task { @MainActor in
            window.title = title ?? "Sticky"
        }
    }

    private func toggleCollapse() {
        guard let window = resolvedWindow as? NSWindow else {
            isCollapsed.toggle()
            return
        }

        if isCollapsed {
            isCollapsed = false
            if let savedExpandedFrame {
                window.setFrame(savedExpandedFrame, display: true, animate: true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { entryFocused = true }
        } else {
            savedExpandedFrame = window.frame
            isCollapsed = true

            let currentFrame = window.frame
            let titleBarHeight = currentFrame.height - window.contentLayoutRect.height
            let minHeader = max(ceil(headerHeight), 26)
            let targetHeight = max(titleBarHeight + minHeader, 48)

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
