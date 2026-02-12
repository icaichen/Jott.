import AppKit
import SwiftUI

/// Sentinel value to open the "All Notes" list window (Apple Stickies-style: only via menu).
private enum AllNotesWindow: Int, Codable, Hashable { case show = 0 }
enum PaywallWindow: Int, Codable, Hashable { case show = 0 }
private enum SlashGuideWindow: Int, Codable, Hashable { case show = 0 }

@main
struct JotApp: App {
    @StateObject private var store = JotStore()
    @StateObject private var purchases = PurchaseStore()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        // Launcher: opens one sticky at launch then closes itself (Apple Stickies-style).
        WindowGroup(id: "launcher") {
            LauncherView()
                .environmentObject(store)
                .environmentObject(purchases)
                .frame(width: 1, height: 1)
        }
        .defaultSize(width: 1, height: 1)
        .commands { JotCommands(store: store) }

        WindowGroup(for: Note.ID.self) { noteID in
            if let id = noteID.wrappedValue, let note = store.note(id: id) {
                NoteView(noteID: note.id)
                    .environmentObject(store)
                    .environmentObject(purchases)
            } else {
                NoteNotFoundView()
            }
        }
        .defaultSize(width: 360, height: 520)

        // List: only via "Show All Notes" menu.
        WindowGroup(for: AllNotesWindow.self) { _ in
            NotesListView()
                .environmentObject(store)
                .environmentObject(purchases)
                .task { await NotificationScheduler.shared.requestAuthorizationIfNeeded() }
        }
        .defaultSize(width: 360, height: 520)

        WindowGroup(for: PaywallWindow.self) { _ in
            JotPaywallScreen()
                .environmentObject(purchases)
        }
        .defaultSize(width: 420, height: 260)

        WindowGroup(for: SlashGuideWindow.self) { _ in
            SlashCommandsGuideView()
        }
        .defaultSize(width: 520, height: 420)
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
    @EnvironmentObject private var purchases: PurchaseStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Color.clear
            .task {
                purchases.configureIfNeeded()
                await purchases.refreshAndWait()
                NSApp.activate(ignoringOtherApps: true)
                let id = store.noteIDForLaunch()
                openWindow(value: id)
                // Ensure sticky is visible even if a paywall window also opens.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    openWindow(value: id)
                }
                if !purchases.isProUnlocked {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        openWindow(value: PaywallWindow.show)
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    dismissWindow(id: "launcher")
                }
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

            Button("Upgrade to Pro") {
                openWindow(value: PaywallWindow.show)
            }
        }
        CommandGroup(after: .help) {
            Button("Slash Commands Guide") {
                openWindow(value: SlashGuideWindow.show)
            }
            .keyboardShortcut("/", modifiers: [.command, .shift])
        }
        CommandGroup(after: .toolbar) {
            Button("Bigger") { store.increaseContentFontSize() }
                .keyboardShortcut("+", modifiers: [.command])
            Button("Smaller") { store.decreaseContentFontSize() }
                .keyboardShortcut("-", modifiers: [.command])
        }
    }
}

private struct SlashCommandsGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("How to use slash commands")
                    .font(.title2.bold())
                Text("Type commands in a note input line to quickly structure content.")
                    .foregroundStyle(.secondary)

                commandRow("/todo Buy milk")
                commandRow("/checklist milk, eggs, bread")
                commandRow("/title Weekly Plan")
                commandRow("/pin")
                commandRow("/color yellow|blue|pink|green|red")

                Text("Tips")
                    .font(.headline)
                    .padding(.top, 6)
                Text("• You can still type normal text without slash commands.")
                Text("• Unknown slash text becomes a title shortcut.")
                Text("• Open this guide anytime from Help → Slash Commands Guide.")
            }
            .padding(18)
        }
    }

    private func commandRow(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
