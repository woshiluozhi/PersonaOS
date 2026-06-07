import Foundation

enum TaskScope: String, CaseIterable, Identifiable {
    case all
    case today
    case overdue
    case main
    case side
    case daily

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .today:
            return "今日"
        case .overdue:
            return "逾期"
        case .main:
            return "主线"
        case .side:
            return "支线"
        case .daily:
            return "每日"
        }
    }
}

struct DashboardData {
    var userName: String
    var companionName: String
    var level: Int
    var currentXP: Int
    var xpToNextLevel: Int
    var energy: Int
    var focus: Int
    var stress: Int
    var todayCompletionRate: Double
    var todayCompletedCount: Int
    var todayTotalCount: Int
    var overdueTaskCount: Int
    var currentMainQuestTitle: String
    var companionComment: String
    var hasTodayReport: Bool
    var todayRecommendation: TodayActionRecommendation
    var todayPlanSummary: TodayPlanSummary

    var todayCompletionPercent: Int {
        Int(todayCompletionRate * 100)
    }

    var todayCompletionPercentText: String {
        "\(todayCompletionPercent)%"
    }

    var currentXPText: String {
        "\(max(0, currentXP)) XP"
    }

    var xpToNextLevelText: String {
        "距下级 \(max(0, xpToNextLevel)) XP"
    }
}

struct TodayPlanSummary: Equatable {
    var totalOpenCount: Int
    var overdueOpenCount: Int
    var mainOpenCount: Int
    var dailyOpenCount: Int
    var availableXP: Int
    var completedXP: Int

    var displayAvailableXP: Int {
        max(0, availableXP)
    }

    var displayCompletedXP: Int {
        min(max(0, completedXP), displayAvailableXP)
    }

    var remainingXP: Int {
        max(0, displayAvailableXP - displayCompletedXP)
    }

    var availableXPText: String {
        "\(displayAvailableXP) XP"
    }

    var completedXPText: String {
        "\(displayCompletedXP) XP"
    }

    var remainingXPText: String {
        "\(remainingXP) XP"
    }

    var scopeSummaryText: String {
        if totalOpenCount == 0 {
            return "今日已清空"
        }

        var parts: [String] = []

        if overdueOpenCount > 0 {
            parts.append("逾期 \(overdueOpenCount)")
        }

        parts.append("未完成 \(totalOpenCount)")
        parts.append("主线 \(mainOpenCount)")
        parts.append("每日 \(dailyOpenCount)")
        return parts.joined(separator: " · ")
    }
}

enum TodayActionRecommendationKind: Equatable {
    case overdue
    case mainQuest
    case daily
    case review
    case noTask
}

struct TodayActionRecommendation: Equatable {
    var kind: TodayActionRecommendationKind
    var title: String
    var detail: String
    var taskTitle: String?

    func actionButtonTitle(hasTodayReport: Bool) -> String {
        switch kind {
        case .review:
            return hasTodayReport ? "更新复盘" : "生成复盘"
        case .noTask:
            return "新增任务"
        case .overdue, .mainQuest, .daily:
            return "查看任务"
        }
    }
}

struct QuestTaskProgress: Equatable {
    var completedCount: Int
    var totalCount: Int

    var displayTotalCount: Int {
        max(0, totalCount)
    }

    var displayCompletedCount: Int {
        min(max(0, completedCount), displayTotalCount)
    }

    var hasTasks: Bool {
        displayTotalCount > 0
    }

    var summaryText: String {
        "关联任务 \(displayCompletedCount)/\(displayTotalCount)"
    }

    var completionRate: Double {
        let safeTotalCount = displayTotalCount
        guard safeTotalCount > 0 else {
            return 0
        }

        return Double(displayCompletedCount) / Double(safeTotalCount)
    }
}

struct QuestDayProgress: Equatable {
    var date: Date
    var completedCount: Int
    var xpGained: Int

    var displayCompletedCount: Int {
        max(0, completedCount)
    }

    var completionSummaryText: String {
        "完成 \(displayCompletedCount) 项"
    }

    var xpGainedText: String {
        "\(max(0, xpGained)) XP"
    }
}

struct QuestRecentProgress: Equatable {
    var dayProgress: [QuestDayProgress]

    var totalCompletedCount: Int {
        dayProgress.reduce(0) { $0 + max(0, $1.completedCount) }
    }

    var totalCompletedCountText: String {
        "\(totalCompletedCount) 项"
    }

    var totalXPGained: Int {
        dayProgress.reduce(0) { $0 + max(0, $1.xpGained) }
    }

    var totalXPGainedText: String {
        "\(totalXPGained) XP"
    }
}

struct TaskCollectionSummary: Equatable {
    var totalCount: Int
    var incompleteCount: Int
    var completedCount: Int
}

struct QuestCollectionSummary: Equatable {
    var totalCount: Int
    var activeCount: Int
    var closedCount: Int
}

struct QuestProgressService {
    func tasks(
        from tasks: [TaskItem],
        matching scope: TaskScope,
        quests: [Quest],
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> [TaskItem] {
        switch scope {
        case .main:
            return tasksLinkedToQuestType(.main, from: tasks, quests: quests)
        case .side:
            return tasksLinkedToQuestType(.side, from: tasks, quests: quests)
        default:
            return self.tasks(from: tasks, matching: scope, date: date, calendar: calendar)
        }
    }

    func tasks(
        from tasks: [TaskItem],
        matching scope: TaskScope,
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> [TaskItem] {
        let visibleTasks = displayableTasks(tasks)
        switch scope {
        case .all:
            return visibleTasks
        case .today:
            return todayTasks(from: visibleTasks, date: date, calendar: calendar)
        case .overdue:
            return overdueTasks(from: visibleTasks, date: date, calendar: calendar)
        case .main:
            return visibleTasks.filter { $0.taskType == QuestType.main.rawValue }
        case .side:
            return visibleTasks.filter { $0.taskType == QuestType.side.rawValue }
        case .daily:
            return visibleTasks.filter { $0.taskType == QuestType.daily.rawValue }
        }
    }

    private func tasksLinkedToQuestType(_ questType: QuestType, from tasks: [TaskItem], quests: [Quest]) -> [TaskItem] {
        let questIds = Set(
            quests
                .filter { $0.questType == questType.rawValue }
                .filter { !displayQuestTitle(for: $0).isEmpty }
                .map(\.id)
        )

        return displayableTasks(tasks).filter { task in
            if task.taskType == questType.rawValue {
                return true
            }

            guard let questId = task.questId else {
                return false
            }

            return questIds.contains(questId)
        }
    }

    func todayTasks(from tasks: [TaskItem], date: Date = Date(), calendar: Calendar = .current) -> [TaskItem] {
        displayableTasks(tasks).filter { task in
            if task.taskType == QuestType.daily.rawValue {
                if !task.isCompleted {
                    return true
                }

                guard let completedAt = task.completedAt else {
                    return true
                }

                return calendar.isDate(completedAt, inSameDayAs: date)
            }

            if let dueDate = task.dueDate, calendar.isDate(dueDate, inSameDayAs: date) {
                return true
            }

            if let completedAt = task.completedAt, calendar.isDate(completedAt, inSameDayAs: date) {
                return true
            }

            return false
        }
    }

    func overdueTasks(from tasks: [TaskItem], date: Date = Date(), calendar: Calendar = .current) -> [TaskItem] {
        let todayStart = calendar.startOfDay(for: date)
        return displayableTasks(tasks).filter { task in
            guard !task.isCompleted, let dueDate = task.dueDate else {
                return false
            }
            return dueDate < todayStart
        }
    }

    func searchTasks(
        _ tasks: [TaskItem],
        searchText: String,
        quests: [Quest] = [],
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> [TaskItem] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchTerms = trimmedSearch
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let searchableTasks = displayableTasks(tasks)
        guard !searchTerms.isEmpty else {
            return searchableTasks
        }

        return searchableTasks.filter { task in
            let questTitle = questTitle(for: task, quests: quests) ?? ""
            let typeTitle = QuestType(rawValue: task.taskType)?.title ?? task.taskType
            let completionTitle = task.isCompleted ? "已完成" : "未完成"
            let xpTitle = displayTaskXPRewardText(for: task)
            var dateMetadata = [
                PersonaDate.displayDate(task.createdAt),
                PersonaDate.relativeDayTitle(task.createdAt, relativeTo: date, calendar: calendar)
            ]

            if let dueDate = task.dueDate {
                dateMetadata.append(PersonaDate.displayDate(dueDate))
                dateMetadata.append(PersonaDate.relativeDayTitle(dueDate, relativeTo: date, calendar: calendar))
            }

            if let completedAt = task.completedAt {
                dateMetadata.append(PersonaDate.displayDate(completedAt))
                dateMetadata.append(PersonaDate.relativeDayTitle(completedAt, relativeTo: date, calendar: calendar))
            }
            let searchableFields = [
                displayTaskTitle(for: task),
                displayTaskDetail(for: task),
                typeTitle,
                questTitle,
                completionTitle,
                xpTitle
            ] + dateMetadata

            return searchTerms.allSatisfy { term in
                searchableFields.contains { $0.localizedCaseInsensitiveContains(term) }
            }
        }
    }

    func sortedIncompleteTasksForAction(
        _ tasks: [TaskItem],
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> [TaskItem] {
        displayableTasks(tasks)
            .filter { !$0.isCompleted }
            .sorted { lhs, rhs in
                let lhsRank = actionSortRank(for: lhs, date: date, calendar: calendar)
                let rhsRank = actionSortRank(for: rhs, date: date, calendar: calendar)

                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }

                switch (lhs.dueDate, rhs.dueDate) {
                case let (lhsDate?, rhsDate?):
                    let lhsDay = calendar.startOfDay(for: lhsDate)
                    let rhsDay = calendar.startOfDay(for: rhsDate)
                    if lhsDay != rhsDay {
                        return lhsDay < rhsDay
                    }
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    break
                }

                let lhsXPReward = normalizedXPReward(for: lhs)
                let rhsXPReward = normalizedXPReward(for: rhs)
                if lhsXPReward != rhsXPReward {
                    return lhsXPReward > rhsXPReward
                }

                return lhs.createdAt > rhs.createdAt
            }
    }

    func actionOrderedTodayTasks(
        from tasks: [TaskItem],
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> [TaskItem] {
        let currentTodayTasks = todayTasks(from: tasks, date: date, calendar: calendar)
        let openTasks = sortedIncompleteTasksForAction(
            currentTodayTasks.filter { !$0.isCompleted },
            date: date,
            calendar: calendar
        )
        let completedTasks = currentTodayTasks
            .filter(\.isCompleted)
            .sorted { lhs, rhs in
                let lhsDate = actionCompletionDate(for: lhs)
                let rhsDate = actionCompletionDate(for: rhs)

                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }

                let lhsXPReward = normalizedXPReward(for: lhs)
                let rhsXPReward = normalizedXPReward(for: rhs)
                if lhsXPReward != rhsXPReward {
                    return lhsXPReward > rhsXPReward
                }

                return lhs.createdAt > rhs.createdAt
            }

        return uniqueTasks(openTasks + completedTasks)
    }

    func actionOrderedOverdueTasks(
        from tasks: [TaskItem],
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> [TaskItem] {
        sortedIncompleteTasksForAction(
            overdueTasks(from: tasks, date: date, calendar: calendar),
            date: date,
            calendar: calendar
        )
    }

    func recentlyCompletedTasks(_ tasks: [TaskItem]) -> [TaskItem] {
        displayableTasks(tasks)
            .filter(\.isCompleted)
            .sorted { lhs, rhs in
                let lhsDate = actionCompletionDate(for: lhs)
                let rhsDate = actionCompletionDate(for: rhs)

                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }

                let lhsXPReward = normalizedXPReward(for: lhs)
                let rhsXPReward = normalizedXPReward(for: rhs)
                if lhsXPReward != rhsXPReward {
                    return lhsXPReward > rhsXPReward
                }

                return lhs.createdAt > rhs.createdAt
            }
    }

    private func actionSortRank(for task: TaskItem, date: Date, calendar: Calendar) -> Int {
        guard !task.isCompleted else {
            return 4
        }

        if let dueDate = task.dueDate {
            let dueDay = calendar.startOfDay(for: dueDate)
            let today = calendar.startOfDay(for: date)

            if dueDay < today {
                return 0
            }

            if dueDay == today {
                return 1
            }

            return 2
        }

        if task.taskType == QuestType.daily.rawValue {
            return 1
        }

        return 3
    }

    private func actionCompletionDate(for task: TaskItem) -> Date {
        task.completedAt ?? task.dueDate ?? task.createdAt
    }

    func isTaskCompleted(_ task: TaskItem, on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard task.isCompleted else {
            return false
        }

        if let completedAt = task.completedAt {
            return calendar.isDate(completedAt, inSameDayAs: date)
        }

        return task.taskType == QuestType.daily.rawValue
    }

    func todayCompletionRate(tasks: [TaskItem], date: Date = Date(), calendar: Calendar = .current) -> Double {
        let todayTasks = todayTasks(from: tasks, date: date, calendar: calendar)
        guard !todayTasks.isEmpty else {
            return 0
        }

        let completedCount = todayTasks.filter { isTaskCompleted($0, on: date, calendar: calendar) }.count
        return Double(completedCount) / Double(todayTasks.count)
    }

    func taskSummary(for tasks: [TaskItem]) -> TaskCollectionSummary {
        let displayableTasks = displayableTasks(tasks)
        let completedCount = displayableTasks.filter(\.isCompleted).count

        return TaskCollectionSummary(
            totalCount: displayableTasks.count,
            incompleteCount: displayableTasks.count - completedCount,
            completedCount: completedCount
        )
    }

    func taskDeleteConfirmationTitle(for tasks: [TaskItem]) -> String {
        tasks.count > 1 ? "删除 \(tasks.count) 项任务" : "删除这项任务"
    }

    func taskDeleteConfirmationMessage(for tasks: [TaskItem]) -> String {
        if tasks.count == 1, let task = tasks.first {
            let title = displayTaskTitle(for: task)
            let displayTitle = title.isEmpty ? "空白任务" : title
            return "这会删除「\(displayTitle)」的本地任务记录。"
        }

        return "这会删除选中的 \(tasks.count) 项本地任务记录。"
    }

    func questSummary(for quests: [Quest]) -> QuestCollectionSummary {
        let displayableQuests = quests.filter { !displayQuestTitle(for: $0).isEmpty }
        let activeCount = displayableQuests
            .filter { $0.status == QuestStatus.active.rawValue }
            .count

        return QuestCollectionSummary(
            totalCount: displayableQuests.count,
            activeCount: activeCount,
            closedCount: displayableQuests.count - activeCount
        )
    }

    func tasks(for quest: Quest, from tasks: [TaskItem]) -> [TaskItem] {
        displayableTasks(tasks).filter { $0.questId == quest.id }
    }

    func questTitle(for task: TaskItem, quests: [Quest]) -> String? {
        guard let questId = task.questId else {
            return nil
        }
        guard let quest = quests.first(where: { $0.id == questId }) else {
            return nil
        }
        let title = displayQuestTitle(for: quest)
        return title.isEmpty ? nil : title
    }

    func assignableQuests(for taskType: QuestType, from quests: [Quest]) -> [Quest] {
        let assignableTypes: Set<String>
        switch taskType {
        case .daily:
            assignableTypes = [QuestType.main.rawValue, QuestType.side.rawValue]
        case .main, .side:
            assignableTypes = [taskType.rawValue]
        }

        return activeQuests(from: quests)
            .filter { assignableTypes.contains($0.questType) }
    }

    func selectableQuests(
        for taskType: QuestType,
        currentQuestID: UUID?,
        from quests: [Quest]
    ) -> [Quest] {
        var seenIDs = Set<UUID>()
        let currentQuest = currentQuestID.flatMap { questID in
            quests.first { $0.id == questID }
        }
        let combinedQuests = assignableQuests(for: taskType, from: quests) + [currentQuest].compactMap { $0 }

        return combinedQuests
            .filter { !displayQuestTitle(for: $0).isEmpty }
            .filter { quest in
                guard !seenIDs.contains(quest.id) else {
                    return false
                }
                seenIDs.insert(quest.id)
                return true
            }
            .sorted(by: questPriorityPrecedes)
    }

    func hasOpenTask(titled title: String, excluding excludedTaskID: UUID? = nil, in tasks: [TaskItem]) -> Bool {
        let normalizedTitle = normalizedTaskTitle(title)
        guard !normalizedTitle.isEmpty else {
            return false
        }

        return tasks.contains { task in
            if let excludedTaskID, task.id == excludedTaskID {
                return false
            }

            return !task.isCompleted && normalizedTaskTitle(task.title) == normalizedTitle
        }
    }

    func hasTodayTask(
        titled title: String,
        excluding excludedTaskID: UUID? = nil,
        in tasks: [TaskItem],
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        let normalizedTitle = normalizedTaskTitle(title)
        guard !normalizedTitle.isEmpty else {
            return false
        }

        return todayTasks(from: tasks, date: date, calendar: calendar).contains { task in
            if let excludedTaskID, task.id == excludedTaskID {
                return false
            }

            return normalizedTaskTitle(task.title) == normalizedTitle
        }
    }

    private func normalizedTaskTitle(_ title: String) -> String {
        title
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    func todayActionRecommendation(
        tasks: [TaskItem],
        quests: [Quest],
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> TodayActionRecommendation {
        if let overdueTask = actionOrderedOverdueTasks(from: tasks, date: date, calendar: calendar).first {
            let overdueTaskTitle = displayTaskTitle(for: overdueTask)
            return TodayActionRecommendation(
                kind: .overdue,
                title: "先清逾期",
                detail: "把「\(overdueTaskTitle)」处理掉。逾期任务会持续吞掉注意力。",
                taskTitle: overdueTaskTitle
            )
        }

        let openTodayTasks = actionOrderedTodayTasks(from: tasks, date: date, calendar: calendar)
            .filter { !$0.isCompleted }

        if let currentMainQuest = currentMainQuest(from: quests),
           let mainTask = openTodayTasks.first(where: { task in
               task.questId == currentMainQuest.id || task.taskType == QuestType.main.rawValue
           }) {
            let mainQuestTitle = displayQuestTitle(for: currentMainQuest)
            let mainTaskTitle = displayTaskTitle(for: mainTask)
            return TodayActionRecommendation(
                kind: .mainQuest,
                title: "推进主线",
                detail: "今天先完成「\(mainTaskTitle)」。它和「\(mainQuestTitle)」直接相关。",
                taskTitle: mainTaskTitle
            )
        }

        if let dailyTask = openTodayTasks.first {
            let dailyTaskTitle = displayTaskTitle(for: dailyTask)
            return TodayActionRecommendation(
                kind: .daily,
                title: "完成今日动作",
                detail: "先完成「\(dailyTaskTitle)」。小闭环比继续规划更有用。",
                taskTitle: dailyTaskTitle
            )
        }

        if !todayTasks(from: tasks, date: date, calendar: calendar).isEmpty {
            return TodayActionRecommendation(
                kind: .review,
                title: "进入复盘",
                detail: "今日任务已闭环。现在记录哪件事真正推进了主线。",
                taskTitle: nil
            )
        }

        return TodayActionRecommendation(
            kind: .noTask,
            title: "写下下一步",
            detail: "今天还没有可执行任务。先定义一个能验收的小动作。",
            taskTitle: nil
        )
    }

    func todayPlanSummary(
        tasks: [TaskItem],
        quests: [Quest],
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> TodayPlanSummary {
        let currentTodayTasks = todayTasks(from: tasks, date: date, calendar: calendar)
        let currentOverdueTasks = overdueTasks(from: tasks, date: date, calendar: calendar)
        let planTasks = uniqueTasks(currentTodayTasks + currentOverdueTasks)
        let openPlanTasks = planTasks.filter { !$0.isCompleted }
        let currentMainQuestID = currentMainQuest(from: quests)?.id
        let mainOpenCount = openPlanTasks.filter { task in
            if task.taskType == QuestType.main.rawValue {
                return true
            }
            return currentMainQuestID.map { task.questId == $0 } ?? false
        }.count
        let dailyOpenCount = openPlanTasks.filter { $0.taskType == QuestType.daily.rawValue }.count
        let completedPlanTasks = planTasks
            .filter { isTaskCompleted($0, on: date, calendar: calendar) }
        let availablePlanTasks = uniqueTasks(openPlanTasks + completedPlanTasks)
        let completedXP = completedPlanTasks
            .reduce(0) { $0 + normalizedXPReward(for: $1) }
        let availableXP = availablePlanTasks.reduce(0) { $0 + normalizedXPReward(for: $1) }

        return TodayPlanSummary(
            totalOpenCount: openPlanTasks.count,
            overdueOpenCount: currentOverdueTasks.count,
            mainOpenCount: mainOpenCount,
            dailyOpenCount: dailyOpenCount,
            availableXP: availableXP,
            completedXP: completedXP
        )
    }

    private func uniqueTasks(_ tasks: [TaskItem]) -> [TaskItem] {
        var seenIDs = Set<UUID>()
        return tasks.filter { task in
            guard !seenIDs.contains(task.id) else {
                return false
            }
            seenIDs.insert(task.id)
            return true
        }
    }

    func questProgress(for quest: Quest, tasks allTasks: [TaskItem]) -> QuestTaskProgress {
        let relatedTasks = tasks(for: quest, from: allTasks)
        return QuestTaskProgress(
            completedCount: relatedTasks.filter(\.isCompleted).count,
            totalCount: relatedTasks.count
        )
    }

    func recentProgress(
        for quest: Quest,
        tasks allTasks: [TaskItem],
        days: Int = 7,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> QuestRecentProgress {
        let safeDays = max(1, days)
        let todayStart = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -(safeDays - 1), to: todayStart) ?? todayStart
        let endDate = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
        let completedTasks = tasks(for: quest, from: allTasks)
            .filter(\.isCompleted)
            .compactMap { task -> (day: Date, xpReward: Int)? in
                let progressDate = task.completedAt ?? task.dueDate ?? task.createdAt
                guard progressDate >= startDate && progressDate < endDate else {
                    return nil
                }
                return (calendar.startOfDay(for: progressDate), normalizedXPReward(for: task))
            }
        let tasksByDay = Dictionary(grouping: completedTasks) { $0.day }
        let dayProgress = (0..<safeDays).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
            let dayTasks = tasksByDay[day] ?? []
            return QuestDayProgress(
                date: day,
                completedCount: dayTasks.count,
                xpGained: dayTasks.reduce(0) { $0 + $1.xpReward }
            )
        }

        return QuestRecentProgress(dayProgress: dayProgress)
    }

    @discardableResult
    func completeTask(_ task: TaskItem, user: UserProfile, completedAt: Date = Date()) -> Int {
        guard !task.isCompleted else {
            if task.completedAt == nil {
                task.completedAt = completedAt
            }
            updateLevel(for: user, now: completedAt)
            return 0
        }

        let reward = normalizedXPReward(for: task)
        task.isCompleted = true
        task.completedAt = completedAt
        user.currentXP += reward
        user.level = level(forXP: user.currentXP)
        user.updatedAt = completedAt
        return reward
    }

    @discardableResult
    func reopenTask(_ task: TaskItem, user: UserProfile, reopenedAt: Date = Date()) -> Int {
        guard task.isCompleted else {
            updateLevel(for: user)
            return 0
        }

        let reward = normalizedXPReward(for: task)
        task.isCompleted = false
        task.completedAt = nil
        user.currentXP = max(0, user.currentXP - reward)
        user.level = level(forXP: user.currentXP)
        user.updatedAt = reopenedAt
        return reward
    }

    func updateLevel(for user: UserProfile, now: Date = Date()) {
        user.level = level(forXP: user.currentXP)
        user.updatedAt = now
    }

    func level(forXP xp: Int) -> Int {
        max(1, xp / 100 + 1)
    }

    func xpToNextLevel(forXP xp: Int) -> Int {
        let normalizedXP = max(0, xp)
        let nextLevelXP = (normalizedXP / 100 + 1) * 100
        return max(0, nextLevelXP - normalizedXP)
    }

    private func normalizedXPReward(for task: TaskItem) -> Int {
        max(0, task.xpReward)
    }

    private func questPriorityPrecedes(_ lhs: Quest, _ rhs: Quest) -> Bool {
        let lhsPriority = normalizedQuestPriority(for: lhs)
        let rhsPriority = normalizedQuestPriority(for: rhs)
        if lhsPriority == rhsPriority {
            return lhs.createdAt < rhs.createdAt
        }
        return lhsPriority < rhsPriority
    }

    private func normalizedQuestPriority(for quest: Quest) -> Int {
        min(max(quest.priority, 1), 10)
    }

    func activeQuests(from quests: [Quest]) -> [Quest] {
        quests
            .filter { $0.status == QuestStatus.active.rawValue }
            .filter { !displayQuestTitle(for: $0).isEmpty }
            .sorted(by: questPriorityPrecedes)
    }

    func closedQuests(from quests: [Quest]) -> [Quest] {
        quests
            .filter { $0.status != QuestStatus.active.rawValue }
            .filter { !displayQuestTitle(for: $0).isEmpty }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func currentMainQuest(from quests: [Quest]) -> Quest? {
        activeQuests(from: quests)
            .first { $0.questType == QuestType.main.rawValue }
    }

    func activeQuest(
        titled title: String,
        ofType questType: QuestType,
        excluding excludedQuestID: UUID? = nil,
        in quests: [Quest]
    ) -> Quest? {
        let normalizedTitle = normalizedTaskTitle(title)
        guard !normalizedTitle.isEmpty else {
            return nil
        }

        return quests.first { quest in
            if let excludedQuestID, quest.id == excludedQuestID {
                return false
            }

            return quest.status == QuestStatus.active.rawValue
                && quest.questType == questType.rawValue
                && normalizedTaskTitle(quest.title) == normalizedTitle
        }
    }

    func hasActiveQuest(
        titled title: String,
        ofType questType: QuestType,
        excluding excludedQuestID: UUID? = nil,
        in quests: [Quest]
    ) -> Bool {
        activeQuest(titled: title, ofType: questType, excluding: excludedQuestID, in: quests) != nil
    }

    func updateQuest(_ quest: Quest, status: QuestStatus, now: Date = Date()) {
        quest.status = status.rawValue
        quest.updatedAt = now
    }

    func makeDashboardData(
        user: UserProfile?,
        companion: CompanionPersona?,
        tasks: [TaskItem],
        quests: [Quest],
        dailyReports: [DailyReport],
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> DashboardData {
        let currentTodayTasks = todayTasks(from: tasks, date: date, calendar: calendar)
        let todayCompletedCount = currentTodayTasks
            .filter { isTaskCompleted($0, on: date, calendar: calendar) }
            .count
        let todayTotalCount = currentTodayTasks.count
        let overdueTaskCount = overdueTasks(from: tasks, date: date, calendar: calendar).count
        let rate = todayTotalCount == 0 ? 0 : Double(todayCompletedCount) / Double(todayTotalCount)
        let mainQuestTitle = currentMainQuest(from: quests).map(displayQuestTitle(for:)) ?? "尚未设定主线"
        let latestReport = dailyReports
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.createdAt > $1.createdAt }
            .first
        let xp = max(0, user?.currentXP ?? 0)

        let fallbackComment = dashboardFallbackComment(for: rate)
        let comment: String
        if let latestReport {
            let reportComment = DailyReviewService().displayComment(for: latestReport)
            comment = reportComment.isEmpty ? fallbackComment : reportComment
        } else {
            comment = fallbackComment
        }

        return DashboardData(
            userName: displayName(user?.name, fallback: "智"),
            companionName: displayName(companion?.name, fallback: "药老"),
            level: level(forXP: xp),
            currentXP: xp,
            xpToNextLevel: xpToNextLevel(forXP: xp),
            energy: clampedProfileStat(user?.energy, fallback: 70),
            focus: clampedProfileStat(user?.focus, fallback: 65),
            stress: clampedProfileStat(user?.stress, fallback: 35),
            todayCompletionRate: rate,
            todayCompletedCount: todayCompletedCount,
            todayTotalCount: todayTotalCount,
            overdueTaskCount: overdueTaskCount,
            currentMainQuestTitle: mainQuestTitle,
            companionComment: comment,
            hasTodayReport: latestReport != nil,
            todayRecommendation: todayActionRecommendation(
                tasks: tasks,
                quests: quests,
                date: date,
                calendar: calendar
            ),
            todayPlanSummary: todayPlanSummary(
                tasks: tasks,
                quests: quests,
                date: date,
                calendar: calendar
            )
        )
    }

    private func dashboardFallbackComment(for completionRate: Double) -> String {
        if completionRate >= 0.8 {
            return "完成率不错，但别被数字麻痹。确认主线是否真的前进。"
        }

        if completionRate == 0 {
            return "药老已苏醒。先完成一件能推进主线的小事。"
        }

        return "你今天可以做很多事，但真正推进主线的只有一两件。先完成 MVP，再谈扩展。"
    }

    func displayName(_ name: String?, fallback: String) -> String {
        let cleanedName = cleanedDisplayTitle(name ?? "")
        return cleanedName.isEmpty ? fallback : cleanedName
    }

    func displayQuestTitle(for quest: Quest) -> String {
        cleanedDisplayTitle(quest.title)
    }

    func cleanQuestTitle(_ title: String) -> String {
        cleanedDisplayTitle(title)
    }

    func displayQuestDetail(for quest: Quest) -> String {
        cleanedDisplayText(quest.detail)
    }

    func displayTaskTitle(for task: TaskItem) -> String {
        cleanedDisplayTitle(task.title)
    }

    func cleanTaskTitle(_ title: String) -> String {
        cleanedDisplayTitle(title)
    }

    func displayTaskDetail(for task: TaskItem) -> String {
        cleanedDisplayText(task.detail)
    }

    func displayTaskXPRewardText(for task: TaskItem) -> String {
        "\(normalizedXPReward(for: task)) XP"
    }

    func displayQuestTypeTitle(for rawValue: String) -> String {
        let cleanedRawValue = cleanedDisplayTitle(rawValue)
        guard !cleanedRawValue.isEmpty else {
            return "未知类型"
        }

        return QuestType(rawValue: cleanedRawValue.lowercased())?.title ?? cleanedRawValue
    }

    func displayTaskTypeTitle(for rawValue: String) -> String {
        displayQuestTypeTitle(for: rawValue)
    }

    func displayQuestStatusTitle(for rawValue: String) -> String {
        let cleanedRawValue = cleanedDisplayTitle(rawValue)
        guard !cleanedRawValue.isEmpty else {
            return "未知状态"
        }

        return QuestStatus(rawValue: cleanedRawValue.lowercased())?.title ?? cleanedRawValue
    }

    private func displayableTasks(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.filter { !displayTaskTitle(for: $0).isEmpty }
    }

    private func cleanedDisplayTitle(_ title: String) -> String {
        cleanedDisplayText(title)
    }

    private func cleanedDisplayText(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func clampedProfileStat(_ value: Int?, fallback: Int) -> Int {
        min(max(value ?? fallback, 0), 100)
    }
}
