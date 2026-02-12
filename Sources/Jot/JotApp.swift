import AppKit
import SwiftUI

/// Sentinel value to open the "All Notes" list window (Apple Stickies-style: only via menu).
private enum AllNotesWindow: Int, Codable, Hashable { case show = 0 }

@main
struct JotApp: App {
    @StateObject private var store = JotStore()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        // Launcher: opens one sticky at launch then closes itself (Apple Stickies-style).
        WindowGroup(id: "launcher") {
            LauncherView()
                .environmentObject(store)
                .frame(width: 1, height: 1)
        }
        .defaultSize(width: 1, height: 1)
        .commands { JotCommands(store: store) }

        WindowGroup(for: Note.ID.self) { noteID in
            if let id = noteID.wrappedValue, let note = store.note(id: id) {
                NoteView(noteID: note.id)
                    .environmentObject(store)
            } else {
                NoteNotFoundView()
            }
        }
        .defaultSize(width: 360, height: 520)

        // List: only via "Show All Notes" menu.
        WindowGroup(for: AllNotesWindow.self) { _ in
            NotesListView()
                .environmentObject(store)
                .task { await NotificationScheduler.shared.requestAuthorizationIfNeeded() }
        }
        .defaultSize(width: 360, height: 520)
    }
}

/// Shown when a sticky window is opened for a note that no longer exists (e.g. restored session). Auto-closes so user only sees stickies or the list.
private struct NoteNotFoundView: View {
    @State private var window: NSWindow?

    var body: some View {
        ContentUnavailableView("Note not found", systemImage: "note.text")
            .padding()
            .background(WindowAccessor { window = $0 }.frame(width: 0, height: 0))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    window?.close()
                }
            }
    }
}

private struct LauncherView: View {
    @EnvironmentObject private var store: JotStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Color.clear
            .task {
                NSApp.activate(ignoringOtherApps: true)
                let id = store.createNote()
                openWindow(value: id)
                dismissWindow(id: "launcher")
            }
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

            Button("Save All") {
                store.saveNow()
            }
            .keyboardShortcut("s", modifiers: [.command])
        }
        CommandGroup(after: .windowList) {
            Button("Show All Notes") {
                openWindow(value: AllNotesWindow.show)
            }
            .keyboardShortcut("l", modifiers: [.command])
        }
        CommandGroup(after: .toolbar) {
            Button("Bigger") { store.increaseContentFontSize() }
                .keyboardShortcut("+", modifiers: [.command])
            Button("Smaller") { store.decreaseContentFontSize() }
                .keyboardShortcut("-", modifiers: [.command])
        }
    }
}
