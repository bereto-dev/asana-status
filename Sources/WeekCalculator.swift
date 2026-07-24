import Foundation

enum WeekCalculator {
    private static func calendar(firstWeekday: Int) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        cal.firstWeekday = firstWeekday
        return cal
    }

    static func startOfWeek(firstWeekday: Int, for date: Date = Date()) -> Date {
        let cal = calendar(firstWeekday: firstWeekday)
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps)!
    }

    static func dateOnlyString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: date)
    }

    static func isoDateTimeUTC(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }

    /// Days elapsed so far this week (including today), capped at 5 — used as a proxy for
    /// "work days" regardless of which day the week starts on.
    static func elapsedWorkdays(firstWeekday: Int, from weekStart: Date, to now: Date = Date()) -> Int {
        let cal = calendar(firstWeekday: firstWeekday)
        let days = cal.dateComponents([.day], from: weekStart, to: now).day ?? 0
        return min(max(days, 0) + 1, 5)
    }
}
