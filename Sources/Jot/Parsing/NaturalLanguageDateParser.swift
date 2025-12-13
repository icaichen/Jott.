import Foundation

struct NaturalLanguageDateParser {
    struct Extraction: Equatable {
        var date: Date
        var remainder: String
    }

    private let calendar = Calendar.current

    func parse(from text: String) -> Extraction? {
        extractDate(from: text)
    }

    func extractDate(from text: String) -> Extraction? {
        let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return nil }

        if let detectorDate = detectDate(original) {
            return Extraction(date: detectorDate.date, remainder: original.replacingOccurrences(of: detectorDate.matchedText, with: "").trimmedSpaces())
        }

        return parseChineseRelative(original)
    }

    private func detectDate(_ text: String) -> (date: Date, matchedText: String)? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = detector.firstMatch(in: text, options: [], range: range),
              let date = match.date,
              let r = Range(match.range, in: text)
        else { return nil }
        return (date, String(text[r]))
    }

    private func parseChineseRelative(_ text: String) -> Extraction? {
        var working = text

        let now = Date()
        var base = calendar.startOfDay(for: now)

        var dayOffset = 0
        var defaultHour: Int? = nil
        var meridiem: Meridiem? = nil

        func consume(_ s: String) {
            working = working.replacingOccurrences(of: s, with: "")
        }

        if working.contains("后天") { dayOffset = 2; consume("后天") }
        else if working.contains("明天") { dayOffset = 1; consume("明天") }
        else if working.contains("明早") { dayOffset = 1; defaultHour = 9; consume("明早") }
        else if working.contains("今晚") { dayOffset = 0; defaultHour = 20; consume("今晚") }
        else if working.contains("今天") { dayOffset = 0; consume("今天") }

        if working.contains("上午") { meridiem = .am; consume("上午") }
        if working.contains("早上") { meridiem = .am; consume("早上") }
        if working.contains("凌晨") { meridiem = .am; consume("凌晨") }
        if working.contains("中午") { meridiem = .noon; consume("中午") }
        if working.contains("下午") { meridiem = .pm; consume("下午") }
        if working.contains("晚上") { meridiem = .pm; consume("晚上") }

        if dayOffset != 0 {
            base = calendar.date(byAdding: .day, value: dayOffset, to: base) ?? base
        }

        if let time = parseTime(in: working) {
            consume(time.matchedText)
            let hour = adjust(hour: time.hour, meridiem: meridiem)
            let minute = time.minute
            let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
            return Extraction(date: normalizeFuture(date, now: now), remainder: working.trimmedSpaces())
        }

        if let defaultHour {
            let date = calendar.date(bySettingHour: defaultHour, minute: 0, second: 0, of: base) ?? base
            return Extraction(date: normalizeFuture(date, now: now), remainder: working.trimmedSpaces())
        }

        return nil
    }

    private func normalizeFuture(_ date: Date, now: Date) -> Date {
        if date < now, let bumped = calendar.date(byAdding: .day, value: 1, to: date) {
            return bumped
        }
        return date
    }

    private enum Meridiem {
        case am
        case noon
        case pm
    }

    private func adjust(hour: Int, meridiem: Meridiem?) -> Int {
        guard let meridiem else { return hour }
        switch meridiem {
        case .am:
            return hour == 12 ? 0 : hour
        case .noon:
            return hour == 12 ? 12 : min(max(hour, 11), 13)
        case .pm:
            if hour == 12 { return 12 }
            return min(hour + 12, 23)
        }
    }

    private func parseTime(in text: String) -> (hour: Int, minute: Int, matchedText: String)? {
        let pattern = #"([0-9]{1,2}|[零一二三四五六七八九十]{1,3})点(?:(半)|([0-5]?[0-9])分?)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 2,
              let matchedRange = Range(match.range(at: 0), in: text),
              let hourRange = Range(match.range(at: 1), in: text)
        else { return nil }

        let hourToken = String(text[hourRange])
        let hour = parseNumberToken(hourToken)
        if !(0...23).contains(hour) { return nil }

        var minute = 0
        if match.range(at: 2).location != NSNotFound {
            minute = 30
        } else if match.range(at: 3).location != NSNotFound, let minuteRange = Range(match.range(at: 3), in: text) {
            minute = Int(text[minuteRange]) ?? 0
        }

        return (hour, minute, String(text[matchedRange]))
    }

    private func parseNumberToken(_ token: String) -> Int {
        if let value = Int(token) { return value }
        return ChineseNumerals.parse(token) ?? 0
    }
}

private enum ChineseNumerals {
    static func parse(_ s: String) -> Int? {
        let map: [Character: Int] = [
            "零": 0, "一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9,
        ]

        let chars = Array(s)
        if chars.isEmpty { return nil }

        if chars.count == 1, let v = map[chars[0]] { return v }
        if s == "十" { return 10 }

        if s.hasPrefix("十") {
            let onesChar = chars.count >= 2 ? chars[1] : nil
            let ones = onesChar.flatMap { map[$0] } ?? 0
            return 10 + ones
        }

        if let tenIndex = chars.firstIndex(of: "十") {
            let tensChar = chars[tenIndex - 1]
            let tens = map[tensChar] ?? 0
            let onesChar = tenIndex + 1 < chars.count ? chars[tenIndex + 1] : nil
            let ones = onesChar.flatMap { map[$0] } ?? 0
            return tens * 10 + ones
        }

        if chars.count == 2, let a = map[chars[0]], let b = map[chars[1]] {
            return a * 10 + b
        }

        return nil
    }
}

private extension String {
    func trimmedSpaces() -> String {
        replacingOccurrences(of: #"[\s]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

