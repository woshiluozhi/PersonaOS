import Foundation

enum PersonaDate {
    static func isSameDay(_ lhs: Date, _ rhs: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    static func relativeDayTitle(_ date: Date, relativeTo referenceDate: Date = Date(), calendar: Calendar = .current) -> String {
        let startOfDate = calendar.startOfDay(for: date)
        let startOfReferenceDate = calendar.startOfDay(for: referenceDate)
        let dayDelta = calendar.dateComponents([.day], from: startOfReferenceDate, to: startOfDate).day ?? 0

        switch dayDelta {
        case 0:
            return "今天"
        case 1:
            return "明天"
        case -1:
            return "昨天"
        case let delta where delta > 1:
            return "\(delta) 天后"
        default:
            return "已过期 \(abs(dayDelta)) 天"
        }
    }

    static func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func displayTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func shortWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.setLocalizedDateFormatFromTemplate("E")
        return formatter.string(from: date)
    }
}
