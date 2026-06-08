import Foundation
import XCTest
@testable import PersonaOS

final class OpenAIClientTests: XCTestCase {
    private var keychainStore: KeychainAPIKeyStore!

    override func setUp() {
        super.setUp()
        keychainStore = KeychainAPIKeyStore(
            service: "com.woshiluozhi.personaos.tests.\(UUID().uuidString)",
            account: "openai-api-key"
        )
    }

    override func tearDown() {
        try? keychainStore.delete()
        keychainStore = nil
        super.tearDown()
    }

    func testKeychainStoreSavesLoadsAndDeletesAPIKey() throws {
        try keychainStore.save("  sk-test-value  ")

        XCTAssertEqual(keychainStore.load(), "sk-test-value")

        try keychainStore.delete()
        XCTAssertNil(keychainStore.load())
    }

    func testKeychainStoreRejectsEmptyAPIKey() {
        XCTAssertThrowsError(try keychainStore.save(" \n\t ")) { error in
            XCTAssertEqual(error as? APIKeyStoreError, .emptyKey)
        }
    }

    func testRequestBodyUsesOnlyEssentialBoundedContext() throws {
        let context = AIRequestContext(
            userName: " 智 ",
            companionName: " 药老 ",
            userLevel: 2,
            currentXP: 120,
            activeQuestTitles: ["主线 1", "主线 2", "主线 3", "主线 4", "主线 5", "主线 6"],
            todayTaskTitles: ["今日 1"],
            completedTodayTaskTitles: ["完成 1"],
            overdueTaskTitles: ["逾期 1"],
            recentMemories: ["记忆 1", "记忆 2", "记忆 3", "记忆 4", "记忆 5", "记忆 6"],
            recentDailyReports: ["复盘 1", "复盘 2", "复盘 3", "复盘 4"]
        )
        let request = try OpenAIRequestBuilder(
            apiKey: "sk-test",
            model: "gpt-5.2",
            endpoint: URL(string: "https://example.com/v1/responses")!
        ).makeRequest(userMessage: "第一条历史不应出现。当前只问：我该做什么", context: context)

        let body = try XCTUnwrap(request.httpBody)
        let bodyString = String(decoding: body, as: UTF8.self)

        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
        XCTAssertTrue(bodyString.contains("\"model\":\"gpt-5.2\""))
        XCTAssertTrue(bodyString.contains("\"store\":false"))
        XCTAssertTrue(bodyString.contains("\"type\":\"json_schema\""))
        XCTAssertTrue(bodyString.contains("\"name\":\"personaos_ai_response\""))
        XCTAssertTrue(bodyString.contains("\"strict\":true"))
        XCTAssertTrue(bodyString.contains("\"additionalProperties\":false"))
        XCTAssertTrue(bodyString.contains("\"assistantMessage\""))
        XCTAssertTrue(bodyString.contains("\"suggestedMemories\""))
        XCTAssertTrue(bodyString.contains("\"suggestedTasks\""))
        XCTAssertTrue(bodyString.contains("\"riskFlags\""))
        XCTAssertFalse(bodyString.contains("\"type\":\"json_object\""))
        XCTAssertTrue(bodyString.contains("我该做什么"))
        XCTAssertTrue(bodyString.contains("记忆 5"))
        XCTAssertFalse(bodyString.contains("记忆 6"))
        XCTAssertTrue(bodyString.contains("复盘 3"))
        XCTAssertFalse(bodyString.contains("复盘 4"))
        XCTAssertTrue(bodyString.contains("主线 1"))
        XCTAssertFalse(bodyString.contains("主线 2"))
    }

    func testResponseParserReadsStructuredAIResponse() throws {
        let json = """
        {
          "output": [
            {
              "content": [
                {
                  "text": "{\\"assistantMessage\\":\\" 先处理主线。 \\", \\"suggestedMemories\\":[\\" 用户重视主线 \\", \\"用户重视主线\\"], \\"suggestedTasks\\":[\\" 完成一个闭环 \\"], \\"riskFlags\\":[\\" overdue_tasks \\"]}"
                }
              ]
            }
          ]
        }
        """

        let response = try OpenAIResponseParser().parse(Data(json.utf8))

        XCTAssertEqual(response.assistantMessage, "先处理主线。")
        XCTAssertEqual(response.suggestedMemories, ["用户重视主线"])
        XCTAssertEqual(response.suggestedTasks, ["完成一个闭环"])
        XCTAssertEqual(response.riskFlags, ["overdue_tasks"])
    }

    func testResponseParserSkipsOutputItemsWithoutText() throws {
        let json = """
        {
          "output": [
            {
              "type": "reasoning"
            },
            {
              "content": [
                {
                  "type": "output_text",
                  "text": "{\\"assistantMessage\\":\\"先把任务闭环。\\",\\"suggestedMemories\\":[],\\"suggestedTasks\\":[\\"完成最小闭环\\"],\\"riskFlags\\":[]}"
                }
              ]
            }
          ]
        }
        """

        let response = try OpenAIResponseParser().parse(Data(json.utf8))

        XCTAssertEqual(response.assistantMessage, "先把任务闭环。")
        XCTAssertEqual(response.suggestedTasks, ["完成最小闭环"])
    }

    func testFallbackClientUsesLocalModeWhenPrimaryFails() async throws {
        let client = FallbackAIClient(
            primary: ThrowingAIClient(),
            fallback: StaticAIClient(response: AIResponse(
                assistantMessage: "先完成今日任务。",
                suggestedMemories: [],
                suggestedTasks: ["完成今日任务"],
                riskFlags: []
            ))
        )

        let response = try await client.sendMessage(userMessage: "我该做什么", context: minimalContext())

        XCTAssertTrue(response.assistantMessage.contains("本地模式"))
        XCTAssertTrue(response.assistantMessage.contains("先完成今日任务"))
        XCTAssertEqual(response.suggestedTasks, ["完成今日任务"])
    }

    func testFactoryFallsBackWhenNoAPIKeyExists() async throws {
        let factory = AIClientFactory(
            keyStore: InMemoryAPIKeyStore(apiKey: nil),
            fallbackClient: StaticAIClient(response: AIResponse(
                assistantMessage: "本地回复",
                suggestedMemories: [],
                suggestedTasks: [],
                riskFlags: []
            ))
        )

        let response = try await factory.makeClient().sendMessage(userMessage: "测试", context: minimalContext())

        XCTAssertTrue(response.assistantMessage.contains("本地模式"))
        XCTAssertTrue(response.assistantMessage.contains("未配置 OpenAI API Key"))
    }

    private func minimalContext() -> AIRequestContext {
        AIRequestContext(
            userName: "智",
            companionName: "药老",
            userLevel: 1,
            currentXP: 0,
            activeQuestTitles: ["构建 PersonaOS"],
            todayTaskTitles: ["完成真实 AI 对话"],
            completedTodayTaskTitles: [],
            overdueTaskTitles: [],
            recentMemories: [],
            recentDailyReports: []
        )
    }
}

private struct ThrowingAIClient: AIClientProtocol {
    func sendMessage(userMessage: String, context: AIRequestContext) async throws -> AIResponse {
        throw OpenAIClientError.httpStatus(401)
    }
}

private struct StaticAIClient: AIClientProtocol {
    let response: AIResponse

    func sendMessage(userMessage: String, context: AIRequestContext) async throws -> AIResponse {
        response
    }
}

private final class InMemoryAPIKeyStore: APIKeyStore {
    private var apiKey: String?

    init(apiKey: String?) {
        self.apiKey = apiKey
    }

    func save(_ apiKey: String) throws {
        self.apiKey = apiKey
    }

    func load() -> String? {
        apiKey
    }

    func delete() throws {
        apiKey = nil
    }
}
