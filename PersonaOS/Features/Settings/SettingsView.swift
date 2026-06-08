import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var users: [UserProfile]
    @Query private var companions: [CompanionPersona]
    @Query private var quests: [Quest]
    @Query private var tasks: [TaskItem]
    @Query private var memories: [MemoryRecord]
    @Query private var reports: [DailyReport]
    @Query private var messages: [ChatMessage]

    @State private var pendingDestructiveAction: DestructiveAction?
    @State private var actionResult: SettingsActionResult?
    @State private var apiKeyInput = ""
    @State private var hasStoredAPIKey = false
    @State private var isTestingAIConnection = false
    @State private var isPresentingDataExporter = false
    @State private var exportDocument = PersonaOSExportDocument(data: Data())
    @State private var exportFilename = "personaos-export.json"

    private let memoryEngine = MemoryEngine()
    private let progressService = QuestProgressService()
    private let dailyReviewService = DailyReviewService()
    private let chatHistoryService = ChatHistoryService()
    private let apiKeyStore = KeychainAPIKeyStore()
    private let exportService = LocalDataExportService()

    private var questSummary: QuestCollectionSummary {
        progressService.questSummary(for: quests)
    }

    private var visibleQuestCount: Int {
        questSummary.totalCount
    }

    private var activeQuestCount: Int {
        questSummary.activeCount
    }

    private var closedQuestCount: Int {
        questSummary.closedCount
    }

    private var taskSummary: TaskCollectionSummary {
        progressService.taskSummary(for: tasks)
    }

    private var visibleTaskCount: Int {
        taskSummary.totalCount
    }

    private var completedTaskCount: Int {
        taskSummary.completedCount
    }

    private var openTaskCount: Int {
        taskSummary.incompleteCount
    }

    private var todayTaskCount: Int {
        progressService.todayTasks(from: tasks).count
    }

    private var overdueTaskCount: Int {
        progressService.overdueTasks(from: tasks).count
    }

    private var memorySummary: MemoryCollectionSummary {
        memoryEngine.summary(for: memories)
    }

    private var confirmedMemoryCount: Int {
        memorySummary.confirmedCount
    }

    private var candidateMemoryCount: Int {
        memorySummary.candidateCount
    }

    private var dismissedMemoryCount: Int {
        memorySummary.dismissedCount
    }

    private var visibleMemoryCount: Int {
        memorySummary.totalCount
    }

    private var visibleMessageCount: Int {
        chatHistoryService.sortedMessages(messages).count
    }

    private var reportSummary: DailyReviewCollectionSummary {
        dailyReviewService.summary(from: reports)
    }

    private var reportCount: Int {
        reportSummary.reportCount
    }

    private var reportCompletionRateText: String {
        reportSummary.completionPercentText
    }

    private var hasExportableLocalData: Bool {
        !users.isEmpty ||
            !companions.isEmpty ||
            !quests.isEmpty ||
            !tasks.isEmpty ||
            !memories.isEmpty ||
            !reports.isEmpty ||
            !messages.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("本地数据") {
                    LabeledContent("任务线", value: "\(visibleQuestCount)")
                    LabeledContent("进行中任务线", value: "\(activeQuestCount)")
                    LabeledContent("已关闭任务线", value: "\(closedQuestCount)")
                    LabeledContent("任务", value: "\(visibleTaskCount)")
                    LabeledContent("今日任务", value: "\(todayTaskCount)")
                    LabeledContent("未完成任务", value: "\(openTaskCount)")
                    LabeledContent("已完成任务", value: "\(completedTaskCount)")
                    LabeledContent("逾期任务", value: "\(overdueTaskCount)")
                    LabeledContent("记忆", value: "\(visibleMemoryCount)")
                    LabeledContent("已确认记忆", value: "\(confirmedMemoryCount)")
                    LabeledContent("候选记忆", value: "\(candidateMemoryCount)")
                    LabeledContent("已忽略记忆", value: "\(dismissedMemoryCount)")
                    LabeledContent("日报", value: "\(reportCount)")
                    LabeledContent("日报 XP", value: reportSummary.totalXPGainedText)
                    LabeledContent("日报完成率", value: reportCompletionRateText)
                    LabeledContent("聊天", value: "\(visibleMessageCount)")
                }

                Section("用户") {
                    if let user = users.first {
                        TextField("用户名称", text: binding(user, \.name))
                        Stepper("精力 \(clampedProfileStat(user.energy))", value: binding(user, \.energy), in: 0...100)
                        Stepper("专注 \(clampedProfileStat(user.focus))", value: binding(user, \.focus), in: 0...100)
                        Stepper("压力 \(clampedProfileStat(user.stress))", value: binding(user, \.stress), in: 0...100)
                    } else {
                        Button("创建默认用户") {
                            createDefaultUser()
                        }
                    }
                }

                Section("药老") {
                    if let companion = companions.first {
                        TextField("助手名称", text: binding(companion, \.name))
                        TextField("风格描述", text: binding(companion, \.styleDescription), axis: .vertical)
                            .lineLimit(2...4)
                        TextField("语气", text: binding(companion, \.voiceStyle))
                        Stepper("严格 \(clampedCompanionLevel(companion.strictnessLevel))", value: binding(companion, \.strictnessLevel), in: 0...10)
                        Stepper("温度 \(clampedCompanionLevel(companion.warmthLevel))", value: binding(companion, \.warmthLevel), in: 0...10)
                    } else {
                        Button("创建默认助手") {
                            createDefaultCompanion()
                        }
                    }
                }

                Section("AI 模式") {
                    LabeledContent("当前模式", value: hasStoredAPIKey ? "真实 AI" : "本地模式")

                    SecureField("OpenAI API Key", text: $apiKeyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HStack {
                        Button("保存 Key") {
                            saveAPIKey()
                        }
                        .disabled(cleanedAPIKeyInput.isEmpty)

                        Button("删除 Key", role: .destructive) {
                            deleteAPIKey()
                        }
                        .disabled(!hasStoredAPIKey)
                    }

                    Button {
                        Task {
                            await testAIConnection()
                        }
                    } label: {
                        if isTestingAIConnection {
                            Label("测试中", systemImage: "hourglass")
                        } else {
                            Label("测试连接", systemImage: "bolt.horizontal.circle")
                        }
                    }
                    .disabled(isTestingAIConnection || (!hasStoredAPIKey && cleanedAPIKeyInput.isEmpty))

                    Text("Key 只保存在本机 Keychain。开启真实 AI 后，对话会发送必要上下文到 OpenAI。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("数据") {
                    Button {
                        prepareDataExport()
                    } label: {
                        Label("导出本地数据", systemImage: "square.and.arrow.up")
                    }
                    .disabled(!hasExportableLocalData)

                    Text("导出内容只包含本机 SwiftData 数据，不包含 Keychain 中的 OpenAI API Key。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("重置演示数据", role: .destructive) {
                        pendingDestructiveAction = .resetDemoData
                    }

                    Button("清空聊天记录", role: .destructive) {
                        pendingDestructiveAction = .clearChat
                    }
                    .disabled(messages.isEmpty)

                    Button("清空记忆", role: .destructive) {
                        pendingDestructiveAction = .clearMemories
                    }
                    .disabled(memories.isEmpty)

                    Button("清空日报", role: .destructive) {
                        pendingDestructiveAction = .clearReports
                    }
                    .disabled(reportCount == 0)

                    Button("清理已忽略记忆", role: .destructive) {
                        pendingDestructiveAction = .clearDismissedMemories
                    }
                    .disabled(dismissedMemoryCount == 0)
                }

                Section("隐私说明") {
                    Text("""
                    - 默认不读取其他 App。
                    - 默认不录音、不定位、不接入健康或日历、不后台采集。
                    - 未配置 OpenAI API Key 时，对话只使用本地模式。
                    - 配置 Key 后，对话会把必要上下文发送到 OpenAI：用户/药老设定、当前主线、今日任务、逾期任务、最近确认记忆和近几篇复盘摘要。
                    - API Key 只保存在本机 Keychain，不写入 SwiftData 或日志。
                    - AI 只能提出建议，记忆和任务仍需你点击确认后才会写入本地。
                    """)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section("隐私与审核") {
                    LabeledContent("版本", value: appVersionText)
                    LabeledContent("Bundle ID", value: bundleIdentifierText)
                    LabeledContent("设备方向", value: "iPhone 竖屏")
                    Text("PersonaOS 不包含广告追踪。真实 AI 模式仅在用户主动保存 OpenAI API Key 后启用；无 Key 时保持本地模式。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("支持与隐私政策 URL 需在 App Store Connect 中配置，草案见仓库内 APP_STORE_METADATA.md 与 PRIVACY_POLICY_DRAFT.md。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "确认执行",
                isPresented: Binding(
                    get: { pendingDestructiveAction != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingDestructiveAction = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                if let pendingDestructiveAction {
                    Button(pendingDestructiveAction.confirmationTitle, role: .destructive) {
                        run(pendingDestructiveAction)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                if let pendingDestructiveAction {
                    Text(pendingDestructiveAction.message)
                }
            }
            .alert(item: $actionResult) { result in
                Alert(
                    title: Text(result.title),
                    message: Text(result.message),
                    dismissButton: .default(Text("好"))
                )
            }
            .fileExporter(
                isPresented: $isPresentingDataExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: exportFilename
            ) { result in
                handleDataExportCompletion(result)
            }
            .onDisappear {
                normalizeEditableProfiles()
                try? modelContext.save()
            }
            .onAppear {
                refreshAPIKeyState()
            }
        }
    }

    private var cleanedAPIKeyInput: String {
        apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        switch (version, build) {
        case let (version?, build?):
            return "\(version) (\(build))"
        case let (version?, nil):
            return version
        case let (nil, build?):
            return build
        default:
            return "未知"
        }
    }

    private var bundleIdentifierText: String {
        Bundle.main.bundleIdentifier ?? "未知"
    }

    private func normalizeEditableProfiles() {
        users.first?.normalizeEditableFields()
        companions.first?.normalizeEditableFields()
    }

    private func clampedProfileStat(_ value: Int) -> Int {
        min(max(value, 0), 100)
    }

    private func clampedCompanionLevel(_ value: Int) -> Int {
        min(max(value, 0), 10)
    }

    private func binding(_ user: UserProfile, _ keyPath: ReferenceWritableKeyPath<UserProfile, String>) -> Binding<String> {
        Binding(
            get: { user[keyPath: keyPath] },
            set: {
                user[keyPath: keyPath] = $0
                user.updatedAt = Date()
            }
        )
    }

    private func binding(_ user: UserProfile, _ keyPath: ReferenceWritableKeyPath<UserProfile, Int>) -> Binding<Int> {
        Binding(
            get: { clampedProfileStat(user[keyPath: keyPath]) },
            set: {
                user[keyPath: keyPath] = clampedProfileStat($0)
                user.updatedAt = Date()
            }
        )
    }

    private func binding(_ companion: CompanionPersona, _ keyPath: ReferenceWritableKeyPath<CompanionPersona, String>) -> Binding<String> {
        Binding(
            get: { companion[keyPath: keyPath] },
            set: {
                companion[keyPath: keyPath] = $0
                companion.updatedAt = Date()
            }
        )
    }

    private func binding(_ companion: CompanionPersona, _ keyPath: ReferenceWritableKeyPath<CompanionPersona, Int>) -> Binding<Int> {
        Binding(
            get: { clampedCompanionLevel(companion[keyPath: keyPath]) },
            set: {
                companion[keyPath: keyPath] = clampedCompanionLevel($0)
                companion.updatedAt = Date()
            }
        )
    }

    private func run(_ action: DestructiveAction) {
        let actionFeedback: SettingsActionResult

        switch action {
        case .resetDemoData:
            DemoDataSeeder.resetDemoData(context: modelContext)
            actionFeedback = result(for: action)
        case .clearChat:
            let deletedCount = DemoDataSeeder.clearChat(context: modelContext)
            actionFeedback = result(for: action, deletedCount: deletedCount)
        case .clearMemories:
            let deletedCount = DemoDataSeeder.clearMemories(context: modelContext)
            actionFeedback = result(for: action, deletedCount: deletedCount)
        case .clearReports:
            let deletedCount = DemoDataSeeder.clearReports(context: modelContext)
            actionFeedback = result(for: action, deletedCount: deletedCount)
        case .clearDismissedMemories:
            let deletedCount = memoryEngine.deleteDismissedMemories(memories, context: modelContext)
            try? modelContext.save()
            actionFeedback = result(for: action, deletedCount: deletedCount)
        }

        pendingDestructiveAction = nil
        actionResult = actionFeedback
    }

    private func refreshAPIKeyState() {
        hasStoredAPIKey = apiKeyStore.load() != nil
    }

    private func saveAPIKey() {
        do {
            try apiKeyStore.save(cleanedAPIKeyInput)
            apiKeyInput = ""
            refreshAPIKeyState()
            actionResult = SettingsActionResult(
                title: "已保存",
                message: "OpenAI API Key 已保存到本机 Keychain。"
            )
        } catch APIKeyStoreError.emptyKey {
            actionResult = SettingsActionResult(
                title: "无法保存",
                message: "API Key 不能为空。"
            )
        } catch {
            actionResult = SettingsActionResult(
                title: "无法保存",
                message: "Keychain 写入失败：\(error.localizedDescription)"
            )
        }
    }

    private func deleteAPIKey() {
        do {
            try apiKeyStore.delete()
            apiKeyInput = ""
            refreshAPIKeyState()
            actionResult = SettingsActionResult(
                title: "已删除",
                message: "OpenAI API Key 已从本机 Keychain 删除。"
            )
        } catch {
            actionResult = SettingsActionResult(
                title: "无法删除",
                message: "Keychain 删除失败：\(error.localizedDescription)"
            )
        }
    }

    @MainActor
    private func testAIConnection() async {
        guard !isTestingAIConnection else {
            return
        }

        let apiKey = cleanedAPIKeyInput.isEmpty ? apiKeyStore.load() : cleanedAPIKeyInput
        guard let apiKey, !apiKey.isEmpty else {
            actionResult = SettingsActionResult(
                title: "无法测试",
                message: "请先填写或保存 OpenAI API Key。"
            )
            return
        }

        isTestingAIConnection = true
        defer {
            isTestingAIConnection = false
        }

        do {
            _ = try await OpenAIClient(apiKey: apiKey).sendMessage(
                userMessage: "连接测试",
                context: testConnectionContext()
            )
            actionResult = SettingsActionResult(
                title: "连接成功",
                message: "真实 AI 模式可用。"
            )
        } catch {
            actionResult = SettingsActionResult(
                title: "连接失败",
                message: "暂时无法连接 OpenAI；对话页仍会自动回退本地模式。"
            )
        }
    }

    private func testConnectionContext() -> AIRequestContext {
        AIRequestContext(
            userName: users.first?.name ?? "智",
            companionName: companions.first?.name ?? "药老",
            userLevel: users.first?.level ?? 1,
            currentXP: users.first?.currentXP ?? 0,
            activeQuestTitles: progressService.activeQuests(from: quests).prefix(3).map {
                progressService.displayQuestTitle(for: $0)
            },
            todayTaskTitles: progressService.actionOrderedTodayTasks(from: tasks).prefix(5).map {
                progressService.displayTaskTitle(for: $0)
            },
            completedTodayTaskTitles: [],
            overdueTaskTitles: progressService.actionOrderedOverdueTasks(from: tasks).prefix(3).map {
                progressService.displayTaskTitle(for: $0)
            },
            recentMemories: memoryEngine.queryMemories(memories, confirmedOnly: true).prefix(3).map {
                memoryEngine.displayContent(for: $0)
            },
            recentDailyReports: reviewContext(limit: 2)
        )
    }

    private func reviewContext(limit: Int) -> [String] {
        Array(
            dailyReviewService.sortedReportsNewestFirst(reports)
                .compactMap { report -> String? in
                    let contextText = dailyReviewService.contextText(for: report)
                    return contextText.isEmpty ? nil : contextText
                }
                .prefix(limit)
        )
    }

    private func prepareDataExport() {
        let exportedAt = Date()

        do {
            let data = try exportService.makeExportData(
                users: users,
                companions: companions,
                quests: quests,
                tasks: tasks,
                memories: memories,
                reports: reports,
                messages: messages,
                exportedAt: exportedAt
            )
            exportDocument = PersonaOSExportDocument(data: data)
            exportFilename = exportService.suggestedFilename(exportedAt: exportedAt)
            isPresentingDataExporter = true
        } catch {
            actionResult = SettingsActionResult(
                title: "无法导出",
                message: "本地数据导出失败：\(error.localizedDescription)"
            )
        }
    }

    private func handleDataExportCompletion(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            actionResult = SettingsActionResult(
                title: "已导出",
                message: "本地数据 JSON 已交给系统文件导出器处理。"
            )
        case .failure(let error):
            actionResult = SettingsActionResult(
                title: "导出失败",
                message: error.localizedDescription
            )
        }
    }

    private func createDefaultUser() {
        modelContext.insert(UserProfile())
        try? modelContext.save()
        actionResult = SettingsActionResult(
            title: "已创建",
            message: "默认用户已创建。"
        )
    }

    private func createDefaultCompanion() {
        modelContext.insert(CompanionPersona())
        try? modelContext.save()
        actionResult = SettingsActionResult(
            title: "已创建",
            message: "默认助手已创建。"
        )
    }

    private func result(for action: DestructiveAction, deletedCount: Int? = nil) -> SettingsActionResult {
        switch action {
        case .resetDemoData:
            return SettingsActionResult(
                title: "已重置",
                message: "演示数据已恢复为默认用户、助手、任务线、任务、记忆和昨日复盘。"
            )
        case .clearChat:
            return SettingsActionResult(
                title: "已清空",
                message: "已删除 \(deletedCount ?? messages.count) 条聊天记录。"
            )
        case .clearMemories:
            return SettingsActionResult(
                title: "已清空",
                message: "已删除 \(deletedCount ?? memories.count) 条记忆。"
            )
        case .clearReports:
            return SettingsActionResult(
                title: "已清空",
                message: "已删除 \(deletedCount ?? reports.count) 篇日报。"
            )
        case .clearDismissedMemories:
            return SettingsActionResult(
                title: "已清理",
                message: "已删除 \(deletedCount ?? dismissedMemoryCount) 条已忽略记忆。"
            )
        }
    }
}

private struct PersonaOSExportDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.json]
    }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct SettingsActionResult: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private enum DestructiveAction: String, Identifiable {
    case resetDemoData
    case clearChat
    case clearMemories
    case clearReports
    case clearDismissedMemories

    var id: String { rawValue }

    var confirmationTitle: String {
        switch self {
        case .resetDemoData:
            return "重置演示数据"
        case .clearChat:
            return "清空聊天记录"
        case .clearMemories:
            return "清空记忆"
        case .clearReports:
            return "清空日报"
        case .clearDismissedMemories:
            return "清理已忽略记忆"
        }
    }

    var message: String {
        switch self {
        case .resetDemoData:
            return "这会删除当前本地数据并重新插入 PersonaOS 演示数据。"
        case .clearChat:
            return "这会删除所有本地聊天记录，但不会删除任务、记忆或日报。"
        case .clearMemories:
            return "这会删除所有本地长期记忆，包括已确认和未确认记忆。"
        case .clearReports:
            return "这会删除所有本地每日复盘日报，但不会删除任务、记忆或聊天记录。"
        case .clearDismissedMemories:
            return "这只会删除已经标记为忽略的记忆，不会影响已确认或候选记忆。"
        }
    }
}
