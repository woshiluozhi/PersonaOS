import XCTest
@testable import PersonaOS

@MainActor
final class ChatHistoryServiceTests: XCTestCase {
    func testFilterMessagesSortsOldestFirst() {
        let service = ChatHistoryService()
        let newer = ChatMessage(
            role: ChatRole.user.rawValue,
            content: "第二条",
            createdAt: Date(timeIntervalSince1970: 20)
        )
        let older = ChatMessage(
            role: ChatRole.assistant.rawValue,
            content: "第一条",
            createdAt: Date(timeIntervalSince1970: 10)
        )

        let results = service.filterMessages([newer, older])

        XCTAssertEqual(results.map(\.content), ["第一条", "第二条"])
    }

    func testFilterMessagesByRole() {
        let service = ChatHistoryService()
        let userMessage = ChatMessage(role: ChatRole.user.rawValue, content: "我想推进主线")
        let assistantMessage = ChatMessage(role: ChatRole.assistant.rawValue, content: "先完成一个闭环")
        let systemMessage = ChatMessage(role: ChatRole.system.rawValue, content: "本地系统记录")

        let assistantResults = service.filterMessages(
            [userMessage, assistantMessage, systemMessage],
            roleFilter: .assistant
        )

        XCTAssertEqual(assistantResults.map(\.content), ["先完成一个闭环"])
    }

    func testFilterMessagesNormalizesDirtyRoleValues() {
        let service = ChatHistoryService()
        let assistantMessage = ChatMessage(role: " Assistant\n ", content: "先处理逾期任务")
        let userMessage = ChatMessage(role: ChatRole.user.rawValue, content: "我想推进主线")

        let assistantResults = service.filterMessages(
            [userMessage, assistantMessage],
            roleFilter: .assistant
        )
        let searchResults = service.filterMessages(
            [userMessage, assistantMessage],
            searchText: "药老"
        )

        XCTAssertEqual(assistantResults.map(\.content), ["先处理逾期任务"])
        XCTAssertEqual(searchResults.map(\.content), ["先处理逾期任务"])
    }

    func testSenderTitleAndUserDetectionNormalizeDirtyRoleValues() {
        let service = ChatHistoryService()
        let userMessage = ChatMessage(role: " User\n ", content: "我要推进主线")
        let assistantMessage = ChatMessage(role: " Assistant\t", content: "先做一个闭环")
        let systemMessage = ChatMessage(role: " System ", content: "本地记录")
        let unknownMessage = ChatMessage(role: " Observer\nRole ", content: "旁观记录")
        let blankRoleMessage = ChatMessage(role: " \n\t ", content: "未知记录")

        XCTAssertTrue(service.isUserMessage(userMessage))
        XCTAssertFalse(service.isUserMessage(assistantMessage))
        XCTAssertFalse(service.isUserMessage(systemMessage))
        XCTAssertEqual(service.senderTitle(for: userMessage), "智")
        XCTAssertEqual(service.senderTitle(for: assistantMessage), "药老")
        XCTAssertEqual(service.senderTitle(for: systemMessage), "系统")
        XCTAssertEqual(service.senderTitle(for: unknownMessage), "Observer Role")
        XCTAssertEqual(service.senderTitle(for: blankRoleMessage), "未知")
    }

    func testSenderTitleUsesCleanProfileNamesWithFallbacks() {
        let service = ChatHistoryService()
        let userMessage = ChatMessage(role: ChatRole.user.rawValue, content: "我要推进主线")
        let assistantMessage = ChatMessage(role: ChatRole.assistant.rawValue, content: "先做一个闭环")

        XCTAssertEqual(
            service.senderTitle(for: userMessage, userName: "  智\n行者  "),
            "智 行者"
        )
        XCTAssertEqual(
            service.senderTitle(for: assistantMessage, companionName: "  药\n老  "),
            "药 老"
        )
        XCTAssertEqual(service.senderTitle(for: userMessage, userName: " \n\t "), "智")
        XCTAssertEqual(service.senderTitle(for: assistantMessage, companionName: nil), "药老")
    }

    func testFilterMessagesSearchesContentAndRoleTitle() {
        let service = ChatHistoryService()
        let userMessage = ChatMessage(role: ChatRole.user.rawValue, content: "我要检查风险")
        let assistantMessage = ChatMessage(role: ChatRole.assistant.rawValue, content: "先处理逾期任务")
        let systemMessage = ChatMessage(role: ChatRole.system.rawValue, content: "启动记录")

        let contentResults = service.filterMessages(
            [userMessage, assistantMessage, systemMessage],
            searchText: "逾期"
        )
        let roleResults = service.filterMessages(
            [userMessage, assistantMessage, systemMessage],
            searchText: "药老"
        )

        XCTAssertEqual(contentResults.map(\.content), ["先处理逾期任务"])
        XCTAssertEqual(roleResults.map(\.content), ["先处理逾期任务"])
    }

    func testFilterMessagesSearchesRelativeDateMetadata() {
        let service = ChatHistoryService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400 * 5)
        let yesterday = Date(timeInterval: -86_400, since: today)
        let todayMessage = ChatMessage(
            role: ChatRole.user.rawValue,
            content: "今日计划",
            createdAt: today
        )
        let yesterdayMessage = ChatMessage(
            role: ChatRole.assistant.rawValue,
            content: "昨日提醒",
            createdAt: yesterday
        )

        let todayResults = service.filterMessages(
            [yesterdayMessage, todayMessage],
            searchText: "今天",
            referenceDate: today,
            calendar: calendar
        )
        let yesterdayResults = service.filterMessages(
            [yesterdayMessage, todayMessage],
            searchText: "昨天",
            referenceDate: today,
            calendar: calendar
        )

        XCTAssertEqual(todayResults.map(\.content), ["今日计划"])
        XCTAssertEqual(yesterdayResults.map(\.content), ["昨日提醒"])
    }

    func testFilterMessagesSearchesMultipleTermsAcrossRoleAndDate() {
        let service = ChatHistoryService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400 * 5)
        let yesterday = Date(timeInterval: -86_400, since: today)
        let userToday = ChatMessage(
            role: ChatRole.user.rawValue,
            content: "今日计划",
            createdAt: today
        )
        let assistantYesterday = ChatMessage(
            role: ChatRole.assistant.rawValue,
            content: "昨日提醒",
            createdAt: yesterday
        )

        let results = service.filterMessages(
            [userToday, assistantYesterday],
            searchText: "药老 昨天",
            referenceDate: today,
            calendar: calendar
        )

        XCTAssertEqual(results.map(\.content), ["昨日提醒"])
    }

    func testFilterMessagesSkipsBlankContentAndUsesCleanDisplayContent() {
        let service = ChatHistoryService()
        let blank = ChatMessage(role: ChatRole.user.rawValue, content: " \n\t ")
        let messy = ChatMessage(role: ChatRole.assistant.rawValue, content: " 主线\n\n推进\t细节 ")

        XCTAssertEqual(service.sortedMessages([blank, messy]).map(\.content), [" 主线\n\n推进\t细节 "])
        XCTAssertEqual(service.displayContent(for: messy), "主线 推进 细节")
        XCTAssertEqual(
            service.filterMessages([blank, messy], searchText: "主线 细节").map(\.content),
            [" 主线\n\n推进\t细节 "]
        )
    }

    func testCleanOutgoingContentCollapsesWhitespaceAndSkipsBlank() {
        let service = ChatHistoryService()

        XCTAssertEqual(service.cleanOutgoingContent("  推进\n主线\t任务  "), "推进 主线 任务")
        XCTAssertTrue(service.cleanOutgoingContent(" \n\t ").isEmpty)
    }
}
