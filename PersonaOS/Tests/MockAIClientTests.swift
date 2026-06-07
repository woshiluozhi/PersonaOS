import XCTest
@testable import PersonaOS

final class MockAIClientTests: XCTestCase {
    private func context() -> AIRequestContext {
        AIRequestContext(
            userName: "智",
            companionName: "药老",
            userLevel: 1,
            currentXP: 0,
            activeQuestTitles: ["构建个人 AI 伴生智能体"],
            todayTaskTitles: ["完成 PersonaOS MVP 骨架"],
            completedTodayTaskTitles: [],
            overdueTaskTitles: [],
            recentMemories: ["用户希望构建长期陪伴智能体"],
            recentDailyReports: []
        )
    }

    func testWhatShouldIDoReturnsMainQuestAdvice() async throws {
        let client = MockAIClient()

        let response = try await client.sendMessage(userMessage: "我该做什么", context: context())

        XCTAssertTrue(response.assistantMessage.contains("构建个人 AI 伴生智能体"))
        XCTAssertFalse(response.suggestedTasks.isEmpty)
    }

    func testWhatShouldIDoPrioritizesOverdueTasks() async throws {
        let client = MockAIClient()
        var requestContext = context()
        requestContext.overdueTaskTitles = ["补齐验收测试"]

        let response = try await client.sendMessage(userMessage: "我该做什么", context: requestContext)

        XCTAssertTrue(response.assistantMessage.contains("补齐验收测试"))
        XCTAssertTrue(response.suggestedTasks.contains("补齐验收测试"))
        XCTAssertTrue(response.riskFlags.contains("overdue_tasks"))
    }

    func testWhatShouldIDOMovesToReviewWhenTodayTasksAreDone() async throws {
        let client = MockAIClient()
        var requestContext = context()
        requestContext.completedTodayTaskTitles = requestContext.todayTaskTitles

        let response = try await client.sendMessage(userMessage: "我该做什么", context: requestContext)

        XCTAssertTrue(response.assistantMessage.contains("每日复盘"))
        XCTAssertTrue(response.suggestedTasks.contains("生成今日总结"))
        XCTAssertTrue(response.riskFlags.isEmpty)
    }

    func testWhatShouldIDoHandlesDuplicateTaskTitlesByCompletionCount() async throws {
        let client = MockAIClient()
        var requestContext = context()
        requestContext.todayTaskTitles = ["补齐测试", "补齐测试"]
        requestContext.completedTodayTaskTitles = ["补齐测试"]

        let response = try await client.sendMessage(userMessage: "我该做什么", context: requestContext)

        XCTAssertTrue(response.assistantMessage.contains("补齐测试"))
        XCTAssertEqual(response.suggestedTasks, ["补齐测试"])
        XCTAssertFalse(response.assistantMessage.contains("每日复盘"))
    }

    func testWhatShouldIDoNormalizesDuplicateTaskTitlesBeforeCountingCompletions() async throws {
        let client = MockAIClient()
        var requestContext = context()
        requestContext.todayTaskTitles = ["补齐  测试", "\n补齐 测试\t", "写 日报"]
        requestContext.completedTodayTaskTitles = ["补齐 测试"]

        let response = try await client.sendMessage(userMessage: "我该做什么", context: requestContext)

        XCTAssertTrue(response.assistantMessage.contains("补齐 测试"))
        XCTAssertEqual(response.suggestedTasks, ["补齐 测试", "写 日报"])
        XCTAssertFalse(response.assistantMessage.contains("每日复盘"))
    }

    func testWhatShouldIDoIgnoresBlankTaskTitles() async throws {
        let client = MockAIClient()
        var requestContext = context()
        requestContext.todayTaskTitles = [" ", "\n\t"]
        requestContext.completedTodayTaskTitles = []

        let response = try await client.sendMessage(userMessage: "我该做什么", context: requestContext)

        XCTAssertTrue(response.assistantMessage.contains("写下下一步可执行动作"))
        XCTAssertEqual(response.suggestedTasks, ["写下下一步可执行动作"])
        XCTAssertFalse(response.assistantMessage.contains("每日复盘"))
    }

    func testWhatShouldIDOSuggestsFallbackTaskWhenTodayIsEmpty() async throws {
        let client = MockAIClient()
        var requestContext = context()
        requestContext.todayTaskTitles = []
        requestContext.completedTodayTaskTitles = []

        let response = try await client.sendMessage(userMessage: "我该做什么", context: requestContext)

        XCTAssertTrue(response.assistantMessage.contains("写下下一步可执行动作"))
        XCTAssertEqual(response.suggestedTasks, ["写下下一步可执行动作"])
    }

    func testWhatShouldIDONormalizesBlankNamesAndQuestContext() async throws {
        let client = MockAIClient()
        var requestContext = context()
        requestContext.userName = "   "
        requestContext.companionName = "   "
        requestContext.activeQuestTitles = [" ", "\n\t"]
        requestContext.todayTaskTitles = []
        requestContext.completedTodayTaskTitles = []

        let response = try await client.sendMessage(userMessage: "我该做什么", context: requestContext)

        XCTAssertTrue(response.assistantMessage.contains("你，先看主线：当前主线尚未明确"))
        XCTAssertTrue(response.assistantMessage.contains("写下下一步可执行动作"))
    }

    func testGeneralReplyIgnoresBlankMemoryHintsAndFallbacksCompanionName() async throws {
        let client = MockAIClient()
        var requestContext = context()
        requestContext.companionName = "   "
        requestContext.activeQuestTitles = ["  "]
        requestContext.recentMemories = ["  "]

        let response = try await client.sendMessage(userMessage: "今天要推进 MVP", context: requestContext)

        XCTAssertTrue(response.assistantMessage.contains("药老的判断"))
        XCTAssertTrue(response.assistantMessage.contains("当前主线尚未明确"))
        XCTAssertFalse(response.assistantMessage.contains("我记得你重视"))
    }

    func testGeneralReplyUsesCleanRecentDailyReportWhenMemoryIsBlank() async throws {
        let client = MockAIClient()
        var requestContext = context()
        requestContext.recentMemories = [" \n "]
        requestContext.recentDailyReports = [" 主线\n推进\t不足 "]

        let response = try await client.sendMessage(userMessage: "今天要推进 MVP", context: requestContext)

        XCTAssertTrue(response.assistantMessage.contains("最近复盘提到「主线 推进 不足」"))
        XCTAssertFalse(response.assistantMessage.contains("\n"))
    }

    func testSuggestedMemoryUsesCleanUserMessage() async throws {
        let client = MockAIClient()

        let response = try await client.sendMessage(
            userMessage: " 今天\n要\t推进 PersonaOS MVP ",
            context: context()
        )

        XCTAssertEqual(response.suggestedMemories, ["用户提到：今天 要 推进 PersonaOS MVP"])
    }

    func testNewProjectReturnsRiskReminder() async throws {
        let client = MockAIClient()

        let response = try await client.sendMessage(userMessage: "我想开新项目", context: context())

        XCTAssertTrue(response.assistantMessage.contains("先别急"))
        XCTAssertTrue(response.riskFlags.contains("scope_creep"))
    }

    func testRiskCheckCallsOutOverdueTasks() async throws {
        let client = MockAIClient()
        var requestContext = context()
        requestContext.overdueTaskTitles = ["补齐验收测试"]

        let response = try await client.sendMessage(userMessage: "检查风险", context: requestContext)

        XCTAssertTrue(response.assistantMessage.contains("补齐验收测试"))
        XCTAssertTrue(response.suggestedTasks.contains("补齐验收测试"))
        XCTAssertTrue(response.riskFlags.contains("overdue_tasks"))
    }

    func testResponseShapeIsComplete() async throws {
        let client = MockAIClient()

        let response = try await client.sendMessage(userMessage: "今天要推进 MVP", context: context())

        XCTAssertFalse(response.assistantMessage.isEmpty)
        XCTAssertNotNil(response.suggestedMemories)
        XCTAssertNotNil(response.suggestedTasks)
        XCTAssertNotNil(response.riskFlags)
    }

    func testDailySummaryRequestSuggestsReview() async throws {
        let client = MockAIClient()

        let response = try await client.sendMessage(userMessage: "总结今天", context: context())

        XCTAssertTrue(response.assistantMessage.contains("每日复盘"))
        XCTAssertTrue(response.suggestedTasks.contains("生成今日总结"))
    }
}
