import Foundation

struct LocalDataExportService {
    func makeExportData(
        users: [UserProfile],
        companions: [CompanionPersona],
        quests: [Quest],
        tasks: [TaskItem],
        memories: [MemoryRecord],
        reports: [DailyReport],
        messages: [ChatMessage],
        exportedAt: Date = Date()
    ) throws -> Data {
        let export = PersonaOSLocalDataExport(
            schemaVersion: 1,
            appName: "PersonaOS",
            exportedAt: exportedAt,
            dataBoundary: "This export includes local SwiftData content only. It does not include the OpenAI API Key stored in Keychain.",
            counts: LocalDataExportCounts(
                users: users.count,
                companions: companions.count,
                quests: quests.count,
                tasks: tasks.count,
                memories: memories.count,
                dailyReports: reports.count,
                chatMessages: messages.count
            ),
            users: users
                .sorted { sort($0.createdAt, $0.name, before: $1.createdAt, $1.name) }
                .map(ExportedUserProfile.init),
            companions: companions
                .sorted { sort($0.createdAt, $0.name, before: $1.createdAt, $1.name) }
                .map(ExportedCompanionPersona.init),
            quests: quests
                .sorted { sort($0.createdAt, $0.title, before: $1.createdAt, $1.title) }
                .map(ExportedQuest.init),
            tasks: tasks
                .sorted { sort($0.createdAt, $0.title, before: $1.createdAt, $1.title) }
                .map(ExportedTaskItem.init),
            memories: memories
                .sorted { sort($0.createdAt, $0.content, before: $1.createdAt, $1.content) }
                .map(ExportedMemoryRecord.init),
            dailyReports: reports
                .sorted { sort($0.createdAt, $0.summary, before: $1.createdAt, $1.summary) }
                .map(ExportedDailyReport.init),
            chatMessages: messages
                .sorted { sort($0.createdAt, $0.content, before: $1.createdAt, $1.content) }
                .map(ExportedChatMessage.init)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(export)
    }

    func suggestedFilename(exportedAt: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "personaos-export-\(formatter.string(from: exportedAt)).json"
    }

    private func sort(_ lhsDate: Date, _ lhsText: String, before rhsDate: Date, _ rhsText: String) -> Bool {
        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }
        return lhsText.localizedStandardCompare(rhsText) == .orderedAscending
    }
}

struct PersonaOSLocalDataExport: Codable {
    let schemaVersion: Int
    let appName: String
    let exportedAt: Date
    let dataBoundary: String
    let counts: LocalDataExportCounts
    let users: [ExportedUserProfile]
    let companions: [ExportedCompanionPersona]
    let quests: [ExportedQuest]
    let tasks: [ExportedTaskItem]
    let memories: [ExportedMemoryRecord]
    let dailyReports: [ExportedDailyReport]
    let chatMessages: [ExportedChatMessage]
}

struct LocalDataExportCounts: Codable, Equatable {
    let users: Int
    let companions: Int
    let quests: Int
    let tasks: Int
    let memories: Int
    let dailyReports: Int
    let chatMessages: Int
}

struct ExportedUserProfile: Codable, Equatable {
    let id: UUID
    let name: String
    let level: Int
    let currentXP: Int
    let energy: Int
    let focus: Int
    let stress: Int
    let createdAt: Date
    let updatedAt: Date

    init(_ user: UserProfile) {
        id = user.id
        name = user.name
        level = user.level
        currentXP = user.currentXP
        energy = user.energy
        focus = user.focus
        stress = user.stress
        createdAt = user.createdAt
        updatedAt = user.updatedAt
    }
}

struct ExportedCompanionPersona: Codable, Equatable {
    let id: UUID
    let name: String
    let styleDescription: String
    let voiceStyle: String
    let strictnessLevel: Int
    let warmthLevel: Int
    let createdAt: Date
    let updatedAt: Date

    init(_ companion: CompanionPersona) {
        id = companion.id
        name = companion.name
        styleDescription = companion.styleDescription
        voiceStyle = companion.voiceStyle
        strictnessLevel = companion.strictnessLevel
        warmthLevel = companion.warmthLevel
        createdAt = companion.createdAt
        updatedAt = companion.updatedAt
    }
}

struct ExportedQuest: Codable, Equatable {
    let id: UUID
    let title: String
    let detail: String
    let questType: String
    let status: String
    let priority: Int
    let createdAt: Date
    let updatedAt: Date

    init(_ quest: Quest) {
        id = quest.id
        title = quest.title
        detail = quest.detail
        questType = quest.questType
        status = quest.status
        priority = quest.priority
        createdAt = quest.createdAt
        updatedAt = quest.updatedAt
    }
}

struct ExportedTaskItem: Codable, Equatable {
    let id: UUID
    let title: String
    let detail: String
    let taskType: String
    let questId: UUID?
    let isCompleted: Bool
    let xpReward: Int
    let dueDate: Date?
    let createdAt: Date
    let completedAt: Date?

    init(_ task: TaskItem) {
        id = task.id
        title = task.title
        detail = task.detail
        taskType = task.taskType
        questId = task.questId
        isCompleted = task.isCompleted
        xpReward = task.xpReward
        dueDate = task.dueDate
        createdAt = task.createdAt
        completedAt = task.completedAt
    }
}

struct ExportedMemoryRecord: Codable, Equatable {
    let id: UUID
    let content: String
    let source: String
    let tagsText: String
    let importance: Int
    let confidence: Double
    let sensitivityLevel: Int
    let isUserConfirmed: Bool
    let isDismissed: Bool
    let createdAt: Date
    let updatedAt: Date

    init(_ memory: MemoryRecord) {
        id = memory.id
        content = memory.content
        source = memory.source
        tagsText = memory.tagsText
        importance = memory.importance
        confidence = memory.confidence
        sensitivityLevel = memory.sensitivityLevel
        isUserConfirmed = memory.isUserConfirmed
        isDismissed = memory.isDismissed
        createdAt = memory.createdAt
        updatedAt = memory.updatedAt
    }
}

struct ExportedDailyReport: Codable, Equatable {
    let id: UUID
    let date: Date
    let completedTaskCount: Int
    let totalTaskCount: Int
    let xpGained: Int
    let summary: String
    let companionComment: String
    let createdAt: Date

    init(_ report: DailyReport) {
        id = report.id
        date = report.date
        completedTaskCount = report.completedTaskCount
        totalTaskCount = report.totalTaskCount
        xpGained = report.xpGained
        summary = report.summary
        companionComment = report.companionComment
        createdAt = report.createdAt
    }
}

struct ExportedChatMessage: Codable, Equatable {
    let id: UUID
    let role: String
    let content: String
    let createdAt: Date

    init(_ message: ChatMessage) {
        id = message.id
        role = message.role
        content = message.content
        createdAt = message.createdAt
    }
}
