import Combine
import Foundation

private let contentFontSizeKey = "jot.contentFontSize"
private let defaultContentFontSize: CGFloat = 20
private let minContentFontSize: CGFloat = 12
private let maxContentFontSize: CGFloat = 32

@MainActor
final class JotStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published var contentFontSize: CGFloat = defaultContentFontSize {
        didSet {
            let clamped = min(max(contentFontSize, minContentFontSize), maxContentFontSize)
            if clamped != contentFontSize { contentFontSize = clamped; return }
            UserDefaults.standard.set(Double(contentFontSize), forKey: contentFontSizeKey)
        }
    }

    private var saveTask: Task<Void, Never>?
    private let persistence = Persistence()
    private let notifications = NotificationScheduler.shared

    init() {
        notes = (try? persistence.load()) ?? [Note(title: "Sticky", blocks: [])]
        normalize()
        if let s = UserDefaults.standard.object(forKey: contentFontSizeKey) as? Double {
            contentFontSize = min(max(CGFloat(s), minContentFontSize), maxContentFontSize)
        }
    }

    func increaseContentFontSize() {
        contentFontSize = min(contentFontSize + 2, maxContentFontSize)
    }

    func decreaseContentFontSize() {
        contentFontSize = max(contentFontSize - 2, minContentFontSize)
    }

    func note(id: Note.ID) -> Note? {
        notes.first(where: { $0.id == id })
    }

    func createNote() -> Note.ID {
        var note = Note()
        note.title = "Sticky \(notes.count + 1)"
        notes.insert(note, at: 0)
        scheduleSave()
        return note.id
    }

    func deleteNotes(ids: Set<Note.ID>) {
        notes.removeAll { ids.contains($0.id) }
        if notes.isEmpty { notes = [Note(title: "Sticky", blocks: [])] }
        scheduleSave()
    }

    func renameNote(id: Note.ID, title: String) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Sticky" : title
        notes[idx].updatedAt = Date()
        scheduleSave()
    }

    func setNoteColor(id: Note.ID, color: NoteColor) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].color = color
        notes[idx].updatedAt = Date()
        scheduleSave()
    }

    func togglePinned(id: Note.ID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].isPinned.toggle()
        notes[idx].updatedAt = Date()
        scheduleSave()
    }

    func addBlock(to noteID: Note.ID, block: Block) {
        guard let idx = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[idx].blocks.append(block)
        notes[idx].updatedAt = Date()
        scheduleSave()

        scheduleNotificationsIfNeeded(note: notes[idx], block: block)
    }

    func addChecklist(to noteID: Note.ID, items: [String]) {
        for item in items {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            addBlock(to: noteID, block: .todo(trimmed, dueAt: nil))
        }
    }

    func updateBlock(noteID: Note.ID, block: Block) {
        guard let idx = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[idx].blocks.replace(id: block.id, with: block)
        notes[idx].updatedAt = Date()
        scheduleSave()

        scheduleNotificationsIfNeeded(note: notes[idx], block: block)
    }

    func deleteBlock(noteID: Note.ID, blockID: Block.ID) {
        guard let idx = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[idx].blocks.removeAll { $0.id == blockID }
        notes[idx].updatedAt = Date()
        scheduleSave()

        Task { await notifications.cancelTodo(id: blockID) }
    }

    func saveNow() {
        saveTask?.cancel()
        let snapshot = notes
        try? (persistence as Persistence).save(snapshot)
    }

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [persistence] in
            try? await Task.sleep(for: .milliseconds(250))
            let snapshot = notes
            try? persistence.save(snapshot)
        }
    }

    private func normalize() {
        notes.sort { $0.updatedAt > $1.updatedAt }
        scheduleSave()
    }

    private func scheduleNotificationsIfNeeded(note: Note, block: Block) {
        guard block.kind == .todo else { return }

        if (block.isDone ?? false) || block.dueAt == nil {
            Task { await notifications.cancelTodo(id: block.id) }
            return
        }

        guard let dueAt = block.dueAt else { return }
        Task { await notifications.scheduleTodo(id: block.id, noteTitle: note.title, text: block.text, dueAt: dueAt) }
    }
}

struct Persistence {
    private let fileManager = FileManager.default

    func load() throws -> [Note] {
        let url = try fileURL()
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Note].self, from: data)
    }

    func save(_ notes: [Note]) throws {
        let url = try fileURL()
        let folder = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(notes)
        try data.write(to: url, options: [.atomic])
    }

    private func fileURL() throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent("Jot", isDirectory: true).appendingPathComponent("notes.json")
    }
}
