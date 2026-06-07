import SwiftData
import SwiftUI

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

    private let memoryEngine = MemoryEngine()
    private let progressService = QuestProgressService()
    private let dailyReviewService = DailyReviewService()
    private let chatHistoryService = ChatHistoryService()

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

                Section("数据") {
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
                    - 第一阶段不读取其他 App。
                    - 第一阶段不录音。
                    - 第一阶段不联网。
                    - 第一阶段不接入真实 AI API。
                    - 所有数据仅存在本地 SwiftData。
                    - 后续接入权限时应逐项授权。
                    """)
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
            .onDisappear {
                normalizeEditableProfiles()
                try? modelContext.save()
            }
        }
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
