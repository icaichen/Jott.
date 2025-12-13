import AppKit
import SwiftUI

@main
struct JotApp: App {
    @StateObject private var store = JotStore()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            NotesListView()
                .environmentObject(store)
                .task {
                    await NotificationScheduler.shared.requestAuthorizationIfNeeded()
                }
        }
        .defaultSize(width: 360, height: 520)

        WindowGroup(for: Note.ID.self) { noteID in
            if let id = noteID.wrappedValue, let note = store.note(id: id) {
                NoteView(note: note)
                    .environmentObject(store)
            } else {
                ContentUnavailableView("Note not found", systemImage: "note.text")
                    .padding()
            }
        }
        .defaultSize(width: 360, height: 520)
    }
}
