import Foundation

enum ChatHistoryRoleFilter: String, CaseIterable, Identifiable {
    case all
    case user
    case assistant
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .user:
            return "我"
        case .assistant:
            return "药老"
        case .system:
            return "系统"
        }
    }
}

struct ChatHistoryService {
    func cleanOutgoingContent(_ content: String) -> String {
        cleanedMessageContent(content)
    }

    func displayContent(for message: ChatMessage) -> String {
        cleanedMessageContent(message.content)
    }

    func sortedMessages(_ messages: [ChatMessage]) -> [ChatMessage] {
        messages
            .filter { !displayContent(for: $0).isEmpty }
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    func isUserMessage(_ message: ChatMessage) -> Bool {
        normalizedRole(message.role) == ChatRole.user.rawValue
    }

    func senderTitle(
        for message: ChatMessage,
        userName: String? = nil,
        companionName: String? = nil
    ) -> String {
        switch ChatRole(rawValue: normalizedRole(message.role)) {
        case .user:
            return displayName(userName, fallback: "智")
        case .assistant:
            return displayName(companionName, fallback: "药老")
        case .system:
            return "系统"
        case .none:
            let cleanedRole = cleanedMessageContent(message.role)
            return cleanedRole.isEmpty ? "未知" : cleanedRole
        }
    }

    func filterMessages(
        _ messages: [ChatMessage],
        roleFilter: ChatHistoryRoleFilter = .all,
        searchText: String = "",
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [ChatMessage] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchTerms = trimmedSearch
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        return sortedMessages(messages).filter { message in
            guard matchesRole(message, roleFilter: roleFilter) else {
                return false
            }

            guard !searchTerms.isEmpty else {
                return true
            }

            let dateTitle = PersonaDate.displayDate(message.createdAt)
            let timeTitle = PersonaDate.displayTime(message.createdAt)
            let relativeDayTitle = PersonaDate.relativeDayTitle(
                message.createdAt,
                relativeTo: referenceDate,
                calendar: calendar
            )
            let searchableFields = [
                displayContent(for: message),
                message.role,
                roleTitle(for: message),
                dateTitle,
                timeTitle,
                relativeDayTitle
            ]

            return searchTerms.allSatisfy { term in
                searchableFields.contains { $0.localizedCaseInsensitiveContains(term) }
            }
        }
    }

    private func matchesRole(_ message: ChatMessage, roleFilter: ChatHistoryRoleFilter) -> Bool {
        switch roleFilter {
        case .all:
            return true
        case .user:
            return normalizedRole(message.role) == ChatRole.user.rawValue
        case .assistant:
            return normalizedRole(message.role) == ChatRole.assistant.rawValue
        case .system:
            return normalizedRole(message.role) == ChatRole.system.rawValue
        }
    }

    private func roleTitle(for message: ChatMessage) -> String {
        switch ChatRole(rawValue: normalizedRole(message.role)) {
        case .user:
            return "我"
        case .assistant:
            return "药老"
        case .system:
            return "系统"
        case .none:
            return cleanedMessageContent(message.role)
        }
    }

    private func normalizedRole(_ role: String) -> String {
        cleanedMessageContent(role).lowercased()
    }

    private func displayName(_ name: String?, fallback: String) -> String {
        let cleanedName = cleanedMessageContent(name ?? "")
        return cleanedName.isEmpty ? fallback : cleanedName
    }

    private func cleanedMessageContent(_ content: String) -> String {
        content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
