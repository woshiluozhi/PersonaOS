import SwiftData
import SwiftUI

struct QuestListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var tasks: [TaskItem]
    @Query private var users: [UserProfile]
    @Query private var quests: [Quest]

    @State private var showingAddTask = false
    @State private var showingAddQuest = false
    @State private var taskScope: TaskScope = .all
    @State private var taskSearchText = ""
    @State private var editingTask: TaskItem?
    @State private var editingQuest: Quest?
    @State private var tasksPendingDeletion: [TaskItem] = []

    private let service = QuestProgressService()

    private var scopedTasksBeforeSearch: [TaskItem] {
        service.tasks(from: tasks, matching: taskScope, quests: quests)
    }

    private var scopedTasks: [TaskItem] {
        service.searchTasks(scopedTasksBeforeSearch, searchText: taskSearchText, quests: quests)
    }

    private var isSearchingTasks: Bool {
        !taskSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var incompleteTasks: [TaskItem] {
        service.sortedIncompleteTasksForAction(scopedTasks)
    }

    private var completedTasks: [TaskItem] {
        service.recentlyCompletedTasks(scopedTasks)
    }

    private var taskSummary: TaskCollectionSummary {
        service.taskSummary(for: scopedTasks)
    }

    private var activeQuests: [Quest] {
        service.activeQuests(from: quests)
    }

    private var closedQuests: [Quest] {
        service.closedQuests(from: quests)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("任务线") {
                    if activeQuests.isEmpty {
                        Text("暂无进行中的主线或支线。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(activeQuests, id: \.id) { quest in
                            QuestRow(
                                quest: quest,
                                progress: service.questProgress(for: quest, tasks: tasks),
                                onComplete: { updateQuest(quest, status: .completed) },
                                onArchive: { updateQuest(quest, status: .archived) },
                                onEdit: { editingQuest = quest }
                            )
                        }
                    }
                }

                Section {
                    Picker("任务范围", selection: $taskScope) {
                        ForEach(TaskScope.allCases) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)

                    TaskSearchField(searchText: $taskSearchText)

                    TaskFilterSummaryRow(
                        scopeTitle: taskScope.title,
                        summary: taskSummary,
                        isSearching: isSearchingTasks
                    )
                }

                Section("未完成") {
                    if incompleteTasks.isEmpty {
                        Text(taskScope == .all ? "暂无未完成任务。" : "当前范围暂无未完成任务。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(incompleteTasks, id: \.id) { task in
                            TaskRow(task: task, questTitle: service.questTitle(for: task, quests: quests), onComplete: {
                                complete(task)
                            }, onReopen: nil, onEdit: {
                                editingTask = task
                            })
                        }
                        .onDelete { offsets in
                            queueDelete(offsets: offsets, from: incompleteTasks)
                        }
                    }
                }

                Section("已完成") {
                    if completedTasks.isEmpty {
                        Text(taskScope == .all ? "完成一项任务后会出现在这里。" : "当前范围暂无已完成任务。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(completedTasks, id: \.id) { task in
                            TaskRow(task: task, questTitle: service.questTitle(for: task, quests: quests), onComplete: nil, onReopen: {
                                reopen(task)
                            }, onEdit: {
                                editingTask = task
                            })
                        }
                        .onDelete { offsets in
                            queueDelete(offsets: offsets, from: completedTasks)
                        }
                    }
                }

                if !closedQuests.isEmpty {
                    Section("已关闭任务线") {
                        ForEach(closedQuests, id: \.id) { quest in
                            QuestRow(
                                quest: quest,
                                progress: service.questProgress(for: quest, tasks: tasks),
                                onComplete: nil,
                                onArchive: { updateQuest(quest, status: .active) },
                                onEdit: { editingQuest = quest }
                            )
                        }
                    }
                }
            }
            .navigationTitle("任务")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingAddTask = true
                        } label: {
                            Label("新增任务", systemImage: "checkmark.circle")
                        }

                        Button {
                            showingAddQuest = true
                        } label: {
                            Label("新增任务线", systemImage: "flag")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新增")
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskSheet()
            }
            .sheet(isPresented: $showingAddQuest) {
                AddQuestSheet()
            }
            .sheet(isPresented: editingTaskSheetPresented) {
                if let editingTask {
                    EditTaskSheet(task: editingTask)
                }
            }
            .sheet(isPresented: editingQuestSheetPresented) {
                if let editingQuest {
                    EditQuestSheet(quest: editingQuest)
                }
            }
            .confirmationDialog(
                "删除任务",
                isPresented: Binding(
                    get: { !tasksPendingDeletion.isEmpty },
                    set: { isPresented in
                        if !isPresented {
                            tasksPendingDeletion = []
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button(service.taskDeleteConfirmationTitle(for: tasksPendingDeletion), role: .destructive) {
                    deletePendingTasks()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text(service.taskDeleteConfirmationMessage(for: tasksPendingDeletion))
            }
        }
    }

    private var editingTaskSheetPresented: Binding<Bool> {
        Binding(
            get: { editingTask != nil },
            set: { isPresented in
                if !isPresented {
                    editingTask = nil
                }
            }
        )
    }

    private var editingQuestSheetPresented: Binding<Bool> {
        Binding(
            get: { editingQuest != nil },
            set: { isPresented in
                if !isPresented {
                    editingQuest = nil
                }
            }
        )
    }

    private func complete(_ task: TaskItem) {
        let user = users.first ?? UserProfile()
        if users.first == nil {
            modelContext.insert(user)
        }
        service.completeTask(task, user: user)
        try? modelContext.save()
    }

    private func reopen(_ task: TaskItem) {
        let user = users.first ?? UserProfile()
        if users.first == nil {
            modelContext.insert(user)
        }
        service.reopenTask(task, user: user)
        try? modelContext.save()
    }

    private func queueDelete(offsets: IndexSet, from source: [TaskItem]) {
        tasksPendingDeletion = offsets.map { source[$0] }
    }

    private func deletePendingTasks() {
        for task in tasksPendingDeletion {
            modelContext.delete(task)
        }
        try? modelContext.save()
        tasksPendingDeletion = []
    }

    private func updateQuest(_ quest: Quest, status: QuestStatus) {
        service.updateQuest(quest, status: status)
        try? modelContext.save()
    }
}

private struct TaskSearchField: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜索标题、细节、任务线、状态、XP、日期", text: $searchText)
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("清空任务搜索")
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct TaskFilterSummaryRow: View {
    let scopeTitle: String
    let summary: TaskCollectionSummary
    let isSearching: Bool

    private var title: String {
        let baseTitle = scopeTitle == "全部" ? "全部任务" : "\(scopeTitle)范围"
        return isSearching ? "\(baseTitle) · 搜索结果" : baseTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "line.3.horizontal.decrease.circle")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                TaskFilterMetric(title: "总计", value: summary.totalCount, systemImage: "list.bullet")
                TaskFilterMetric(title: "未完成", value: summary.incompleteCount, systemImage: "circle")
                TaskFilterMetric(title: "已完成", value: summary.completedCount, systemImage: "checkmark.circle")
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TaskFilterMetric: View {
    let title: String
    let value: Int
    let systemImage: String

    var body: some View {
        Label {
            Text("\(value) \(title)")
                .font(.caption)
                .monospacedDigit()
        } icon: {
            Image(systemName: systemImage)
        }
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

private struct QuestRow: View {
    let quest: Quest
    let progress: QuestTaskProgress
    let onComplete: (() -> Void)?
    let onArchive: (() -> Void)?
    let onEdit: (() -> Void)?

    private let service = QuestProgressService()

    private var displayDetail: String {
        service.displayQuestDetail(for: quest)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(service.displayQuestTypeTitle(for: quest.questType))
                    .font(.caption.bold())
                    .foregroundStyle(typeColor(quest.questType))
                Text(service.displayQuestStatusTitle(for: quest.status))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("P\(QuestPriorityBounds.clamped(quest.priority))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(service.displayQuestTitle(for: quest))
                .font(.headline)

            if !displayDetail.isEmpty {
                Text(displayDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if progress.hasTasks {
                ProgressView(value: progress.completionRate)
                Text(progress.summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("尚未关联任务")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if let onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("编辑任务线")
                }

                if let onComplete {
                    Button("完成任务线", action: onComplete)
                        .buttonStyle(.bordered)
                }

                if let onArchive {
                    Button(quest.status == QuestStatus.active.rawValue ? "归档" : "重新激活", action: onArchive)
                        .buttonStyle(.bordered)
                }

                NavigationLink {
                    QuestDetailView(quest: quest)
                } label: {
                    Label("查看详情", systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 6)
    }

    private func typeColor(_ rawValue: String) -> Color {
        switch QuestType(rawValue: rawValue) {
        case .main:
            return .red
        case .side:
            return .purple
        case .daily:
            return .blue
        case .none:
            return .secondary
        }
    }
}

private struct QuestDetailView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var tasks: [TaskItem]
    @Query private var users: [UserProfile]
    @Query private var quests: [Quest]
    @Query private var reports: [DailyReport]

    let quest: Quest

    @State private var showingAddTask = false
    @State private var showingEditQuest = false
    @State private var editingTask: TaskItem?
    @State private var tasksPendingDeletion: [TaskItem] = []

    private let service = QuestProgressService()
    private let reviewService = DailyReviewService()

    private var relatedTasks: [TaskItem] {
        service
            .tasks(for: quest, from: tasks)
            .sorted { lhs, rhs in
                if lhs.isCompleted == rhs.isCompleted {
                    return lhs.createdAt > rhs.createdAt
                }
                return !lhs.isCompleted && rhs.isCompleted
            }
    }

    private var incompleteTasks: [TaskItem] {
        service.sortedIncompleteTasksForAction(relatedTasks)
    }

    private var completedTasks: [TaskItem] {
        service.recentlyCompletedTasks(relatedTasks)
    }

    private var progress: QuestTaskProgress {
        service.questProgress(for: quest, tasks: tasks)
    }

    private var recentProgress: QuestRecentProgress {
        service.recentProgress(for: quest, tasks: tasks)
    }

    private var relatedReports: [DailyReport] {
        reviewService.reports(relatedTo: quest, from: reports)
    }

    private var displayDetail: String {
        service.displayQuestDetail(for: quest)
    }

    var body: some View {
        List {
            Section("概览") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(service.displayQuestTypeTitle(for: quest.questType))
                            .font(.caption.bold())
                            .foregroundStyle(typeColor(quest.questType))
                        Text(service.displayQuestStatusTitle(for: quest.status))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("P\(QuestPriorityBounds.clamped(quest.priority))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !displayDetail.isEmpty {
                        Text(displayDetail)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: progress.completionRate)
                    Text(progress.summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("最近推进") {
                QuestRecentProgressView(progress: recentProgress)
            }

            Section("关联复盘") {
                if relatedReports.isEmpty {
                    Text("暂无提到这条任务线的日报。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(relatedReports.prefix(3)), id: \.id) { report in
                        QuestRelatedReportRow(report: report)
                    }

                    if relatedReports.count > 3 {
                        Text("仅显示最近 3 条相关日报。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("未完成") {
                if incompleteTasks.isEmpty {
                    Text("这条任务线暂无未完成任务。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(incompleteTasks, id: \.id) { task in
                        TaskRow(
                            task: task,
                            questTitle: service.questTitle(for: task, quests: quests),
                            onComplete: { complete(task) },
                            onReopen: nil,
                            onEdit: { editingTask = task }
                        )
                    }
                    .onDelete { offsets in
                        queueDelete(offsets: offsets, from: incompleteTasks)
                    }
                }
            }

            Section("已完成") {
                if completedTasks.isEmpty {
                    Text("完成关联任务后会出现在这里。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(completedTasks, id: \.id) { task in
                        TaskRow(
                            task: task,
                            questTitle: service.questTitle(for: task, quests: quests),
                            onComplete: nil,
                            onReopen: { reopen(task) },
                            onEdit: { editingTask = task }
                        )
                    }
                    .onDelete { offsets in
                        queueDelete(offsets: offsets, from: completedTasks)
                    }
                }
            }
        }
        .navigationTitle(service.displayQuestTitle(for: quest))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingEditQuest = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("编辑任务线")

                Button {
                    showingAddTask = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("新增关联任务")
            }
        }
        .sheet(isPresented: $showingEditQuest) {
            EditQuestSheet(quest: quest)
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskSheet(
                initialTaskType: QuestType(rawValue: quest.questType) ?? .daily,
                pinnedQuestID: quest.id
            )
        }
        .sheet(isPresented: editingTaskSheetPresented) {
            if let editingTask {
                EditTaskSheet(task: editingTask)
            }
        }
        .confirmationDialog(
            "删除任务",
            isPresented: Binding(
                get: { !tasksPendingDeletion.isEmpty },
                set: { isPresented in
                    if !isPresented {
                        tasksPendingDeletion = []
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(service.taskDeleteConfirmationTitle(for: tasksPendingDeletion), role: .destructive) {
                deletePendingTasks()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(service.taskDeleteConfirmationMessage(for: tasksPendingDeletion))
        }
    }

    private var editingTaskSheetPresented: Binding<Bool> {
        Binding(
            get: { editingTask != nil },
            set: { isPresented in
                if !isPresented {
                    editingTask = nil
                }
            }
        )
    }

    private func complete(_ task: TaskItem) {
        let user = users.first ?? UserProfile()
        if users.first == nil {
            modelContext.insert(user)
        }
        service.completeTask(task, user: user)
        try? modelContext.save()
    }

    private func reopen(_ task: TaskItem) {
        let user = users.first ?? UserProfile()
        if users.first == nil {
            modelContext.insert(user)
        }
        service.reopenTask(task, user: user)
        try? modelContext.save()
    }

    private func queueDelete(offsets: IndexSet, from source: [TaskItem]) {
        tasksPendingDeletion = offsets.map { source[$0] }
    }

    private func deletePendingTasks() {
        for task in tasksPendingDeletion {
            modelContext.delete(task)
        }
        try? modelContext.save()
        tasksPendingDeletion = []
    }

    private func typeColor(_ rawValue: String) -> Color {
        switch QuestType(rawValue: rawValue) {
        case .main:
            return .red
        case .side:
            return .purple
        case .daily:
            return .blue
        case .none:
            return .secondary
        }
    }
}

private struct QuestRelatedReportRow: View {
    let report: DailyReport

    private let service = DailyReviewService()

    private var metrics: DailyReportMetrics {
        service.metrics(for: report)
    }

    private var displayComment: String {
        service.displayComment(for: report)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(PersonaDate.displayDate(report.date))
                    .font(.subheadline.bold())
                Spacer()
                Text(metrics.xpGainedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(service.displaySummary(for: report))
                .font(.subheadline)
                .lineLimit(3)

            if !displayComment.isEmpty {
                Text(displayComment)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct QuestRecentProgressView: View {
    let progress: QuestRecentProgress

    var body: some View {
        if progress.totalCompletedCount == 0 {
            Text("最近 7 天暂无完成记录。")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    Label(progress.totalCompletedCountText, systemImage: "checkmark.circle")
                    Label(progress.totalXPGainedText, systemImage: "bolt")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(progress.dayProgress, id: \.date) { dayProgress in
                        QuestProgressBar(
                            dayProgress: dayProgress,
                            maxCompletedCount: maxCompletedCount
                        )
                    }
                }
                .frame(height: 94)
                .accessibilityElement(children: .combine)
            }
            .padding(.vertical, 4)
        }
    }

    private var maxCompletedCount: Int {
        max(1, progress.dayProgress.map(\.displayCompletedCount).max() ?? 1)
    }
}

private struct QuestProgressBar: View {
    let dayProgress: QuestDayProgress
    let maxCompletedCount: Int

    var body: some View {
        VStack(spacing: 6) {
            Text("\(dayProgress.displayCompletedCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            GeometryReader { proxy in
                let ratio = Double(dayProgress.displayCompletedCount) / Double(maxCompletedCount)
                let filledHeight = max(dayProgress.displayCompletedCount == 0 ? 2 : 6, proxy.size.height * ratio)

                ZStack(alignment: .bottom) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.16))

                    Capsule()
                        .fill(dayProgress.displayCompletedCount == 0 ? Color.secondary.opacity(0.35) : Color.accentColor)
                        .frame(height: filledHeight)
                }
            }
            .frame(height: 48)

            Text(PersonaDate.shortWeekday(dayProgress.date))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(PersonaDate.displayDate(dayProgress.date))，\(dayProgress.completionSummaryText)，\(dayProgress.xpGainedText)")
    }
}

private struct TaskRow: View {
    let task: TaskItem
    let questTitle: String?
    let onComplete: (() -> Void)?
    let onReopen: (() -> Void)?
    let onEdit: (() -> Void)?

    private let service = QuestProgressService()

    private var displayDetail: String {
        service.displayTaskDetail(for: task)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(service.displayTaskTypeTitle(for: task.taskType))
                        .font(.caption.bold())
                        .foregroundStyle(typeColor(task.taskType))
                    Text(service.displayTaskXPRewardText(for: task))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(service.displayTaskTitle(for: task))
                    .font(.headline)

                if !displayDetail.isEmpty {
                    Text(displayDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let questTitle {
                    Text("任务线：\(questTitle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let dueDate = task.dueDate {
                    Label {
                        Text("到期：\(PersonaDate.relativeDayTitle(dueDate)) · \(PersonaDate.displayDate(dueDate))")
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(.caption)
                    .foregroundStyle(dueDateColor(for: dueDate))
                }

                if task.isCompleted {
                    Label {
                        Text("完成：\(PersonaDate.relativeDayTitle(completionDisplayDate)) · \(PersonaDate.displayDate(completionDisplayDate))")
                    } icon: {
                        Image(systemName: "checkmark.seal")
                    }
                    .font(.caption)
                    .foregroundStyle(.green)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if let onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("编辑任务")
                }

                if let onComplete {
                    Button(action: onComplete) {
                        Image(systemName: "checkmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("完成任务")
                } else if let onReopen {
                    Button(action: onReopen) {
                        Image(systemName: "arrow.uturn.backward.circle")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("撤回完成")
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func dueDateColor(for dueDate: Date) -> Color {
        guard !task.isCompleted else {
            return .secondary
        }

        let calendar = Calendar.current
        let dueDay = calendar.startOfDay(for: dueDate)
        let today = calendar.startOfDay(for: Date())

        if dueDay < today {
            return .red
        }

        if dueDay == today {
            return .orange
        }

        return .secondary
    }

    private var completionDisplayDate: Date {
        task.completedAt ?? task.dueDate ?? task.createdAt
    }

    private func typeColor(_ rawValue: String) -> Color {
        switch QuestType(rawValue: rawValue) {
        case .main:
            return .red
        case .side:
            return .purple
        case .daily:
            return .blue
        case .none:
            return .secondary
        }
    }
}

private enum TaskXPRewardBounds {
    static let range = 0...100

    static func clamped(_ reward: Int) -> Int {
        min(max(reward, range.lowerBound), range.upperBound)
    }
}

private enum QuestPriorityBounds {
    static let range = 1...10

    static func clamped(_ priority: Int) -> Int {
        min(max(priority, range.lowerBound), range.upperBound)
    }
}

struct AddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var quests: [Quest]
    @Query private var tasks: [TaskItem]

    private let pinnedQuestID: UUID?
    private let service = QuestProgressService()

    @State private var title = ""
    @State private var detail = ""
    @State private var taskType: QuestType = .daily
    @State private var questAssignment = TaskQuestAssignment.createNew
    @State private var xpReward = 20
    @State private var dueMode: TaskDueMode = .today
    @State private var customDueDate = Date()

    private var cleanedTitle: String {
        service.cleanTaskTitle(title)
    }

    private var isDuplicateOpenTask: Bool {
        service.hasOpenTask(titled: cleanedTitle, in: tasks)
    }

    private var isDuplicateTodayTask: Bool {
        guard wouldAppearInTodayScope else {
            return false
        }
        return service.hasTodayTask(titled: cleanedTitle, in: tasks)
    }

    private var duplicateWarning: String? {
        if isDuplicateOpenTask {
            return "已有同名未完成任务"
        }

        if isDuplicateTodayTask {
            return "今天已有同名任务"
        }

        return nil
    }

    private var canSave: Bool {
        !cleanedTitle.isEmpty && duplicateWarning == nil
    }

    init(initialTaskType: QuestType = .daily, pinnedQuestID: UUID? = nil) {
        self.pinnedQuestID = pinnedQuestID
        _taskType = State(initialValue: initialTaskType)
        _questAssignment = State(
            initialValue: pinnedQuestID?.uuidString ?? (
                initialTaskType == .daily ? TaskQuestAssignment.none : TaskQuestAssignment.createNew
            )
        )
    }

    private var canAssignQuest: Bool {
        pinnedQuestID != nil || taskType == .main || taskType == .side || !activeQuestsForAssignment.isEmpty
    }

    private var pinnedQuest: Quest? {
        guard let pinnedQuestID else {
            return nil
        }
        return quests.first { $0.id == pinnedQuestID }
    }

    private var activeQuestsForAssignment: [Quest] {
        service.assignableQuests(for: taskType, from: quests)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("任务") {
                    TextField("标题", text: $title)
                    TextField("细节", text: $detail, axis: .vertical)
                        .lineLimit(2...4)
                    if let duplicateWarning {
                        Label(duplicateWarning, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Picker("类型", selection: $taskType) {
                        ForEach(QuestType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }

                    Stepper("XP 奖励：\(xpReward)", value: $xpReward, in: TaskXPRewardBounds.range, step: 5)

                    Picker("到期", selection: $dueMode) {
                        ForEach(TaskDueMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    if dueMode == .custom {
                        DatePicker("日期", selection: $customDueDate, displayedComponents: .date)
                    }
                }

                if canAssignQuest {
                    Section("归属任务线") {
                        if let pinnedQuestID {
                            LabeledContent(
                                "任务线",
                                value: pinnedQuest.map { service.displayQuestTitle(for: $0) } ?? "当前任务线"
                            )
                            Text("此任务会固定加入当前任务线。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .onAppear {
                                    questAssignment = pinnedQuestID.uuidString
                                }
                        } else {
                            Picker("任务线", selection: $questAssignment) {
                                if canCreateQuestForTaskType {
                                    Text("创建同名任务线").tag(TaskQuestAssignment.createNew)
                                }
                                Text("不归属任务线").tag(TaskQuestAssignment.none)

                                ForEach(activeQuestsForAssignment, id: \.id) { quest in
                                    Text(service.displayQuestTitle(for: quest)).tag(quest.id.uuidString)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("新增任务")
            .onChange(of: taskType) {
                if let pinnedQuestID {
                    questAssignment = pinnedQuestID.uuidString
                } else {
                    questAssignment = canCreateQuestForTaskType ? TaskQuestAssignment.createNew : TaskQuestAssignment.none
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let questId = resolveQuestId(title: cleanedTitle, detail: trimmedDetail)
        let task = TaskItem(
            title: cleanedTitle,
            detail: trimmedDetail,
            taskType: taskType.rawValue,
            questId: questId,
            xpReward: TaskXPRewardBounds.clamped(xpReward),
            dueDate: dueDate
        )

        modelContext.insert(task)

        try? modelContext.save()
        dismiss()
    }

    private func resolveQuestId(title: String, detail: String) -> UUID? {
        if let pinnedQuestID {
            return pinnedQuestID
        }

        guard canAssignQuest else {
            return nil
        }

        if questAssignment == TaskQuestAssignment.none {
            return nil
        }

        if questAssignment == TaskQuestAssignment.createNew {
            guard canCreateQuestForTaskType else {
                return nil
            }

            if let existingQuest = service.activeQuest(titled: title, ofType: taskType, in: quests) {
                return existingQuest.id
            }

            let quest = Quest(
                title: title,
                detail: detail,
                questType: taskType.rawValue,
                status: QuestStatus.active.rawValue,
                priority: taskType == .main ? 3 : 5
            )
            modelContext.insert(quest)
            return quest.id
        }

        return UUID(uuidString: questAssignment)
    }

    private var canCreateQuestForTaskType: Bool {
        taskType == .main || taskType == .side
    }

    private var wouldAppearInTodayScope: Bool {
        if taskType == .daily {
            return true
        }

        guard let dueDate else {
            return false
        }

        return Calendar.current.isDate(dueDate, inSameDayAs: Date())
    }

    private var dueDate: Date? {
        switch dueMode {
        case .none:
            return nil
        case .today:
            return Date()
        case .custom:
            return customDueDate
        }
    }
}

private struct EditTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var quests: [Quest]
    @Query private var tasks: [TaskItem]

    private let task: TaskItem
    private let service = QuestProgressService()

    @State private var title: String
    @State private var detail: String
    @State private var taskType: QuestType
    @State private var questAssignment: String
    @State private var xpReward: Int
    @State private var dueMode: TaskDueMode
    @State private var customDueDate: Date

    init(task: TaskItem) {
        self.task = task
        _title = State(initialValue: task.title)
        _detail = State(initialValue: task.detail)
        _taskType = State(initialValue: QuestType(rawValue: task.taskType) ?? .daily)
        _questAssignment = State(initialValue: task.questId?.uuidString ?? TaskQuestAssignment.none)
        _xpReward = State(initialValue: TaskXPRewardBounds.clamped(task.xpReward))

        if let dueDate = task.dueDate {
            _dueMode = State(initialValue: .custom)
            _customDueDate = State(initialValue: dueDate)
        } else {
            _dueMode = State(initialValue: .none)
            _customDueDate = State(initialValue: Date())
        }
    }

    private var cleanedTitle: String {
        service.cleanTaskTitle(title)
    }

    private var isDuplicateOpenTask: Bool {
        guard !task.isCompleted else {
            return false
        }
        return service.hasOpenTask(titled: cleanedTitle, excluding: task.id, in: tasks)
    }

    private var isDuplicateTodayTask: Bool {
        guard wouldAppearInTodayScope else {
            return false
        }
        return service.hasTodayTask(titled: cleanedTitle, excluding: task.id, in: tasks)
    }

    private var duplicateWarning: String? {
        if isDuplicateOpenTask {
            return "已有同名未完成任务"
        }

        if isDuplicateTodayTask {
            return "今天已有同名任务"
        }

        return nil
    }

    private var canSave: Bool {
        !cleanedTitle.isEmpty && duplicateWarning == nil
    }

    private var selectableQuests: [Quest] {
        service.selectableQuests(for: taskType, currentQuestID: task.questId, from: quests)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("任务") {
                    TextField("标题", text: $title)
                    TextField("细节", text: $detail, axis: .vertical)
                        .lineLimit(2...4)
                    if let duplicateWarning {
                        Label(duplicateWarning, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Picker("类型", selection: $taskType) {
                        ForEach(QuestType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }

                    Stepper("XP 奖励：\(xpReward)", value: $xpReward, in: TaskXPRewardBounds.range, step: 5)

                    Picker("到期", selection: $dueMode) {
                        ForEach(TaskDueMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    if dueMode == .custom {
                        DatePicker("日期", selection: $customDueDate, displayedComponents: .date)
                    }
                }

                Section("归属任务线") {
                    Picker("任务线", selection: $questAssignment) {
                        Text("不归属任务线").tag(TaskQuestAssignment.none)

                        ForEach(selectableQuests, id: \.id) { quest in
                            Text(service.displayQuestTitle(for: quest)).tag(quest.id.uuidString)
                        }
                    }
                }
            }
            .onChange(of: taskType) {
                clearInvalidQuestAssignment()
            }
            .navigationTitle("编辑任务")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        task.title = cleanedTitle
        task.detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        task.taskType = taskType.rawValue
        task.questId = questAssignment == TaskQuestAssignment.none ? nil : UUID(uuidString: questAssignment)
        task.xpReward = TaskXPRewardBounds.clamped(xpReward)
        task.dueDate = dueDate

        try? modelContext.save()
        dismiss()
    }

    private func clearInvalidQuestAssignment() {
        guard questAssignment != TaskQuestAssignment.none else {
            return
        }

        let assignableIDs = Set(service.assignableQuests(for: taskType, from: quests).map { $0.id.uuidString })
        if !assignableIDs.contains(questAssignment) {
            questAssignment = TaskQuestAssignment.none
        }
    }

    private var wouldAppearInTodayScope: Bool {
        if taskType == .daily {
            return true
        }

        if let dueDate, Calendar.current.isDate(dueDate, inSameDayAs: Date()) {
            return true
        }

        if task.isCompleted, let completedAt = task.completedAt {
            return Calendar.current.isDate(completedAt, inSameDayAs: Date())
        }

        return false
    }

    private var dueDate: Date? {
        switch dueMode {
        case .none:
            return nil
        case .today:
            return Date()
        case .custom:
            return customDueDate
        }
    }
}

private enum TaskQuestAssignment {
    static let createNew = "create_new"
    static let none = "none"
}

private enum TaskDueMode: String, CaseIterable, Identifiable {
    case none
    case today
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "无"
        case .today:
            return "今天"
        case .custom:
            return "自选"
        }
    }
}

private struct AddQuestSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var quests: [Quest]

    private let service = QuestProgressService()

    @State private var title = ""
    @State private var detail = ""
    @State private var questType: QuestType = .main
    @State private var priority = 3

    private var cleanedTitle: String {
        service.cleanQuestTitle(title)
    }

    private var duplicateWarning: String? {
        if service.hasActiveQuest(titled: cleanedTitle, ofType: questType, in: quests) {
            return "已有同名进行中任务线"
        }

        return nil
    }

    private var canSave: Bool {
        !cleanedTitle.isEmpty && duplicateWarning == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("任务线") {
                    TextField("标题", text: $title)
                    TextField("细节", text: $detail, axis: .vertical)
                        .lineLimit(2...5)
                    if let duplicateWarning {
                        Label(duplicateWarning, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Picker("类型", selection: $questType) {
                        Text(QuestType.main.title).tag(QuestType.main)
                        Text(QuestType.side.title).tag(QuestType.side)
                    }

                    Stepper("优先级：\(priority)", value: $priority, in: QuestPriorityBounds.range)
                }
            }
            .navigationTitle("新增任务线")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let quest = Quest(
            title: cleanedTitle,
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            questType: questType.rawValue,
            status: QuestStatus.active.rawValue,
            priority: QuestPriorityBounds.clamped(priority)
        )
        modelContext.insert(quest)
        try? modelContext.save()
        dismiss()
    }
}

private struct EditQuestSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var quests: [Quest]

    private let quest: Quest
    private let service = QuestProgressService()

    @State private var title: String
    @State private var detail: String
    @State private var questType: QuestType
    @State private var status: QuestStatus
    @State private var priority: Int

    init(quest: Quest) {
        self.quest = quest
        _title = State(initialValue: quest.title)
        _detail = State(initialValue: quest.detail)
        _questType = State(initialValue: QuestType(rawValue: quest.questType) ?? .main)
        _status = State(initialValue: QuestStatus(rawValue: quest.status) ?? .active)
        _priority = State(initialValue: QuestPriorityBounds.clamped(quest.priority))
    }

    private var cleanedTitle: String {
        service.cleanQuestTitle(title)
    }

    private var duplicateWarning: String? {
        guard status == .active else {
            return nil
        }

        if service.hasActiveQuest(titled: cleanedTitle, ofType: questType, excluding: quest.id, in: quests) {
            return "已有同名进行中任务线"
        }

        return nil
    }

    private var canSave: Bool {
        !cleanedTitle.isEmpty && duplicateWarning == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("任务线") {
                    TextField("标题", text: $title)
                    TextField("细节", text: $detail, axis: .vertical)
                        .lineLimit(2...5)
                    if let duplicateWarning {
                        Label(duplicateWarning, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Picker("类型", selection: $questType) {
                        Text(QuestType.main.title).tag(QuestType.main)
                        Text(QuestType.side.title).tag(QuestType.side)
                    }

                    Picker("状态", selection: $status) {
                        ForEach(QuestStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }

                    Stepper("优先级：\(priority)", value: $priority, in: QuestPriorityBounds.range)
                }
            }
            .navigationTitle("编辑任务线")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        quest.title = cleanedTitle
        quest.detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        quest.questType = questType.rawValue
        quest.status = status.rawValue
        quest.priority = QuestPriorityBounds.clamped(priority)
        quest.updatedAt = Date()

        try? modelContext.save()
        dismiss()
    }
}
