import SwiftUI

struct NoteView: View {
    @EnvironmentObject private var store: JotStore
    @Environment(\.dismiss) private var dismiss

    let note: Note

    @State private var title: String = ""
    @State private var quickAddText: String = ""
    @FocusState private var quickAddFocused: Bool

    private let parser = QuickAddParser()
    private let dateParser = NaturalLanguageDateParser()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            blocks
            Divider()
            quickAdd
        }
        .background(StickyBackground())
        .onAppear {
            title = note.title
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                quickAddFocused = true
            }
        }
        .onChange(of: title) { _, newValue in
            store.renameNote(id: note.id, title: newValue)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            TextField("Title", text: $title)
                .textFieldStyle(.plain)
                .font(.headline)

            Spacer(minLength: 8)

            Button(role: .destructive) {
                store.deleteNotes(ids: [note.id])
                dismiss()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete sticky")
        }
        .padding(12)
    }

    private var blocks: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if note.blocks.isEmpty {
                    ContentUnavailableView("Type /todo or /note", systemImage: "slash.circle")
                        .padding(.vertical, 20)
                }
                ForEach(note.blocks) { block in
                    BlockRow(noteID: note.id, block: block)
                        .environmentObject(store)
                }
            }
            .padding(12)
        }
    }

    private var quickAdd: some View {
        HStack(spacing: 10) {
            TextField("Quick add (e.g. 明早七点叫外卖, /todo 明早七点 叫外卖)", text: $quickAddText)
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
            store.addBlock(to: note.id, block: .note(text))
        case .todo(let text, let dueText):
            let dueAt = dueText.flatMap { dateParser.parse(from: $0)?.date }
            store.addBlock(to: note.id, block: .todo(text, dueAt: dueAt))
        case .smart(let text):
            if let parsed = dateParser.extractDate(from: text) {
                store.addBlock(to: note.id, block: .todo(parsed.remainder, dueAt: parsed.date))
            } else {
                store.addBlock(to: note.id, block: .note(text))
            }
        }
    }
}

private struct StickyBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.96, blue: 0.64),
                Color(red: 0.98, green: 0.90, blue: 0.45),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
