import AppKit
import SwiftUI

@main
struct JotApp: App {
    @StateObject private var store = JotStore()
    @State private var didActivateOnce = false

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            NotesListView()
                .environmentObject(store)
                .task {
                    await NotificationScheduler.shared.requestAuthorizationIfNeeded()
                }
                .task {
                    if !didActivateOnce {
                        didActivateOnce = true
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
        }
        .defaultSize(width: 360, height: 520)
        .commands {
            JotCommands(store: store)
        }

        WindowGroup(for: Note.ID.self) { noteID in
            if let id = noteID.wrappedValue, let note = store.note(id: id) {
                NoteView(noteID: note.id)
                    .environmentObject(store)
            } else {
                ContentUnavailableView("Note not found", systemImage: "note.text")
                    .padding()
            }
        }
        .defaultSize(width: 360, height: 520)
    }
}

private struct JotCommands: Commands {
    @ObservedObject var store: JotStore
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Sticky") {
                let id = store.createNote()
                openWindow(value: id)
            }
            .keyboardShortcut("n", modifiers: [.command])
        }
    }
}
