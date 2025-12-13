import Foundation

enum NoteColor: String, Codable, CaseIterable, Hashable {
    case yellow
    case blue
    case pink
    case green
}

struct Note: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String = "Sticky"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var blocks: [Block] = []
    var color: NoteColor = .yellow
    var isPinned: Bool = false
}

struct Block: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case note
        case todo
    }

    var id: UUID = UUID()
    var kind: Kind

    var text: String
    var isDone: Bool? = nil
    var dueAt: Date? = nil
    var reminderID: String? = nil

    static func note(_ text: String) -> Block {
        Block(kind: .note, text: text, isDone: nil, dueAt: nil)
    }

    static func todo(_ text: String, dueAt: Date?) -> Block {
        Block(kind: .todo, text: text, isDone: false, dueAt: dueAt)
    }

    static func reminderTodo(_ text: String, dueAt: Date?) -> Block {
        Block(kind: .todo, text: text, isDone: false, dueAt: dueAt, reminderID: nil)
    }
}

extension Array where Element == Block {
    mutating func replace(id: Block.ID, with newValue: Block) {
        guard let idx = firstIndex(where: { $0.id == id }) else { return }
        self[idx] = newValue
    }
}
