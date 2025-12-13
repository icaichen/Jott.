import Foundation

struct QuickAddParser {
    enum Result: Equatable {
        case note(text: String)
        case todo(text: String, dueText: String?)
        case smart(text: String)
    }

    func parse(_ raw: String) -> Result {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else {
            return .smart(text: trimmed)
        }

        let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard let command = parts.first?.lowercased() else {
            return .smart(text: trimmed)
        }

        switch command {
        case "/todo":
            if parts.count == 1 { return .todo(text: "Todo", dueText: nil) }
            if parts.count == 2 { return .todo(text: String(parts[1]), dueText: nil) }
            return .todo(text: String(parts[2]), dueText: String(parts[1]))

        case "/note", "/notes":
            if parts.count == 1 { return .note(text: "") }
            return .note(text: parts.dropFirst().joined(separator: " "))

        default:
            return .smart(text: trimmed)
        }
    }
}

