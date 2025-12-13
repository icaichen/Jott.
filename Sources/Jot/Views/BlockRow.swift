import SwiftUI

struct BlockRow: View {
    @EnvironmentObject private var store: JotStore

    let noteID: Note.ID
    let block: Block

    private static let dueFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private let leadingWidth: CGFloat = 22

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            switch block.kind {
            case .todo:
                Button {
                    var updated = block
                    updated.isDone = !(block.isDone ?? false)
                    store.updateBlock(noteID: noteID, block: updated)
                } label: {
                    Image(systemName: (block.isDone ?? false) ? "checkmark.square.fill" : "square")
                        .foregroundStyle(Color.black)
                        .frame(width: leadingWidth, alignment: .leading)
                        .accessibilityLabel((block.isDone ?? false) ? "Mark as not done" : "Mark as done")
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    TextField(
                        "",
                        text: Binding(
                            get: { block.text },
                            set: { newValue in
                                var updated = block
                                updated.text = newValue
                                store.updateBlock(noteID: noteID, block: updated)
                            }
                        )
                    )
                    .textFieldStyle(.plain)
                    .strikethrough(block.isDone ?? false)
                    .foregroundStyle((block.isDone ?? false) ? Color.black.opacity(0.35) : Color.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onSubmit { deleteIfEmpty() }
                    .onExitCommand(perform: deleteIfEmpty)

                    if let dueAt = block.dueAt {
                        Text(Self.dueFormatter.string(from: dueAt))
                            .font(.caption)
                            .foregroundStyle(Color.black.opacity(0.45))
                    }
                }

            case .note:
                Color.clear
                    .frame(width: leadingWidth, height: 1)

                TextField(
                    "",
                    text: Binding(
                        get: { block.text },
                        set: { newValue in
                            var updated = block
                            updated.text = newValue
                            store.updateBlock(noteID: noteID, block: updated)
                        }
                    )
                )
                .textFieldStyle(.plain)
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onSubmit { deleteIfEmpty() }
                .onExitCommand(perform: deleteIfEmpty)
            }
        }
        .font(.system(size: 20))
        .padding(.vertical, 2)
        .contextMenu {
            Button("Delete") {
                store.deleteBlock(noteID: noteID, blockID: block.id)
            }
        }
    }

    private func deleteIfEmpty() {
        let trimmed = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            store.deleteBlock(noteID: noteID, blockID: block.id)
            return
        }
    }
}
