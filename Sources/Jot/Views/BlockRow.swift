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

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            switch block.kind {
            case .todo:
                Toggle(isOn: Binding(
                    get: { block.isDone ?? false },
                    set: { newValue in
                        var updated = block
                        updated.isDone = newValue
                        store.updateBlock(noteID: noteID, block: updated)
                    }
                )) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(block.text)
                            .strikethrough(block.isDone ?? false)
                            .foregroundStyle((block.isDone ?? false) ? .secondary : .primary)

                        if let dueAt = block.dueAt {
                            Text(Self.dueFormatter.string(from: dueAt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .toggleStyle(.checkbox)

            case .note:
                Text(block.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                store.deleteBlock(noteID: noteID, blockID: block.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete block")
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

