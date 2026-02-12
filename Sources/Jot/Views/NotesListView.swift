import SwiftUI

struct NotesListView: View {
    @EnvironmentObject private var store: JotStore
    @EnvironmentObject private var purchases: PurchaseStore
    @Environment(\.openWindow) private var openWindow

    @State private var selection: Set<Note.ID> = []

    var body: some View {
        NavigationStack {
            Group {
                if store.notesInList.isEmpty {
                    ContentUnavailableView {
                        Label("No saved notes", systemImage: "tray")
                    } description: {
                        Text("Close a sticky and choose **Save** to add it here.")
                    }
                } else {
                    List(store.notesInList, selection: $selection) { note in
                        HStack(spacing: 10) {
                            Image(systemName: "note.text")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.title)
                                    .lineLimit(1)
                                Text(note.createdAt, format: .dateTime.day().month().year())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            openWindow(value: note.id)
                        }
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
                }
            }
            .navigationTitle("Jott - Sticky Notes")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    if !purchases.isProUnlocked {
                        Button("Upgrade") {
                            purchases.configureIfNeeded()
                            purchases.refresh()
                            openWindow(value: PaywallWindow.show)
                        }
                    }
                }
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
    }
}
