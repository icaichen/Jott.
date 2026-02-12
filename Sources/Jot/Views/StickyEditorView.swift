import SwiftUI
import AppKit

struct StickyEditorView: View {
    @EnvironmentObject private var store: JotStore
    @Environment(\.dismiss) private var dismiss

    let noteID: Note.ID

    @State private var editorText: String = ""
    @State private var hasAppliedWindowChrome = false
    @FocusState private var focusedField: FocusField?

    private let parser = QuickAddParser()
    private let dateParser = NaturalLanguageDateParser()

    var body: some View {
        let note = store.note(id: noteID)
        let pinned = note?.isPinned ?? false
        let title = note?.title ?? Note.defaultTitle

        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                header(title: title, pinned: pinned)

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
                            .id(block.id)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)

                    SimpleTextEditor(text: $editorText, focusedField: $focusedField, onEnterPressed: handleEnterPressed, fontSize: store.contentFontSize)
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }
            }
            .padding(.top, -geometry.safeAreaInsets.top)
        }
        .background(StickyBackground(color: note?.color ?? .yellow))
        .foregroundStyle(Color.black)
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 250, minHeight: 200)
        .background(
            WindowAccessor { window in
                Task { @MainActor in
                    if !hasAppliedWindowChrome {
                        StickyWindowChrome.apply(to: window)
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
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { 
            // The editor doesn't have its own toggleCollapse, 
            // but we want consistency. This view is mainly for the primary sticky window.
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.12))
                .frame(height: 1)
        }
    }

    private func applyPinIfNeeded(pinned: Bool) {
        guard let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "sticky-\(noteID)" }) else { return }
        Task { @MainActor in
            window.level = pinned ? .floating : .normal
        }
    }

    private func applyWindowTitle(_ title: String?) {
        guard let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "sticky-\(noteID)" }) else { return }
        Task { @MainActor in
            window.title = title ?? Note.defaultTitle
        }
    }

    private func handleEnterPressed(_ content: String) {
        let raw = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        // 解析 slash 命令
        if raw.hasPrefix("/") {
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
                store.setNoteColor(id: noteID, color: color)
            case .togglePin:
                store.togglePinned(id: noteID)
            case .setTitle(let title):
                store.renameNote(id: noteID, title: title)
            case .smart(let text):
                store.addBlock(to: noteID, block: .note(text))
            }
        } else {
            // 普通文本直接作为 note
            store.addBlock(to: noteID, block: .note(raw))
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
}

struct SimpleTextEditor: NSViewRepresentable {
    @Binding var text: String
    var focusedField: FocusState<FocusField?>.Binding
    var onEnterPressed: (String) -> Void
    var fontSize: CGFloat = 20

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.font = NSFont.systemFont(ofSize: fontSize)
        textView.textColor = .black
        textView.backgroundColor = .clear
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false

        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true

        textView.enclosingScrollView?.borderType = .noBorder
        textView.enclosingScrollView?.drawsBackground = false
        textView.enclosingScrollView?.hasVerticalScroller = false
        textView.enclosingScrollView?.hasHorizontalScroller = false
        textView.enclosingScrollView?.autohidesScrollers = true

        textView.textContainerInset = CGSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0

        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        if nsView.string != text {
            let selectedRange = nsView.selectedRange
            nsView.string = text
            nsView.setSelectedRange(selectedRange)
        }
        if nsView.font?.pointSize != fontSize {
            nsView.font = NSFont.systemFont(ofSize: fontSize)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SimpleTextEditor
        private var isProcessingChange = false

        init(_ parent: SimpleTextEditor) {
            self.parent = parent
        }

        @MainActor
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  !isProcessingChange else { return }

            let newText = textView.string
            let currentText = parent.text

            if newText != currentText && newText.contains("\n") {
                isProcessingChange = true
                processNewline(textView: textView, currentText: currentText)
                isProcessingChange = false
            } else if newText != currentText {
                parent.text = newText
            }
        }

        @MainActor
        private func processNewline(textView: NSTextView, currentText: String) {
            let newText = textView.string
            guard let newlineIndex = newText.firstIndex(of: "\n") else { return }

            let currentLine = String(newText[..<newlineIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let remainingText = String(newText[newlineIndex...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !currentLine.isEmpty {
                parent.onEnterPressed(currentLine)
            }

            parent.text = remainingText
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
