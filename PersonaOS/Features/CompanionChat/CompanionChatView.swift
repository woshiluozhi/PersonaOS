import SwiftData
import SwiftUI

struct CompanionChatView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var users: [UserProfile]
    @Query private var companions: [CompanionPersona]
    @Query private var tasks: [TaskItem]
    @Query private var quests: [Quest]
    @Query private var memories: [MemoryRecord]
    @Query private var reports: [DailyReport]
    @Query private var messages: [ChatMessage]

    @State private var inputText = ""
    @State private var isSending = false
    @State private var suggestedMemories: [String] = []
    @State private var suggestedTasks: [String] = []
    @State private var riskFlags: [String] = []
    @State private var messageRoleFilter: ChatHistoryRoleFilter = .all
    @State private var searchText = ""
    @State private var sendTask: Task<Void, Never>?

    private let aiClientFactory = AIClientFactory()
    private let chatHistoryService = ChatHistoryService()
    private let suggestionSanitizer = AISuggestionSanitizer()
    private let memoryEngine = MemoryEngine()
    private let progressService = QuestProgressService()
    private let reviewService = DailyReviewService()

    private var sortedMessages: [ChatMessage] {
        chatHistoryService.sortedMessages(messages)
    }

    private var displayedMessages: [ChatMessage] {
        chatHistoryService.filterMessages(
            messages,
            roleFilter: messageRoleFilter,
            searchText: searchText
        )
    }

    private var displayedMessageIDs: [UUID] {
        displayedMessages.map(\.id)
    }

    private var companionDisplayName: String {
        progressService.displayName(companions.first?.name, fallback: "药老")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ChatHistoryFilterBar(
                    roleFilter: $messageRoleFilter,
                    searchText: $searchText,
                    totalCount: sortedMessages.count,
                    displayedCount: displayedMessages.count
                )

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if sortedMessages.isEmpty {
                                EmptyChatView()
                            } else if displayedMessages.isEmpty {
                                EmptyChatSearchResultView {
                                    messageRoleFilter = .all
                                    searchText = ""
                                }
                            } else {
                                ForEach(displayedMessages, id: \.id) { message in
                                    ChatBubble(
                                        message: message,
                                        content: chatHistoryService.displayContent(for: message),
                                        senderTitle: chatHistoryService.senderTitle(
                                            for: message,
                                            userName: users.first?.name,
                                            companionName: companions.first?.name
                                        ),
                                        isUser: chatHistoryService.isUserMessage(message)
                                    )
                                        .id(message.id)
                                }
                            }

                            if !suggestedMemories.isEmpty {
                                SuggestedMemoryPanel(
                                    memories: suggestedMemories,
                                    onSave: saveCandidateMemory
                                )
                            }

                            if !suggestedTasks.isEmpty {
                                SuggestedTaskPanel(
                                    tasks: suggestedTasks,
                                    onSave: saveSuggestedTask
                                )
                            }

                            if !riskFlags.isEmpty {
                                InsightPanel(
                                    title: "风险提示",
                                    systemImage: "exclamationmark.triangle",
                                    items: riskFlags.map { suggestionSanitizer.riskTitle(for: $0) },
                                    tint: .orange
                                )
                            }

                            if isSending {
                                ChatLoadingView(companionName: companionDisplayName)
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                    .onChange(of: displayedMessageIDs) {
                        scrollToLastMessage(using: proxy)
                    }
                    .onAppear {
                        DispatchQueue.main.async {
                            scrollToLastMessage(using: proxy, animated: false)
                        }
                    }
                }

                Divider()

                QuickPromptBar(isDisabled: isSending) { prompt in
                    startSending(prompt)
                }

                HStack(spacing: 10) {
                    TextField("对药老说一句具体的话", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)

                    if isSending {
                        Button {
                            cancelSending()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("取消回复")
                    } else {
                        Button {
                            startSending(inputText)
                        } label: {
                            Image(systemName: "paperplane.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(chatHistoryService.cleanOutgoingContent(inputText).isEmpty)
                        .accessibilityLabel("发送")
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle(companionDisplayName)
            .onDisappear {
                cancelSending()
            }
        }
    }

    @MainActor
    private func startSending(_ rawText: String) {
        guard !isSending else {
            return
        }

        let text = chatHistoryService.cleanOutgoingContent(rawText)
        guard !text.isEmpty else {
            return
        }

        sendTask = Task {
            await sendMessage(text)
        }
    }

    @MainActor
    private func cancelSending() {
        sendTask?.cancel()
        sendTask = nil
        isSending = false
    }

    @MainActor
    private func sendMessage(_ rawText: String) async {
        let text = chatHistoryService.cleanOutgoingContent(rawText)
        guard !text.isEmpty else {
            return
        }
        guard !isSending else {
            return
        }

        inputText = ""
        isSending = true
        defer {
            isSending = false
            sendTask = nil
        }

        suggestedMemories = []
        suggestedTasks = []
        riskFlags = []

        let userMessage = ChatMessage(role: ChatRole.user.rawValue, content: text)
        modelContext.insert(userMessage)

        do {
            let aiClient = aiClientFactory.makeClient()
            let response = try await aiClient.sendMessage(userMessage: text, context: makeContext())
            guard !Task.isCancelled else {
                try? modelContext.save()
                return
            }

            let assistantMessage = ChatMessage(
                role: ChatRole.assistant.rawValue,
                content: response.assistantMessage
            )
            modelContext.insert(assistantMessage)
            suggestedMemories = suggestionSanitizer.cleanedUniqueItems(response.suggestedMemories)
                .filter { !isDuplicateSuggestedMemory($0) }
            suggestedTasks = suggestionSanitizer.cleanedUniqueItems(response.suggestedTasks)
                .filter { !isDuplicateSuggestedTask(titled: $0) }
            riskFlags = suggestionSanitizer.cleanedUniqueItems(response.riskFlags)
        } catch {
            if error is CancellationError {
                let cancelledMessage = ChatMessage(
                    role: ChatRole.system.rawValue,
                    content: "已取消本次回复。"
                )
                modelContext.insert(cancelledMessage)
                try? modelContext.save()
                return
            }

            let fallback = ChatMessage(
                role: ChatRole.assistant.rawValue,
                content: "本地模拟回复失败：\(error.localizedDescription)"
            )
            modelContext.insert(fallback)
        }

        try? modelContext.save()
    }

    private func makeContext() -> AIRequestContext {
        let user = users.first
        let companion = companions.first
        let now = Date()
        let todayTasks = progressService.actionOrderedTodayTasks(from: tasks, date: now)
        let overdueTasks = progressService.actionOrderedOverdueTasks(from: tasks, date: now)
        let completedToday = todayTasks.filter {
            progressService.isTaskCompleted($0, on: now)
        }
        let todayContextTasks = todayTasks.filter { task in
            !task.isCompleted || progressService.isTaskCompleted(task, on: now)
        }
        let sortedMemories = memoryEngine.queryMemories(memories, confirmedOnly: true)
        let recentReportContext = reviewService.sortedReportsNewestFirst(reports)
            .compactMap { report -> String? in
                let contextText = reviewService.contextText(for: report)
                return contextText.isEmpty ? nil : contextText
            }

        return AIRequestContext(
            userName: progressService.displayName(user?.name, fallback: "智"),
            companionName: progressService.displayName(companion?.name, fallback: "药老"),
            userLevel: user?.level ?? 1,
            currentXP: user?.currentXP ?? 0,
            activeQuestTitles: progressService.activeQuests(from: quests).map {
                progressService.displayQuestTitle(for: $0)
            },
            todayTaskTitles: todayContextTasks.map {
                progressService.displayTaskTitle(for: $0)
            },
            completedTodayTaskTitles: completedToday.map {
                progressService.displayTaskTitle(for: $0)
            },
            overdueTaskTitles: overdueTasks.map {
                progressService.displayTaskTitle(for: $0)
            },
            recentMemories: Array(sortedMemories.prefix(5)).map {
                memoryEngine.displayContent(for: $0)
            },
            recentDailyReports: Array(recentReportContext.prefix(3))
        )
    }

    private func saveCandidateMemory(_ text: String) {
        let cleanedText = suggestionSanitizer.clean(text)
        guard !cleanedText.isEmpty else {
            removeSuggestedMemory(matching: text)
            return
        }

        guard !isDuplicateSuggestedMemory(cleanedText) else {
            removeSuggestedMemory(matching: text)
            return
        }

        let memory = memoryEngine.makeCandidateMemory(from: cleanedText, source: "chat")
        modelContext.insert(memory)
        try? modelContext.save()
        removeSuggestedMemory(matching: text)
    }

    private func saveSuggestedTask(_ title: String) {
        let cleanedTitle = suggestionSanitizer.clean(title)
        guard !cleanedTitle.isEmpty else {
            removeSuggestedTask(matching: title)
            return
        }

        guard !isDuplicateSuggestedTask(titled: cleanedTitle) else {
            removeSuggestedTask(matching: title)
            return
        }

        let currentMainQuest = progressService.currentMainQuest(from: quests)
        let task = TaskItem(
            title: cleanedTitle,
            detail: "由药老建议生成。",
            taskType: QuestType.daily.rawValue,
            questId: currentMainQuest?.id,
            xpReward: 20,
            dueDate: Date()
        )
        modelContext.insert(task)
        try? modelContext.save()
        removeSuggestedTask(matching: title)
    }

    private func removeSuggestedMemory(matching text: String) {
        let key = suggestionSanitizer.normalizedKey(text)
        suggestedMemories.removeAll {
            suggestionSanitizer.normalizedKey($0) == key
        }
    }

    private func removeSuggestedTask(matching title: String) {
        let key = suggestionSanitizer.normalizedKey(title)
        suggestedTasks.removeAll {
            suggestionSanitizer.normalizedKey($0) == key
        }
    }

    private func isDuplicateSuggestedTask(titled title: String) -> Bool {
        progressService.hasOpenTask(titled: title, in: tasks)
            || progressService.hasTodayTask(titled: title, in: tasks)
    }

    private func isDuplicateSuggestedMemory(_ text: String) -> Bool {
        memoryEngine.hasMemory(content: text, in: memories)
    }

    private func scrollToLastMessage(using proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastMessageID = displayedMessageIDs.last else {
            return
        }

        if animated {
            withAnimation {
                proxy.scrollTo(lastMessageID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastMessageID, anchor: .bottom)
        }
    }

}

private struct ChatHistoryFilterBar: View {
    @Binding var roleFilter: ChatHistoryRoleFilter
    @Binding var searchText: String

    let totalCount: Int
    let displayedCount: Int

    private var isFiltering: Bool {
        roleFilter != .all || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var countSummary: String {
        if totalCount == 0 {
            return "还没有对话"
        }
        if isFiltering {
            return "显示 \(displayedCount)/\(totalCount) 条消息"
        }
        return "\(totalCount) 条消息"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("消息角色", selection: $roleFilter) {
                ForEach(ChatHistoryRoleFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索对话、角色、日期", text: $searchText)
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("清空搜索")
                }
            }
            .padding(10)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(countSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }
}

private struct QuickPromptBar: View {
    let isDisabled: Bool
    let onSelect: (String) -> Void

    private let prompts = [
        "我该做什么",
        "我想开新项目",
        "检查风险",
        "总结今天"
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(prompts, id: \.self) { prompt in
                    Button(prompt) {
                        onSelect(prompt)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isDisabled)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
}

private struct EmptyChatView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("药老在听。")
                .font(.headline)
            Text("这里不是客服窗口。你可以问“我该做什么”、说“我想开新项目”、要求“检查风险”或“总结今天”。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct EmptyChatSearchResultView: View {
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("当前筛选下没有消息。")
                .font(.headline)
            Button("清空筛选", action: onClear)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    let content: String
    let senderTitle: String
    let isUser: Bool

    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 40)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(senderTitle)
                    .font(.caption.bold())
                    .foregroundStyle(isUser ? .white.opacity(0.8) : .secondary)
                Text(content)
                    .font(.body)
                    .foregroundStyle(isUser ? .white : .primary)
                Text(PersonaDate.displayTime(message.createdAt))
                    .font(.caption2)
                    .foregroundStyle(isUser ? .white.opacity(0.65) : .secondary)
            }
            .padding(12)
            .background(isUser ? Color.accentColor : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if !isUser {
                Spacer(minLength: 40)
            }
        }
    }
}

private struct ChatLoadingView: View {
    let companionName: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(companionName)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在判断...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer(minLength: 40)
        }
    }
}

private struct SuggestedMemoryPanel: View {
    let memories: [String]
    let onSave: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("候选记忆")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(memories, id: \.self) { memory in
                VStack(alignment: .leading, spacing: 8) {
                    Text(memory)
                        .font(.subheadline)
                    Button {
                        onSave(memory)
                    } label: {
                        Label("存为未确认记忆", systemImage: "tray.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct SuggestedTaskPanel: View {
    let tasks: [String]
    let onSave: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("行动建议", systemImage: "target")
                .font(.caption.bold())
                .foregroundStyle(.blue)

            ForEach(tasks, id: \.self) { task in
                VStack(alignment: .leading, spacing: 8) {
                    Text(task)
                        .font(.subheadline)
                    Button {
                        onSave(task)
                    } label: {
                        Label("加入今日任务", systemImage: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct InsightPanel: View {
    let title: String
    let systemImage: String
    let items: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption.bold())
                .foregroundStyle(tint)

            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
