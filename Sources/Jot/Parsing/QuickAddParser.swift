import Foundation

struct QuickAddParser {
    enum Result: Equatable {
        case note(text: String)
        case todo(rawText: String)
        case checklist(items: [String])
        case setColor(NoteColor)
        case togglePin
        case setTitle(String)
        case smart(text: String)
    }

    func parse(_ raw: String) -> Result {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else {
            return .smart(text: trimmed)
        }

        if trimmed.lowercased().hasPrefix("/checklist") {
            let remainder = String(trimmed.dropFirst("/checklist".count))
            return .checklist(items: splitChecklistItems(remainder))
        }

        if trimmed.lowercased().hasPrefix("/title") {
            let remainder = String(trimmed.dropFirst("/title".count))
            let title = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty { return .setTitle(title) }
            return .smart(text: trimmed)
        }

        let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard let command = parts.first?.lowercased() else {
            return .smart(text: trimmed)
        }

        switch command {
        case "/todo":
            let remainder = parts.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            return .todo(rawText: remainder.isEmpty ? "Todo" : remainder)

        case "/checklist":
            let rest = parts.dropFirst().joined(separator: " ")
            let items = splitChecklistItems(rest)
            return .checklist(items: items)

        case "/pin":
            return .togglePin

        case "/color":
            let arg = (parts.count >= 2) ? String(parts[1]).lowercased() : ""
            if let color = NoteColor(rawValue: arg) {
                return .setColor(color)
            }
            return .smart(text: trimmed)

        default:
            if parts.count == 1, trimmed.count > 1 {
                let title = String(trimmed.dropFirst())
                if !title.isEmpty {
                    return .setTitle(title)
                }
            }
            return .smart(text: trimmed)
        }
    }

    private func splitChecklistItems(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }

        let normalized = trimmed
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let rawItems = normalized
            .split(whereSeparator: { $0 == "\n" || $0 == "," || $0 == ";" || $0 == "；" || $0 == "，" })
            .map(String.init)

        return rawItems
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map(stripChecklistPrefix)
            .filter { !$0.isEmpty }
    }

    private func stripChecklistPrefix(_ s: String) -> String {
        var out = s
        let prefixes = ["- [ ]", "- []", "[ ]", "[]", "-", "*", "•"]
        for p in prefixes {
            if out.hasPrefix(p) {
                out = out.dropPrefix(p).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        return out
    }
}

private extension String {
    func dropPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }
}
