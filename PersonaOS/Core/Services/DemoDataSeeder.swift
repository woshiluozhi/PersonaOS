import Foundation
import SwiftData

enum DemoDataSeeder {
    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        var descriptor = FetchDescriptor<UserProfile>()
        descriptor.fetchLimit = 1
        let existingUsers = (try? context.fetch(descriptor)) ?? []
        guard existingUsers.isEmpty else {
            return
        }

        insertDefaults(context: context)
    }

    @MainActor
    static func resetDemoData(context: ModelContext) {
        deleteAll(context: context)
        insertDefaults(context: context)
    }

    @MainActor
    @discardableResult
    static func clearChat(context: ModelContext) -> Int {
        let deletedCount = delete(ChatMessage.self, context: context)
        try? context.save()
        return deletedCount
    }

    @MainActor
    @discardableResult
    static func clearMemories(context: ModelContext) -> Int {
        let deletedCount = delete(MemoryRecord.self, context: context)
        try? context.save()
        return deletedCount
    }

    @MainActor
    @discardableResult
    static func clearReports(context: ModelContext) -> Int {
        let deletedCount = delete(DailyReport.self, context: context)
        try? context.save()
        return deletedCount
    }

    @MainActor
    private static func insertDefaults(context: ModelContext) {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let user = UserProfile(createdAt: now, updatedAt: now)
        let companion = CompanionPersona(createdAt: now, updatedAt: now)

        let mainQuest = Quest(
            title: "构建个人 AI 伴生智能体",
            detail: "第一阶段先做本地可运行 MVP，形成任务、记忆、复盘与对话闭环。",
            questType: QuestType.main.rawValue,
            status: QuestStatus.active.rawValue,
            priority: 1,
            createdAt: now,
            updatedAt: now
        )

        let sideQuest = Quest(
            title: "整理长期记忆系统",
            detail: "把候选记忆与用户确认机制拆开，避免未经确认写入长期记忆。",
            questType: QuestType.side.rawValue,
            status: QuestStatus.active.rawValue,
            priority: 2,
            createdAt: now,
            updatedAt: now
        )

        let tasks = [
            TaskItem(
                title: "完成 PersonaOS MVP 骨架",
                detail: "先保证 App 可运行，再扩展复杂能力。",
                taskType: QuestType.daily.rawValue,
                questId: mainQuest.id,
                xpReward: 40,
                dueDate: now,
                createdAt: now
            ),
            TaskItem(
                title: "写下今日关键事件",
                detail: "记录真正影响主线推进的事件。",
                taskType: QuestType.daily.rawValue,
                xpReward: 20,
                dueDate: now,
                createdAt: now
            ),
            TaskItem(
                title: "复盘主线推进情况",
                detail: "判断今天是否让 MVP 更接近可运行。",
                taskType: QuestType.daily.rawValue,
                questId: mainQuest.id,
                xpReward: 30,
                dueDate: now,
                createdAt: now
            )
        ]

        let memory = MemoryRecord(
            content: "用户希望构建一个像药老一样长期陪伴、提醒和规划的个人智能体",
            source: "demo",
            tagsText: "PersonaOS,长期主义,伴生智能体",
            importance: 9,
            confidence: 0.9,
            sensitivityLevel: 1,
            isUserConfirmed: true,
            createdAt: now,
            updatedAt: now
        )

        let report = DailyReport(
            date: yesterday,
            completedTaskCount: 0,
            totalTaskCount: tasks.count,
            xpGained: 0,
            summary: "本地演示日报：昨日已建立目标，今天等待完成任务。",
            companionComment: "药老已苏醒。今天先完成 MVP 骨架，再谈扩展能力。",
            createdAt: yesterday
        )

        context.insert(user)
        context.insert(companion)
        context.insert(mainQuest)
        context.insert(sideQuest)
        tasks.forEach { context.insert($0) }
        context.insert(memory)
        context.insert(report)
        try? context.save()
    }

    @MainActor
    private static func deleteAll(context: ModelContext) {
        delete(ChatMessage.self, context: context)
        delete(DailyReport.self, context: context)
        delete(MemoryRecord.self, context: context)
        delete(TaskItem.self, context: context)
        delete(Quest.self, context: context)
        delete(CompanionPersona.self, context: context)
        delete(UserProfile.self, context: context)
        try? context.save()
    }

    @MainActor
    @discardableResult
    private static func delete<T: PersistentModel>(_ modelType: T.Type, context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<T>()
        let items = (try? context.fetch(descriptor)) ?? []
        for item in items {
            context.delete(item)
        }
        return items.count
    }
}
