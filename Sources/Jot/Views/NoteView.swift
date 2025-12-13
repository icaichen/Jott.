import AppKit
import SwiftUI

struct NoteView: View {
    @EnvironmentObject private var store: JotStore
    @Environment(\.dismiss) private var dismiss

    let noteID: Note.ID

    @State private var quickAddText: String = ""
    @FocusState private var quickAddFocused: Bool

    @State private var isCollapsed: Bool = false
    @State private var savedExpandedFrame: CGRect?
    @State private var headerHeight: CGFloat = 0
    @State private var resolvedWindow: AnyObject?

    private let parser = QuickAddParser()
    private let dateParser = NaturalLanguageDateParser()

    var body: some View {
        let note = store.note(id: noteID)
        let pinned = note?.isPinned ?? false

        VStack(spacing: 0) {
            header(note: note)
            if !isCollapsed {
                Divider()
                blocks(note: note)
                Divider()
                quickAdd(note: note)
            }
        }
        .background(StickyBackground(color: note?.color ?? .yellow))
        .background(
            WindowAccessor { window in
                Task { @MainActor in
                    StickyWindowChrome.apply(to: window)
                }
                resolvedWindow = window
                applyPinIfNeeded(pinned: pinned)
            }
            .frame(width: 0, height: 0)
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                quickAddFocused = true
            }
        }
        .onChange(of: pinned) { _, newValue in
            applyPinIfNeeded(pinned: newValue)
        }
    }

    private func header(note: Note?) -> some View {
        HStack(spacing: 10) {
            TextField("Title", text: Binding(
                get: { note?.title ?? "" },
                set: { store.renameNote(id: noteID, title: $0) }
            ))
                .textFieldStyle(.plain)
                .font(.headline)

            Spacer(minLength: 8)

            Button {
                store.togglePinned(id: noteID)
            } label: {
                Image(systemName: (note?.isPinned ?? false) ? "pin.fill" : "pin")
            }
            .buttonStyle(.borderless)
            .help("Pin (always on top)")

            Button(role: .destructive) {
                store.deleteNotes(ids: [noteID])
                dismiss()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
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
        .onTapGesture(count: 2) {
            toggleCollapse()
        }
        .padding(12)
    }

    private func blocks(note: Note?) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if (note?.blocks ?? []).isEmpty {
                    ContentUnavailableView("Try /todo, /checklist, /remind, /color, /pin", systemImage: "slash.circle")
                        .padding(.vertical, 20)
                }
                ForEach(note?.blocks ?? []) { block in
                    BlockRow(noteID: noteID, block: block)
                        .environmentObject(store)
                }
            }
            .padding(12)
        }
    }

    private func quickAdd(note: Note?) -> some View {
        HStack(spacing: 10) {
            TextField("Quick add (e.g. 明早七点叫外卖, /checklist 牛奶,鸡蛋,面包, /remind 明早七点 叫外卖)", text: $quickAddText)
                .textFieldStyle(.plain)
                .focused($quickAddFocused)
                .onSubmit(addFromQuickInput)

            Button("Add") { addFromQuickInput() }
                .keyboardShortcut(.return, modifiers: [])
        }
        .padding(12)
    }

    private func addFromQuickInput() {
        let raw = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        defer { quickAddText = "" }

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
        case .smart(let text):
            if let parsed = dateParser.extractDate(from: text) {
                store.addBlock(to: noteID, block: .todo(parsed.remainder, dueAt: parsed.date))
            } else {
                store.addBlock(to: noteID, block: .note(text))
            }
        }
    }

    private func applyPinIfNeeded(pinned: Bool) {
        guard let window = resolvedWindow as? NSWindow else { return }
        Task { @MainActor in
            window.level = pinned ? .floating : .normal
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                quickAddFocused = true
            }
        } else {
            savedExpandedFrame = window.frame
            isCollapsed = true

            let minContentHeight = max(ceil(headerHeight + 8), 52)
            let currentFrame = window.frame
            let titleBarHeight = currentFrame.height - window.contentLayoutRect.height
            let targetHeight = minContentHeight + titleBarHeight

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
        }
    }
}

private struct HeaderHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
