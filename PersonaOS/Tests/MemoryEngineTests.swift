import SwiftData
import XCTest
@testable import PersonaOS

@MainActor
final class MemoryEngineTests: XCTestCase {
    func testCreateCandidateMemory() {
        let engine = MemoryEngine()

        let memory = engine.makeCandidateMemory(from: " 用户希望\n长期主义\t推进主线 ", source: " ")
        let sourcedMemory = engine.makeCandidateMemory(from: "用户偏好", source: " chat\nplugin ")

        XCTAssertEqual(memory.content, "用户希望 长期主义 推进主线")
        XCTAssertEqual(memory.source, "chat")
        XCTAssertFalse(memory.isUserConfirmed)
        XCTAssertEqual(memory.tagsText, "候选")
        XCTAssertEqual(sourcedMemory.source, "chat plugin")
    }

    func testTagsSplitTrimAndDeduplicate() {
        let engine = MemoryEngine()

        let tags = engine.tags(from: " PersonaOS, 长期主义，personaos; 伴生智能体； ")

        XCTAssertEqual(tags, ["PersonaOS", "长期主义", "伴生智能体"])
    }

    func testTagsNormalizeWidthWhitespaceAndCaseForDeduplication() {
        let engine = MemoryEngine()

        let tags = engine.tags(from: " ＡＩ, ai，AI ;  长期   主义 ; 长期 主义 ")

        XCTAssertEqual(tags, ["AI", "长期 主义"])
    }

    func testStatusTitle() {
        let engine = MemoryEngine()
        let confirmed = MemoryRecord(content: "已确认", isUserConfirmed: true)
        let candidate = MemoryRecord(content: "候选", isUserConfirmed: false)
        let dismissed = MemoryRecord(content: "已忽略", isUserConfirmed: false, isDismissed: true)

        XCTAssertEqual(engine.statusTitle(for: confirmed), "已确认")
        XCTAssertEqual(engine.statusTitle(for: candidate), "候选")
        XCTAssertEqual(engine.statusTitle(for: dismissed), "已忽略")
    }

    func testSummaryCountsStatusesAndTreatsDismissedAsSeparate() {
        let engine = MemoryEngine()
        let confirmed = MemoryRecord(content: "已确认", isUserConfirmed: true)
        let candidate = MemoryRecord(content: "候选", isUserConfirmed: false)
        let dismissedCandidate = MemoryRecord(content: "已忽略候选", isUserConfirmed: false, isDismissed: true)
        let dismissedConfirmed = MemoryRecord(content: "已忽略确认", isUserConfirmed: true, isDismissed: true)
        let blank = MemoryRecord(content: " \n\t ", isUserConfirmed: true)

        let summary = engine.summary(for: [confirmed, candidate, dismissedCandidate, dismissedConfirmed, blank])

        XCTAssertEqual(
            summary,
            MemoryCollectionSummary(
                totalCount: 4,
                confirmedCount: 1,
                candidateCount: 1,
                dismissedCount: 2
            )
        )
    }

    func testMemoryDeleteConfirmationCopyUsesCleanPreviewAndCount() {
        let engine = MemoryEngine()
        let messy = MemoryRecord(content: "  用户\n偏好\t主线  ")
        let second = MemoryRecord(content: "整理支线")
        let blank = MemoryRecord(content: " \n\t ")
        let long = MemoryRecord(content: "12345678901234567890123456789")

        XCTAssertEqual(engine.memoryDeleteConfirmationTitle(for: [messy]), "删除这条记忆")
        XCTAssertEqual(
            engine.memoryDeleteConfirmationMessage(for: [messy]),
            "这会删除「用户 偏好 主线」这条本地记忆。"
        )
        XCTAssertEqual(engine.memoryDeleteConfirmationTitle(for: [messy, second]), "删除 2 条记忆")
        XCTAssertEqual(
            engine.memoryDeleteConfirmationMessage(for: [messy, second]),
            "这会删除选中的 2 条本地记忆。"
        )
        XCTAssertEqual(
            engine.memoryDeleteConfirmationMessage(for: [blank]),
            "这会删除「空白记忆」这条本地记忆。"
        )
        XCTAssertEqual(
            engine.memoryDeleteConfirmationMessage(for: [long]),
            "这会删除「1234567890123456789012345678...」这条本地记忆。"
        )
    }

    func testHasMemoryNormalizesContentAndCanMatchSource() {
        let engine = MemoryEngine()
        let chatMemory = MemoryRecord(content: " 用户   提到\n主线 ", source: "chat")
        let manualMemory = MemoryRecord(content: "用户提到主线", source: "manual")

        XCTAssertTrue(engine.hasMemory(content: "用户 提到 主线", source: "chat", in: [chatMemory]))
        XCTAssertTrue(engine.hasMemory(content: "用户 提到 主线", source: " Chat ", in: [chatMemory]))
        XCTAssertTrue(engine.hasMemory(content: " 用户提到主线 ", in: [manualMemory]))
        XCTAssertFalse(engine.hasMemory(content: "用户提到主线", source: "demo", in: [chatMemory, manualMemory]))
        XCTAssertFalse(engine.hasMemory(content: " ", in: [chatMemory]))
    }

    func testConfirmMemory() {
        let engine = MemoryEngine()
        let memory = MemoryRecord(content: "候选", confidence: 0.2, isUserConfirmed: false, isDismissed: true)

        engine.confirmMemory(memory)

        XCTAssertTrue(memory.isUserConfirmed)
        XCTAssertFalse(memory.isDismissed)
        XCTAssertGreaterThanOrEqual(memory.confidence, 0.8)
    }

    func testConfirmMemoryNormalizesStoredTextAndTags() {
        let engine = MemoryEngine()
        let memory = MemoryRecord(
            content: "  主线\n偏好\t细节  ",
            source: " chat\npanel ",
            tagsText: " ＡＩ, ai;  长期   主义 ",
            confidence: 0.2,
            isUserConfirmed: false
        )
        let blankSource = MemoryRecord(content: "来源空白", source: " \n\t ", isUserConfirmed: false)

        engine.confirmMemory(memory)
        engine.confirmMemory(blankSource)

        XCTAssertEqual(memory.content, "主线 偏好 细节")
        XCTAssertEqual(memory.source, "chat panel")
        XCTAssertEqual(memory.tagsText, "AI, 长期 主义")
        XCTAssertEqual(blankSource.source, "manual")
    }

    func testDismissAndRestoreMemory() {
        let engine = MemoryEngine()
        let memory = MemoryRecord(content: "暂不采用", isUserConfirmed: false)

        engine.dismissMemory(memory)
        XCTAssertTrue(memory.isDismissed)

        engine.restoreMemory(memory)
        XCTAssertFalse(memory.isDismissed)
    }

    func testDeleteMemory() throws {
        let schema = Schema([MemoryRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let engine = MemoryEngine()
        let memory = MemoryRecord(content: "待删除")

        context.insert(memory)
        try context.save()
        engine.deleteMemory(memory, context: context)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<MemoryRecord>())
        XCTAssertTrue(remaining.isEmpty)
    }

    func testSaveMemoryNormalizesMetadataAndBoundsWeights() throws {
        let schema = Schema([MemoryRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let engine = MemoryEngine()

        engine.saveMemory(
            content: " 用户\n偏好\t主线 ",
            source: " manual\ninput ",
            tagsText: " PersonaOS, 主线 ",
            importance: 99,
            confidence: 2,
            sensitivityLevel: -1,
            context: context
        )
        try context.save()

        let memory = try XCTUnwrap(try context.fetch(FetchDescriptor<MemoryRecord>()).first)
        XCTAssertEqual(memory.content, "用户 偏好 主线")
        XCTAssertEqual(memory.source, "manual input")
        XCTAssertEqual(memory.tagsText, "PersonaOS, 主线")
        XCTAssertEqual(memory.importance, 10)
        XCTAssertEqual(memory.confidence, 1)
        XCTAssertEqual(memory.sensitivityLevel, 0)
    }

    func testSaveMemoryCanonicalizesTags() throws {
        let schema = Schema([MemoryRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let engine = MemoryEngine()

        engine.saveMemory(
            content: "用户关注本地 AI",
            tagsText: " ＡＩ, ai;  长期   主义 ",
            context: context
        )
        try context.save()

        let memory = try XCTUnwrap(try context.fetch(FetchDescriptor<MemoryRecord>()).first)
        XCTAssertEqual(memory.tagsText, "AI, 长期 主义")
    }

    func testSaveMemorySkipsEmptyContentAndDefaultsEmptySource() throws {
        let schema = Schema([MemoryRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let engine = MemoryEngine()

        engine.saveMemory(content: "   ", source: "manual", context: context)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<MemoryRecord>()).isEmpty)

        engine.saveMemory(content: " 用户重视主线 ", source: " ", context: context)
        try context.save()

        let memory = try XCTUnwrap(try context.fetch(FetchDescriptor<MemoryRecord>()).first)
        XCTAssertEqual(memory.content, "用户重视主线")
        XCTAssertEqual(memory.source, "manual")
    }

    func testDeleteDismissedMemoriesOnlyRemovesIgnoredRecords() throws {
        let schema = Schema([MemoryRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let engine = MemoryEngine()
        let confirmed = MemoryRecord(content: "保留确认", isUserConfirmed: true)
        let candidate = MemoryRecord(content: "保留候选", isUserConfirmed: false)
        let dismissed = MemoryRecord(content: "清理忽略", isUserConfirmed: false, isDismissed: true)

        [confirmed, candidate, dismissed].forEach(context.insert)
        try context.save()

        let deletedCount = engine.deleteDismissedMemories([confirmed, candidate, dismissed], context: context)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<MemoryRecord>())
        XCTAssertEqual(deletedCount, 1)
        XCTAssertEqual(remaining.map(\.content).sorted(), ["保留候选", "保留确认"])
    }

    func testQuerySorting() {
        let engine = MemoryEngine()
        let older = MemoryRecord(content: "低重要", importance: 1, createdAt: Date(timeIntervalSince1970: 10))
        let newer = MemoryRecord(content: "高重要", importance: 9, createdAt: Date(timeIntervalSince1970: 1))

        let results = engine.queryMemories([older, newer], statusFilter: .all)

        XCTAssertEqual(results.first?.content, "高重要")
    }

    func testQueryStatusFilterAndSearchText() {
        let engine = MemoryEngine()
        let confirmed = MemoryRecord(content: "用户重视主线", source: "manual", tagsText: "长期", isUserConfirmed: true)
        let candidate = MemoryRecord(content: "用户提到新想法", source: "chat", tagsText: "候选", isUserConfirmed: false)
        let unrelated = MemoryRecord(content: "普通记录", source: "manual", tagsText: "杂项", isUserConfirmed: true)
        let dismissed = MemoryRecord(content: "被忽略的候选", source: "chat", tagsText: "候选", isUserConfirmed: false, isDismissed: true)

        let allMemories = [confirmed, candidate, unrelated, dismissed]
        let allResults = engine.queryMemories(allMemories, statusFilter: .all)
        let candidateResults = engine.queryMemories(allMemories, statusFilter: .candidates)
        let confirmedResults = engine.queryMemories(allMemories, statusFilter: .confirmed)
        let dismissedResults = engine.queryMemories(allMemories, statusFilter: .dismissed)
        let chatResults = engine.queryMemories(allMemories, statusFilter: .all, searchText: "chat")

        XCTAssertFalse(allResults.contains { $0.isDismissed })
        XCTAssertEqual(candidateResults.map(\.content), ["用户提到新想法"])
        XCTAssertFalse(confirmedResults.contains { !$0.isUserConfirmed })
        XCTAssertEqual(dismissedResults.map(\.content), ["被忽略的候选"])
        XCTAssertEqual(chatResults.map(\.content), ["用户提到新想法"])
    }

    func testQuerySkipsBlankContentAndUsesCleanDisplayContent() {
        let engine = MemoryEngine()
        let blank = MemoryRecord(content: " \n\t ")
        let messy = MemoryRecord(content: " 主线\n\n偏好\t细节 ")

        XCTAssertEqual(engine.queryMemories([blank, messy]).map(\.content), [" 主线\n\n偏好\t细节 "])
        XCTAssertEqual(engine.displayContent(for: messy), "主线 偏好 细节")
        XCTAssertEqual(
            engine.queryMemories([messy], searchText: "主线 细节").map(\.content),
            [" 主线\n\n偏好\t细节 "]
        )
    }

    func testQuerySearchMatchesMemoryStatusTitle() {
        let engine = MemoryEngine()
        let confirmed = MemoryRecord(content: "主线偏好", tagsText: "", isUserConfirmed: true)
        let candidate = MemoryRecord(content: "新想法", tagsText: "", isUserConfirmed: false)
        let dismissed = MemoryRecord(content: "暂不采用", tagsText: "", isUserConfirmed: false, isDismissed: true)

        let confirmedResults = engine.queryMemories([confirmed, candidate, dismissed], statusFilter: .all, searchText: "已确认")
        let candidateResults = engine.queryMemories([confirmed, candidate, dismissed], statusFilter: .all, searchText: "候选")
        let dismissedResults = engine.queryMemories([confirmed, candidate, dismissed], statusFilter: .dismissed, searchText: "已忽略")

        XCTAssertEqual(confirmedResults.map(\.content), ["主线偏好"])
        XCTAssertEqual(candidateResults.map(\.content), ["新想法"])
        XCTAssertEqual(dismissedResults.map(\.content), ["暂不采用"])
    }

    func testQuerySearchMatchesMemoryWeightMetadata() {
        let engine = MemoryEngine()
        let strategic = MemoryRecord(
            content: "战略偏好",
            importance: 9,
            confidence: 0.85,
            sensitivityLevel: 1
        )
        let sensitive = MemoryRecord(
            content: "敏感边界",
            importance: 3,
            confidence: 0.4,
            sensitivityLevel: 4
        )
        let dirtyMetadata = MemoryRecord(
            content: "旧脏记忆",
            importance: 99,
            confidence: 2,
            sensitivityLevel: -1
        )

        XCTAssertEqual(
            engine.queryMemories([strategic, sensitive], searchText: "重要 9").map(\.content),
            ["战略偏好"]
        )
        XCTAssertEqual(
            engine.queryMemories([strategic, sensitive], searchText: "置信 0.85").map(\.content),
            ["战略偏好"]
        )
        XCTAssertEqual(
            engine.queryMemories([strategic, sensitive], searchText: "敏感 4").map(\.content),
            ["敏感边界"]
        )
        XCTAssertEqual(
            engine.metrics(for: dirtyMetadata),
            MemoryMetrics(importance: 10, confidence: 1, sensitivityLevel: 0)
        )
        XCTAssertEqual(
            engine.queryMemories([dirtyMetadata], searchText: "重要 10").map(\.content),
            ["旧脏记忆"]
        )
        XCTAssertEqual(
            engine.queryMemories([dirtyMetadata], searchText: "置信 1.00").map(\.content),
            ["旧脏记忆"]
        )
        XCTAssertEqual(
            engine.queryMemories([dirtyMetadata], searchText: "敏感 0").map(\.content),
            ["旧脏记忆"]
        )
        XCTAssertTrue(engine.queryMemories([dirtyMetadata], searchText: "重要 99").isEmpty)
        XCTAssertTrue(engine.queryMemories([dirtyMetadata], searchText: "置信 2.00").isEmpty)
        XCTAssertTrue(engine.queryMemories([dirtyMetadata], searchText: "敏感 -1").isEmpty)

        engine.confirmMemory(dirtyMetadata)

        XCTAssertEqual(dirtyMetadata.confidence, 1)
    }

    func testQuerySearchMatchesMemoryRelativeDateMetadata() throws {
        let engine = MemoryEngine()
        let calendar = Calendar(identifier: .gregorian)
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7)))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))
        let yesterdayMemory = MemoryRecord(
            content: "昨日偏好",
            createdAt: yesterday,
            updatedAt: yesterday
        )
        let todayMemory = MemoryRecord(
            content: "今日偏好",
            createdAt: today,
            updatedAt: today
        )

        let results = engine.queryMemories(
            [todayMemory, yesterdayMemory],
            searchText: "昨天",
            referenceDate: today,
            calendar: calendar
        )

        XCTAssertEqual(results.map(\.content), ["昨日偏好"])
    }

    func testQuerySearchMatchesMultipleTermsAcrossContentAndDate() throws {
        let engine = MemoryEngine()
        let calendar = Calendar(identifier: .gregorian)
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7)))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))
        let yesterdayMain = MemoryRecord(content: "主线偏好", createdAt: yesterday, updatedAt: yesterday)
        let todayMain = MemoryRecord(content: "主线偏好", createdAt: today, updatedAt: today)
        let yesterdaySide = MemoryRecord(content: "支线偏好", createdAt: yesterday, updatedAt: yesterday)

        let results = engine.queryMemories(
            [todayMain, yesterdaySide, yesterdayMain],
            searchText: "主线 昨天",
            referenceDate: today,
            calendar: calendar
        )

        XCTAssertEqual(results.map(\.content), ["主线偏好"])
        XCTAssertEqual(results.first?.createdAt, yesterday)
    }
}

@MainActor
final class DemoDataSeederTests: XCTestCase {
    func testProfileEditableFieldsNormalizeBlankTextAndBounds() {
        let now = Date(timeIntervalSince1970: 123)
        let user = UserProfile(
            name: " 智\n者\t一号 ",
            energy: -10,
            focus: 120,
            stress: 150
        )
        let companion = CompanionPersona(
            name: " 药老\nPro ",
            styleDescription: " 冷静\n直接\t长期主义 ",
            voiceStyle: "  沉稳\n一点  ",
            strictnessLevel: 12,
            warmthLevel: -3
        )

        user.normalizeEditableFields(now: now)
        companion.normalizeEditableFields(now: now)

        XCTAssertEqual(user.name, "智 者 一号")
        XCTAssertEqual(user.energy, 0)
        XCTAssertEqual(user.focus, 100)
        XCTAssertEqual(user.stress, 100)
        XCTAssertEqual(user.updatedAt, now)
        XCTAssertEqual(companion.name, "药老 Pro")
        XCTAssertEqual(companion.styleDescription, "冷静 直接 长期主义")
        XCTAssertEqual(companion.voiceStyle, "沉稳 一点")
        XCTAssertEqual(companion.strictnessLevel, 10)
        XCTAssertEqual(companion.warmthLevel, 0)
        XCTAssertEqual(companion.updatedAt, now)
    }

    func testProfileEditableFieldsUseFallbacksForBlankText() {
        let user = UserProfile(name: " \n\t ")
        let companion = CompanionPersona(
            name: " ",
            styleDescription: " \n",
            voiceStyle: "\t "
        )

        user.normalizeEditableFields()
        companion.normalizeEditableFields()

        XCTAssertEqual(user.name, "智")
        XCTAssertEqual(companion.name, "药老")
        XCTAssertEqual(companion.styleDescription, "冷静、直接、长期主义，不盲目迎合")
        XCTAssertEqual(companion.voiceStyle, "沉稳、简洁")
    }

    func testSeedIfNeededDoesNotDuplicateDemoData() throws {
        let context = try makeContext()

        DemoDataSeeder.seedIfNeeded(context: context)
        DemoDataSeeder.seedIfNeeded(context: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<UserProfile>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CompanionPersona>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Quest>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TaskItem>()).count, 3)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MemoryRecord>()).count, 1)
        let reports = try context.fetch(FetchDescriptor<DailyReport>())
        XCTAssertEqual(reports.count, 1)
        XCTAssertFalse(Calendar.current.isDateInToday(try XCTUnwrap(reports.first).date))

        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        XCTAssertEqual(tasks.filter { $0.questId != nil }.count, 2)
    }

    func testResetDemoDataRestoresDefaults() throws {
        let context = try makeContext()
        context.insert(UserProfile(name: "临时用户"))
        context.insert(ChatMessage(role: ChatRole.user.rawValue, content: "临时对话"))
        try context.save()

        DemoDataSeeder.resetDemoData(context: context)

        let users = try context.fetch(FetchDescriptor<UserProfile>())
        let messages = try context.fetch(FetchDescriptor<ChatMessage>())

        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users.first?.name, "智")
        XCTAssertTrue(messages.isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TaskItem>()).count, 3)
    }

    func testClearChatReturnsDeletedCountAndPreservesOtherData() throws {
        let context = try makeContext()
        let task = TaskItem(title: "保留任务")
        let firstMessage = ChatMessage(role: ChatRole.user.rawValue, content: "第一条")
        let secondMessage = ChatMessage(role: ChatRole.assistant.rawValue, content: "第二条")

        context.insert(task)
        context.insert(firstMessage)
        context.insert(secondMessage)
        try context.save()

        let deletedCount = DemoDataSeeder.clearChat(context: context)

        XCTAssertEqual(deletedCount, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChatMessage>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TaskItem>()).count, 1)
    }

    func testClearMemoriesReturnsDeletedCountAndPreservesReports() throws {
        let context = try makeContext()
        let firstMemory = MemoryRecord(content: "第一条记忆")
        let secondMemory = MemoryRecord(content: "第二条记忆")
        let report = DailyReport(summary: "保留日报")

        context.insert(firstMemory)
        context.insert(secondMemory)
        context.insert(report)
        try context.save()

        let deletedCount = DemoDataSeeder.clearMemories(context: context)

        XCTAssertEqual(deletedCount, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MemoryRecord>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DailyReport>()).count, 1)
    }

    func testClearReportsOnlyRemovesDailyReports() throws {
        let context = try makeContext()
        let task = TaskItem(title: "保留任务")
        let memory = MemoryRecord(content: "保留记忆")
        let report = DailyReport(summary: "待清理日报")

        context.insert(task)
        context.insert(memory)
        context.insert(report)
        try context.save()

        let deletedCount = DemoDataSeeder.clearReports(context: context)

        XCTAssertEqual(deletedCount, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DailyReport>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TaskItem>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MemoryRecord>()).count, 1)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            UserProfile.self,
            CompanionPersona.self,
            Quest.self,
            TaskItem.self,
            MemoryRecord.self,
            DailyReport.self,
            ChatMessage.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return container.mainContext
    }
}
