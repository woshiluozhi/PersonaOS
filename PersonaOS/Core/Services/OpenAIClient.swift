import Foundation

enum OpenAIClientError: Error, Equatable {
    case invalidRequest
    case invalidResponse
    case httpStatus(Int)
    case emptyAssistantMessage
}

struct OpenAIClient: AIClientProtocol {
    let apiKey: String
    var model: String = "gpt-5.2"
    var endpoint: URL = URL(string: "https://api.openai.com/v1/responses")!
    var session: URLSession = .shared

    func sendMessage(userMessage: String, context: AIRequestContext) async throws -> AIResponse {
        let request = try OpenAIRequestBuilder(
            apiKey: apiKey,
            model: model,
            endpoint: endpoint
        ).makeRequest(userMessage: userMessage, context: context)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OpenAIClientError.httpStatus(httpResponse.statusCode)
        }

        return try OpenAIResponseParser().parse(data)
    }
}

struct OpenAIRequestBuilder {
    let apiKey: String
    let model: String
    let endpoint: URL

    func makeRequest(userMessage: String, context: AIRequestContext) throws -> URLRequest {
        let cleanedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedKey.isEmpty else {
            throw APIKeyStoreError.emptyKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(cleanedKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 45
        request.httpBody = try JSONEncoder().encode(makePayload(userMessage: userMessage, context: context))
        return request
    }

    func makePayload(userMessage: String, context: AIRequestContext) -> OpenAIResponsesRequest {
        OpenAIResponsesRequest(
            model: model,
            input: [
                .system(systemInstructions),
                .user(contextPrompt(userMessage: userMessage, context: context))
            ],
            text: OpenAITextConfig(format: OpenAITextFormat.jsonObject)
        )
    }

    private var systemInstructions: String {
        """
        你是 PersonaOS 里的“药老”：冷静、直接、长期主义、不盲目迎合。你的任务不是陪聊，而是把用户的话落成行动、风险判断和可确认的长期记忆。

        只根据本次提供的必要上下文回答，不要声称读取了其他 App、录音、定位、健康、日历或完整聊天历史。
        不要替用户自动确认记忆、创建任务或删除数据，只能提出建议。

        必须只输出 JSON object，字段固定为：
        {
          "assistantMessage": "给用户看的中文回复",
          "suggestedMemories": ["可选，适合作为候选记忆的短句"],
          "suggestedTasks": ["可选，今天能执行的任务标题"],
          "riskFlags": ["可选，例如 overdue_tasks, scope_creep, unclear_main_quest"]
        }
        """
    }

    private func contextPrompt(userMessage: String, context: AIRequestContext) -> String {
        let snapshot = EssentialAIContextSnapshot(context: context)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let snapshotData = (try? encoder.encode(snapshot)) ?? Data()
        let snapshotJSON = String(decoding: snapshotData, as: UTF8.self)

        return """
        用户消息：
        \(cleanedText(userMessage))

        必要上下文 JSON：
        \(snapshotJSON)
        """
    }

    private func cleanedText(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

struct OpenAIResponsesRequest: Encodable, Equatable {
    var model: String
    var input: [OpenAIInputMessage]
    var text: OpenAITextConfig
}

enum OpenAIInputMessage: Encodable, Equatable {
    case system(String)
    case user(String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .system(let content):
            try container.encode("system", forKey: .role)
            try container.encode(content, forKey: .content)
        case .user(let content):
            try container.encode("user", forKey: .role)
            try container.encode(content, forKey: .content)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case role
        case content
    }
}

struct OpenAITextConfig: Encodable, Equatable {
    var format: OpenAITextFormat
}

struct OpenAITextFormat: Encodable, Equatable {
    static let jsonObject = OpenAITextFormat(type: "json_object")

    var type: String
}

struct EssentialAIContextSnapshot: Encodable, Equatable {
    var userName: String
    var companionName: String
    var userLevel: Int
    var currentXP: Int
    var activeQuestTitles: [String]
    var todayTaskTitles: [String]
    var completedTodayTaskTitles: [String]
    var overdueTaskTitles: [String]
    var recentMemories: [String]
    var recentDailyReports: [String]

    init(context: AIRequestContext) {
        userName = Self.cleaned(context.userName, fallback: "智")
        companionName = Self.cleaned(context.companionName, fallback: "药老")
        userLevel = max(context.userLevel, 1)
        currentXP = max(context.currentXP, 0)
        activeQuestTitles = Self.cleanedItems(context.activeQuestTitles, limit: 5)
        todayTaskTitles = Self.cleanedItems(context.todayTaskTitles, limit: 12)
        completedTodayTaskTitles = Self.cleanedItems(context.completedTodayTaskTitles, limit: 12)
        overdueTaskTitles = Self.cleanedItems(context.overdueTaskTitles, limit: 8)
        recentMemories = Self.cleanedItems(context.recentMemories, limit: 5)
        recentDailyReports = Self.cleanedItems(context.recentDailyReports, limit: 3)
    }

    private static func cleaned(_ text: String, fallback: String) -> String {
        let cleaned = cleanedText(text)
        return cleaned.isEmpty ? fallback : cleaned
    }

    private static func cleanedItems(_ items: [String], limit: Int) -> [String] {
        Array(
            items
                .map(cleanedText)
                .filter { !$0.isEmpty }
                .prefix(limit)
        )
    }

    private static func cleanedText(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

struct OpenAIResponseParser {
    func parse(_ data: Data) throws -> AIResponse {
        let response = try JSONDecoder().decode(OpenAIResponsesResponse.self, from: data)
        guard let outputText = response.outputText else {
            throw OpenAIClientError.invalidResponse
        }

        let aiResponseData = Data(outputText.utf8)
        let decoded = try JSONDecoder().decode(AIResponsePayload.self, from: aiResponseData)
        let assistantMessage = cleanedText(decoded.assistantMessage)
        guard !assistantMessage.isEmpty else {
            throw OpenAIClientError.emptyAssistantMessage
        }

        return AIResponse(
            assistantMessage: assistantMessage,
            suggestedMemories: cleanedItems(decoded.suggestedMemories),
            suggestedTasks: cleanedItems(decoded.suggestedTasks),
            riskFlags: cleanedItems(decoded.riskFlags)
        )
    }

    private func cleanedItems(_ items: [String]) -> [String] {
        var seen: Set<String> = []
        var cleanedItems: [String] = []

        for item in items {
            let cleaned = cleanedText(item)
            let key = cleaned.lowercased()
            guard !cleaned.isEmpty, !seen.contains(key) else {
                continue
            }
            seen.insert(key)
            cleanedItems.append(cleaned)
        }

        return cleanedItems
    }

    private func cleanedText(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

private struct OpenAIResponsesResponse: Decodable {
    var output: [OpenAIOutputItem]?
    var directOutputText: String?

    var outputText: String? {
        if let directOutputText, !directOutputText.isEmpty {
            return directOutputText
        }

        return output?
            .flatMap(\.content)
            .compactMap(\.text)
            .first
    }

    private enum CodingKeys: String, CodingKey {
        case output
        case directOutputText = "output_text"
    }
}

private struct OpenAIOutputItem: Decodable {
    var content: [OpenAIOutputContent]
}

private struct OpenAIOutputContent: Decodable {
    var text: String?
}

private struct AIResponsePayload: Decodable {
    var assistantMessage: String
    var suggestedMemories: [String]
    var suggestedTasks: [String]
    var riskFlags: [String]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        assistantMessage = try container.decode(String.self, forKey: .assistantMessage)
        suggestedMemories = try container.decodeIfPresent([String].self, forKey: .suggestedMemories) ?? []
        suggestedTasks = try container.decodeIfPresent([String].self, forKey: .suggestedTasks) ?? []
        riskFlags = try container.decodeIfPresent([String].self, forKey: .riskFlags) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case assistantMessage
        case suggestedMemories
        case suggestedTasks
        case riskFlags
    }
}

struct AIClientFactory {
    var keyStore: APIKeyStore = KeychainAPIKeyStore()
    var model: String = "gpt-5.2"
    var session: URLSession = .shared
    var fallbackClient: AIClientProtocol = MockAIClient()

    func makeClient() -> AIClientProtocol {
        guard let apiKey = keyStore.load(), !apiKey.isEmpty else {
            return LocalModeAIClient(
                wrapped: fallbackClient,
                reason: "未配置 OpenAI API Key"
            )
        }

        let openAIClient = OpenAIClient(apiKey: apiKey, model: model, session: session)
        return FallbackAIClient(primary: openAIClient, fallback: fallbackClient)
    }
}

struct LocalModeAIClient: AIClientProtocol {
    let wrapped: AIClientProtocol
    let reason: String

    func sendMessage(userMessage: String, context: AIRequestContext) async throws -> AIResponse {
        var response = try await wrapped.sendMessage(userMessage: userMessage, context: context)
        response.assistantMessage = "本地模式（\(reason)）：\(response.assistantMessage)"
        return response
    }
}

struct FallbackAIClient: AIClientProtocol {
    let primary: AIClientProtocol
    let fallback: AIClientProtocol

    func sendMessage(userMessage: String, context: AIRequestContext) async throws -> AIResponse {
        do {
            return try await primary.sendMessage(userMessage: userMessage, context: context)
        } catch {
            var response = try await fallback.sendMessage(userMessage: userMessage, context: context)
            response.assistantMessage = "本地模式（真实 AI 暂不可用）：\(response.assistantMessage)"
            return response
        }
    }
}
