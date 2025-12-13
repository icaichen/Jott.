import Foundation

struct QuickAddParser {
    enum Result: Equatable {
        case note(text: String)
        case todo(text: String, dueText: String?)
        case checklist(items: [String])
        case remind(text: String, dueText: String?)
        case setColor(NoteColor)
        case togglePin
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

        case "/checklist":
            let rest = parts.dropFirst().joined(separator: " ")
            let items = splitChecklistItems(rest)
            return .checklist(items: items)

        case "/remind":
            if parts.count == 1 { return .remind(text: "Reminder", dueText: nil) }
            if parts.count == 2 { return .remind(text: String(parts[1]), dueText: nil) }
            return .remind(text: String(parts[2]), dueText: String(parts[1]))

        case "/pin":
            return .togglePin

        case "/color":
            let arg = (parts.count >= 2) ? String(parts[1]).lowercased() : ""
            if let color = NoteColor(rawValue: arg) {
                return .setColor(color)
            }
            return .smart(text: trimmed)

        default:
            return .smart(text: trimmed)
        }
    }

    private func splitChecklistItems(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        return trimmed
            .replacingOccurrences(of: "\t", with: " ")
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "；" || $0 == "，" })
            .map(String.init)
    }
}
