import Foundation
import SwiftData

private func cleanedPersonaText(_ text: String) -> String {
    text
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

enum QuestType: String, CaseIterable, Identifiable {
    case main
    case side
    case daily

    var id: String { rawValue }

    var title: String {
        switch self {
        case .main:
            return "主线"
        case .side:
            return "支线"
        case .daily:
            return "每日"
        }
    }
}

enum QuestStatus: String, CaseIterable, Identifiable {
    case active
    case completed
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active:
            return "进行中"
        case .completed:
            return "已完成"
        case .archived:
            return "已归档"
        }
    }
}

enum ChatRole: String, CaseIterable, Identifiable {
    case user
    case assistant
    case system

    var id: String { rawValue }
}

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var level: Int
    var currentXP: Int
    var energy: Int
    var focus: Int
    var stress: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "智",
        level: Int = 1,
        currentXP: Int = 0,
        energy: Int = 70,
        focus: Int = 65,
        stress: Int = 35,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.level = level
        self.currentXP = currentXP
        self.energy = energy
        self.focus = focus
        self.stress = stress
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func normalizeEditableFields(now: Date = Date()) {
        let cleanedName = cleanedPersonaText(name)
        name = cleanedName.isEmpty ? "智" : cleanedName
        energy = min(max(energy, 0), 100)
        focus = min(max(focus, 0), 100)
        stress = min(max(stress, 0), 100)
        updatedAt = now
    }
}

@Model
final class CompanionPersona {
    var id: UUID
    var name: String
    var styleDescription: String
    var voiceStyle: String
    var strictnessLevel: Int
    var warmthLevel: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "药老",
        styleDescription: String = "冷静、直接、长期主义，不盲目迎合",
        voiceStyle: String = "沉稳、简洁",
        strictnessLevel: Int = 8,
        warmthLevel: Int = 5,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.styleDescription = styleDescription
        self.voiceStyle = voiceStyle
        self.strictnessLevel = strictnessLevel
        self.warmthLevel = warmthLevel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func normalizeEditableFields(now: Date = Date()) {
        let cleanedName = cleanedPersonaText(name)
        let cleanedStyle = cleanedPersonaText(styleDescription)
        let cleanedVoice = cleanedPersonaText(voiceStyle)

        name = cleanedName.isEmpty ? "药老" : cleanedName
        styleDescription = cleanedStyle.isEmpty ? "冷静、直接、长期主义，不盲目迎合" : cleanedStyle
        voiceStyle = cleanedVoice.isEmpty ? "沉稳、简洁" : cleanedVoice
        strictnessLevel = min(max(strictnessLevel, 0), 10)
        warmthLevel = min(max(warmthLevel, 0), 10)
        updatedAt = now
    }
}

@Model
final class Quest {
    var id: UUID
    var title: String
    var detail: String
    var questType: String
    var status: String
    var priority: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        detail: String = "",
        questType: String = QuestType.main.rawValue,
        status: String = QuestStatus.active.rawValue,
        priority: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.questType = questType
        self.status = status
        self.priority = priority
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var detail: String
    var taskType: String
    var questId: UUID?
    var isCompleted: Bool
    var xpReward: Int
    var dueDate: Date?
    var createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        detail: String = "",
        taskType: String = QuestType.daily.rawValue,
        questId: UUID? = nil,
        isCompleted: Bool = false,
        xpReward: Int = 20,
        dueDate: Date? = Date(),
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.taskType = taskType
        self.questId = questId
        self.isCompleted = isCompleted
        self.xpReward = xpReward
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

@Model
final class MemoryRecord {
    var id: UUID
    var content: String
    var source: String
    var tagsText: String
    var importance: Int
    var confidence: Double
    var sensitivityLevel: Int
    var isUserConfirmed: Bool
    var isDismissed: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        content: String,
        source: String = "manual",
        tagsText: String = "",
        importance: Int = 5,
        confidence: Double = 0.7,
        sensitivityLevel: Int = 1,
        isUserConfirmed: Bool = true,
        isDismissed: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.source = source
        self.tagsText = tagsText
        self.importance = importance
        self.confidence = confidence
        self.sensitivityLevel = sensitivityLevel
        self.isUserConfirmed = isUserConfirmed
        self.isDismissed = isDismissed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class DailyReport {
    var id: UUID
    var date: Date
    var completedTaskCount: Int
    var totalTaskCount: Int
    var xpGained: Int
    var summary: String
    var companionComment: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        completedTaskCount: Int = 0,
        totalTaskCount: Int = 0,
        xpGained: Int = 0,
        summary: String = "",
        companionComment: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.completedTaskCount = completedTaskCount
        self.totalTaskCount = totalTaskCount
        self.xpGained = xpGained
        self.summary = summary
        self.companionComment = companionComment
        self.createdAt = createdAt
    }
}

@Model
final class ChatMessage {
    var id: UUID
    var role: String
    var content: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        role: String,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}
