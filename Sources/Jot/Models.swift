import Foundation

enum FocusField: Hashable {
    case block(UUID)
    case newEntry
}

enum NoteColor: String, Codable, CaseIterable, Hashable {
    case yellow
    case blue
    case pink
    case green
    case red
}

struct Note: Identifiable, Codable, Hashable {
    static let defaultTitle = "Untitled"

    var id: UUID = UUID()
    var title: String = Note.defaultTitle
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var blocks: [Block] = []
    var color: NoteColor = .yellow
    var isPinned: Bool = false
    /// 是否在「收纳」列表中显示；仅关闭时选 Save 的便签为 true。
    var isInList: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, title, createdAt, updatedAt, blocks, color, isPinned, isInList
    }

    init(id: UUID = UUID(), title: String = Note.defaultTitle, createdAt: Date = Date(), updatedAt: Date = Date(), blocks: [Block] = [], color: NoteColor = .yellow, isPinned: Bool = false, isInList: Bool = false) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.blocks = blocks
        self.color = color
        self.isPinned = isPinned
        self.isInList = isInList
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        blocks = try c.decode([Block].self, forKey: .blocks)
        color = try c.decode(NoteColor.self, forKey: .color)
        isPinned = try c.decode(Bool.self, forKey: .isPinned)
        isInList = try c.decodeIfPresent(Bool.self, forKey: .isInList) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(blocks, forKey: .blocks)
        try c.encode(color, forKey: .color)
        try c.encode(isPinned, forKey: .isPinned)
        try c.encode(isInList, forKey: .isInList)
    }
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
