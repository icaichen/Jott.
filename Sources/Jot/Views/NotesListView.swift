import SwiftUI
import AppKit

struct NotesListView: View {
    @EnvironmentObject private var store: JotStore
    @Environment(\.openWindow) private var openWindow

    @State private var selection: Set<Note.ID> = []

    var body: some View {
        NavigationStack {
            List(store.notes, selection: $selection) { note in
                Button {
                    openWindow(value: note.id)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "note.text")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(note.title)
                                .lineLimit(1)
                            Text(note.updatedAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Open") { openWindow(value: note.id) }
                    Button("New Sticky") {
                        let id = store.createNote()
                        openWindow(value: id)
                    }
                    Divider()
                    Button("Delete", role: .destructive) { store.deleteNotes(ids: [note.id]) }
                }
            }
            .navigationTitle("Jot")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let id = store.createNote()
                        openWindow(value: id)
                    } label: {
                        Label("New Sticky", systemImage: "plus")
                    }
                }
            }
        }
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
