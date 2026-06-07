import Foundation

struct AISuggestionSanitizer {
    func clean(_ item: String) -> String {
        item
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func cleanedUniqueItems(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.compactMap { item in
            let cleaned = clean(item)
            guard !cleaned.isEmpty else {
                return nil
            }

            let key = normalizedKey(cleaned)
            guard !seen.contains(key) else {
                return nil
            }

            seen.insert(key)
            return cleaned
        }
    }

    func riskTitle(for rawValue: String) -> String {
        let cleanedValue = clean(rawValue)
        guard !cleanedValue.isEmpty else {
            return "未知风险"
        }

        switch cleanedValue.lowercased() {
        case "scope_creep":
            return "范围膨胀：新项目会分散主线火力。"
        case "unfinished_main_quest":
            return "主线未闭环：先交付可验证结果。"
        case "overdue_tasks":
            return "逾期任务：先清理一个真实阻塞。"
        default:
            return cleanedValue
        }
    }

    func normalizedKey(_ item: String) -> String {
        clean(item)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
