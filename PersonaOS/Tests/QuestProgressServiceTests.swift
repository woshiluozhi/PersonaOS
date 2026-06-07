import XCTest
@testable import PersonaOS

final class QuestProgressServiceTests: XCTestCase {
    func testCompleteTaskAddsXP() {
        let service = QuestProgressService()
        let user = UserProfile(currentXP: 10)
        let task = TaskItem(title: "推进主线", xpReward: 30)

        let reward = service.completeTask(task, user: user)

        XCTAssertEqual(reward, 30)
        XCTAssertTrue(task.isCompleted)
        XCTAssertEqual(user.currentXP, 40)
    }

    func testCompleteTaskBackfillsMissingCompletionDateWithoutRewardingAgain() {
        let service = QuestProgressService()
        let completedAt = Date(timeIntervalSince1970: 123)
        let user = UserProfile(currentXP: 50)
        let task = TaskItem(
            title: "已完成旧任务",
            isCompleted: true,
            xpReward: 20,
            completedAt: nil
        )

        let reward = service.completeTask(task, user: user, completedAt: completedAt)

        XCTAssertEqual(reward, 0)
        XCTAssertEqual(task.completedAt, completedAt)
        XCTAssertEqual(user.currentXP, 50)
        XCTAssertEqual(user.level, 1)
        XCTAssertEqual(user.updatedAt, completedAt)
    }

    func testLevelChangesAtOneHundredXP() {
        let service = QuestProgressService()
        let user = UserProfile(currentXP: 90)
        let task = TaskItem(title: "完成闭环", xpReward: 10)

        service.completeTask(task, user: user)

        XCTAssertEqual(user.currentXP, 100)
        XCTAssertEqual(user.level, 2)
    }

    func testReopenTaskRollsBackXPAndLevel() {
        let service = QuestProgressService()
        let user = UserProfile(level: 2, currentXP: 100)
        let task = TaskItem(title: "误完成", isCompleted: true, xpReward: 20, completedAt: Date())

        let rollback = service.reopenTask(task, user: user)

        XCTAssertEqual(rollback, 20)
        XCTAssertFalse(task.isCompleted)
        XCTAssertNil(task.completedAt)
        XCTAssertEqual(user.currentXP, 80)
        XCTAssertEqual(user.level, 1)
    }

    func testXPToNextLevel() {
        let service = QuestProgressService()

        XCTAssertEqual(service.xpToNextLevel(forXP: 0), 100)
        XCTAssertEqual(service.xpToNextLevel(forXP: 95), 5)
        XCTAssertEqual(service.xpToNextLevel(forXP: 100), 100)
    }

    func testTodayCompletionRateIsCorrect() {
        let service = QuestProgressService()
        let today = Date()
        let done = TaskItem(title: "已完成", isCompleted: true, dueDate: today, completedAt: today)
        let pending = TaskItem(title: "未完成", isCompleted: false, dueDate: today)

        let rate = service.todayCompletionRate(tasks: [done, pending], date: today)

        XCTAssertEqual(rate, 0.5, accuracy: 0.001)
    }

    func testTodayTasksExcludeDailyTaskCompletedBeforeToday() {
        let service = QuestProgressService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400 * 10)
        let yesterday = Date(timeInterval: -86_400, since: today)
        let completedYesterday = TaskItem(
            title: "昨日每日",
            taskType: QuestType.daily.rawValue,
            isCompleted: true,
            dueDate: today,
            completedAt: yesterday
        )
        let openDaily = TaskItem(
            title: "今日每日",
            taskType: QuestType.daily.rawValue,
            dueDate: nil
        )

        let todayTasks = service.todayTasks(
            from: [completedYesterday, openDaily],
            date: today,
            calendar: calendar
        )
        let rate = service.todayCompletionRate(
            tasks: [completedYesterday, openDaily],
            date: today,
            calendar: calendar
        )

        XCTAssertEqual(todayTasks.map(\.title), ["今日每日"])
        XCTAssertEqual(rate, 0, accuracy: 0.001)
    }

    func testBlankTaskTitlesAreSkippedFromPlanningAndSearch() {
        let service = QuestProgressService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400 * 10)
        let yesterday = Date(timeInterval: -86_400, since: today)
        let blankToday = TaskItem(
            title: " \n\t ",
            taskType: QuestType.daily.rawValue,
            dueDate: today
        )
        let blankOverdue = TaskItem(title: "  ", dueDate: yesterday)
        let blankCompleted = TaskItem(
            title: "\n",
            isCompleted: true,
            dueDate: today,
            completedAt: today
        )
        let messyToday = TaskItem(
            title: " 推进\n主线\t任务 ",
            detail: "  处理\n详情\t换行  ",
            taskType: QuestType.daily.rawValue,
            dueDate: today
        )
        let tasks = [blankToday, blankOverdue, blankCompleted, messyToday]

        let dashboard = service.makeDashboardData(
            user: nil,
            companion: nil,
            tasks: tasks,
            quests: [],
            dailyReports: [],
            date: today,
            calendar: calendar
        )

        XCTAssertEqual(service.todayTasks(from: tasks, date: today, calendar: calendar).map(\.id), [messyToday.id])
        XCTAssertTrue(service.overdueTasks(from: tasks, date: today, calendar: calendar).isEmpty)
        XCTAssertEqual(service.tasks(from: tasks, matching: .all, date: today, calendar: calendar).map(\.id), [messyToday.id])
        XCTAssertEqual(service.searchTasks(tasks, searchText: "主线 任务").map(\.id), [messyToday.id])
        XCTAssertEqual(service.searchTasks(tasks, searchText: "详情 换行").map(\.id), [messyToday.id])
        XCTAssertTrue(service.recentlyCompletedTasks(tasks).isEmpty)
        XCTAssertEqual(service.displayTaskTitle(for: messyToday), "推进 主线 任务")
        XCTAssertEqual(service.displayTaskDetail(for: messyToday), "处理 详情 换行")
        XCTAssertEqual(dashboard.todayTotalCount, 1)
        XCTAssertEqual(dashboard.todayRecommendation.taskTitle, "推进 主线 任务")
    }

    func testTaskSummarySkipsBlankTasksAndCountsCompletionStatus() {
        let service = QuestProgressService()
        let open = TaskItem(title: "继续推进")
        let completed = TaskItem(title: "已经完成", isCompleted: true, completedAt: Date())
        let blankOpen = TaskItem(title: " \n\t ")
        let blankCompleted = TaskItem(title: " ", isCompleted: true, completedAt: Date())

        let summary = service.taskSummary(for: [open, completed, blankOpen, blankCompleted])

        XCTAssertEqual(
            summary,
            TaskCollectionSummary(totalCount: 2, incompleteCount: 1, completedCount: 1)
        )
    }

    func testTaskDeleteConfirmationCopyUsesCleanTitlesAndCount() {
        let service = QuestProgressService()
        let messy = TaskItem(title: "  推进\n主线\t任务  ")
        let second = TaskItem(title: "整理支线")
        let blank = TaskItem(title: " \n\t ")

        XCTAssertEqual(service.taskDeleteConfirmationTitle(for: [messy]), "删除这项任务")
        XCTAssertEqual(
            service.taskDeleteConfirmationMessage(for: [messy]),
            "这会删除「推进 主线 任务」的本地任务记录。"
        )
        XCTAssertEqual(service.taskDeleteConfirmationTitle(for: [messy, second]), "删除 2 项任务")
        XCTAssertEqual(
            service.taskDeleteConfirmationMessage(for: [messy, second]),
            "这会删除选中的 2 项本地任务记录。"
        )
        XCTAssertEqual(
            service.taskDeleteConfirmationMessage(for: [blank]),
            "这会删除「空白任务」的本地任务记录。"
        )
    }

    func testManualTaskAndQuestTitleCleaningCollapsesWhitespace() {
        let service = QuestProgressService()

        XCTAssertEqual(service.cleanTaskTitle("  推进\n主线\t任务  "), "推进 主线 任务")
        XCTAssertEqual(service.cleanQuestTitle("  构建\nPersonaOS\t主线  "), "构建 PersonaOS 主线")
        XCTAssertTrue(service.cleanTaskTitle(" \n\t ").isEmpty)
        XCTAssertTrue(service.cleanQuestTitle(" \n\t ").isEmpty)
    }

    func testTypeAndStatusTitlesNormalizeRawValues() {
        let service = QuestProgressService()

        XCTAssertEqual(service.displayTaskTypeTitle(for: " MAIN "), "主线")
        XCTAssertEqual(service.displayQuestTypeTitle(for: "side"), "支线")
        XCTAssertEqual(service.displayQuestTypeTitle(for: "legacy type"), "legacy type")
        XCTAssertEqual(service.displayQuestTypeTitle(for: " \n\t "), "未知类型")
        XCTAssertEqual(service.displayQuestStatusTitle(for: " ARCHIVED "), "已归档")
        XCTAssertEqual(service.displayQuestStatusTitle(for: "paused"), "paused")
        XCTAssertEqual(service.displayQuestStatusTitle(for: " \n\t "), "未知状态")
    }

    func testTodayActionRecommendationButtonTitleReflectsTargetAction() {
        XCTAssertEqual(
            TodayActionRecommendation(kind: .review, title: "", detail: "").actionButtonTitle(hasTodayReport: false),
            "生成复盘"
        )
        XCTAssertEqual(
            TodayActionRecommendation(kind: .review, title: "", detail: "").actionButtonTitle(hasTodayReport: true),
            "更新复盘"
        )
        XCTAssertEqual(
            TodayActionRecommendation(kind: .noTask, title: "", detail: "").actionButtonTitle(hasTodayReport: false),
            "新增任务"
        )
        XCTAssertEqual(
            TodayActionRecommendation(kind: .overdue, title: "", detail: "").actionButtonTitle(hasTodayReport: false),
            "查看任务"
        )
        XCTAssertEqual(
            TodayActionRecommendation(kind: .mainQuest, title: "", detail: "").actionButtonTitle(hasTodayReport: false),
            "查看任务"
        )
        XCTAssertEqual(
            TodayActionRecommendation(kind: .daily, title: "", detail: "").actionButtonTitle(hasTodayReport: false),
            "查看任务"
        )
    }

    func testTodayMetricsCountOnlyTasksCompletedOnDate() {
        let service = QuestProgressService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400 * 10)
        let yesterday = Date(timeInterval: -86_400, since: today)
        let user = UserProfile()
        let companion = CompanionPersona()
        let completedYesterday = TaskItem(
            title: "提前完成",
            isCompleted: true,
            xpReward: 30,
            dueDate: today,
            completedAt: yesterday
        )
        let completedToday = TaskItem(
            title: "今日完成",
            isCompleted: true,
            xpReward: 20,
            dueDate: today,
            completedAt: today
        )
        let pending = TaskItem(
            title: "今日未完成",
            xpReward: 10,
            dueDate: today
        )

        let rate = service.todayCompletionRate(
            tasks: [completedYesterday, completedToday, pending],
            date: today,
            calendar: calendar
        )
        let dashboard = service.makeDashboardData(
            user: user,
            companion: companion,
            tasks: [completedYesterday, completedToday, pending],
            quests: [],
            dailyReports: [],
            date: today,
            calendar: calendar
        )

        XCTAssertFalse(service.isTaskCompleted(completedYesterday, on: today, calendar: calendar))
        XCTAssertTrue(service.isTaskCompleted(completedToday, on: today, calendar: calendar))
        XCTAssertEqual(rate, 1.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(dashboard.todayCompletedCount, 1)
        XCTAssertEqual(dashboard.todayTotalCount, 3)
        XCTAssertEqual(dashboard.todayCompletionRate, 1.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(dashboard.todayPlanSummary.availableXP, 30)
        XCTAssertEqual(dashboard.todayPlanSummary.completedXP, 20)
        XCTAssertEqual(dashboard.todayPlanSummary.remainingXP, 10)
    }

    func testTaskScopeFiltering() {
        let service = QuestProgressService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 0)
        let yesterday = Date(timeInterval: -86_400, since: today)
        let tomorrow = Date(timeInterval: 86_400, since: today)
        let mainToday = TaskItem(title: "主线今日", taskType: QuestType.main.rawValue, dueDate: today)
        let sideTomorrow = TaskItem(title: "支线明日", taskType: QuestType.side.rawValue, dueDate: tomorrow)
        let daily = TaskItem(title: "每日习惯", taskType: QuestType.daily.rawValue, dueDate: nil)
        let overdue = TaskItem(title: "逾期未完成", taskType: QuestType.side.rawValue, dueDate: yesterday)
        let completedOverdue = TaskItem(
            title: "已完成逾期",
            taskType: QuestType.side.rawValue,
            isCompleted: true,
            dueDate: yesterday,
            completedAt: yesterday
        )
        let allTasks = [mainToday, sideTomorrow, daily, overdue, completedOverdue]

        let todayTitles = service
            .tasks(from: allTasks, matching: .today, date: today, calendar: calendar)
            .map(\.title)
        let overdueTitles = service
            .tasks(from: allTasks, matching: .overdue, date: today, calendar: calendar)
            .map(\.title)
        let mainTitles = service.tasks(from: allTasks, matching: .main).map(\.title)

        XCTAssertEqual(Set(todayTitles), Set(["主线今日", "每日习惯"]))
        XCTAssertEqual(overdueTitles, ["逾期未完成"])
        XCTAssertEqual(mainTitles, ["主线今日"])
    }

    func testTaskScopeFilteringIncludesTasksLinkedToQuestType() {
        let service = QuestProgressService()
        let mainQuest = Quest(title: "构建 PersonaOS", questType: QuestType.main.rawValue)
        let blankMainQuest = Quest(title: " \n ", questType: QuestType.main.rawValue)
        let sideQuest = Quest(title: "整理素材", questType: QuestType.side.rawValue)
        let typedMain = TaskItem(title: "主线任务", taskType: QuestType.main.rawValue)
        let linkedDailyMain = TaskItem(
            title: "挂主线的每日任务",
            taskType: QuestType.daily.rawValue,
            questId: mainQuest.id
        )
        let linkedBlankMain = TaskItem(
            title: "挂空白主线的每日任务",
            taskType: QuestType.daily.rawValue,
            questId: blankMainQuest.id
        )
        let linkedDailySide = TaskItem(
            title: "挂支线的每日任务",
            taskType: QuestType.daily.rawValue,
            questId: sideQuest.id
        )
        let unrelatedDaily = TaskItem(title: "普通每日", taskType: QuestType.daily.rawValue)

        let allTasks = [typedMain, linkedDailyMain, linkedBlankMain, linkedDailySide, unrelatedDaily]
        let mainTitles = service
            .tasks(from: allTasks, matching: .main, quests: [mainQuest, blankMainQuest, sideQuest])
            .map(\.title)
        let sideTitles = service
            .tasks(from: allTasks, matching: .side, quests: [mainQuest, blankMainQuest, sideQuest])
            .map(\.title)

        XCTAssertEqual(Set(mainTitles), Set(["主线任务", "挂主线的每日任务"]))
        XCTAssertEqual(sideTitles, ["挂支线的每日任务"])
    }

    func testSearchTasksMatchesTitleDetailTypeAndQuestTitle() {
        let service = QuestProgressService()
        let quest = Quest(title: "构建 PersonaOS", questType: QuestType.main.rawValue)
        let titleMatch = TaskItem(title: "写测试")
        let detailMatch = TaskItem(title: "普通任务", detail: "整理日报趋势")
        let typeMatch = TaskItem(title: "类型匹配", taskType: QuestType.side.rawValue)
        let questMatch = TaskItem(title: "绑定任务线", questId: quest.id)
        let unrelated = TaskItem(title: "无关")
        let tasks = [titleMatch, detailMatch, typeMatch, questMatch, unrelated]

        XCTAssertEqual(service.searchTasks(tasks, searchText: "测试").map(\.title), ["写测试"])
        XCTAssertEqual(service.searchTasks(tasks, searchText: "趋势").map(\.title), ["普通任务"])
        XCTAssertEqual(service.searchTasks(tasks, searchText: "支线").map(\.title), ["类型匹配"])
        XCTAssertEqual(service.searchTasks(tasks, searchText: "PersonaOS", quests: [quest]).map(\.title), ["绑定任务线"])
    }

    func testSearchTasksMatchesRelativeDueDate() {
        let service = QuestProgressService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400 * 3)
        let yesterday = Date(timeInterval: -86_400, since: today)
        let dueToday = TaskItem(title: "今天截止", dueDate: today)
        let overdue = TaskItem(title: "昨天截止", dueDate: yesterday)
        let noDueDate = TaskItem(title: "无日期", dueDate: nil)

        let todayResults = service.searchTasks(
            [dueToday, overdue, noDueDate],
            searchText: "今天",
            date: today,
            calendar: calendar
        )
        let overdueResults = service.searchTasks(
            [dueToday, overdue, noDueDate],
            searchText: "已过期",
            date: today,
            calendar: calendar
        )

        XCTAssertEqual(todayResults.map(\.title), ["今天截止"])
        XCTAssertEqual(overdueResults.map(\.title), ["昨天截止"])
    }

    func testSearchTasksMatchesMultipleTermsAcrossTypeAndDate() {
        let service = QuestProgressService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400 * 10)
        let tomorrow = Date(timeInterval: 86_400, since: today)
        let mainToday = TaskItem(
            title: "推进接口",
            taskType: QuestType.main.rawValue,
            dueDate: today
        )
        let mainTomorrow = TaskItem(
            title: "明日主线",
            taskType: QuestType.main.rawValue,
            dueDate: tomorrow
        )
        let dailyToday = TaskItem(
            title: "今日习惯",
            taskType: QuestType.daily.rawValue,
            dueDate: today
        )

        let results = service.searchTasks(
            [mainToday, mainTomorrow, dailyToday],
            searchText: "主线 今天",
            date: today,
            calendar: calendar
        )

        XCTAssertEqual(results.map(\.title), ["推进接口"])
    }

    func testSearchTasksMatchesCreatedDueAndCompletedRelativeDates() {
        let service = QuestProgressService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400 * 10)
        let yesterday = Date(timeInterval: -86_400, since: today)
        let tomorrow = Date(timeInterval: 86_400, since: today)
        let createdYesterday = TaskItem(title: "昨日创建", dueDate: nil, createdAt: yesterday)
        let dueTomorrow = TaskItem(title: "明日截止", dueDate: tomorrow, createdAt: today)
        let completedYesterday = TaskItem(
            title: "昨日完成",
            isCompleted: true,
            dueDate: nil,
            createdAt: today,
            completedAt: yesterday
        )
        let unrelated = TaskItem(title: "普通任务", dueDate: nil, createdAt: today)
        let tasks = [createdYesterday, dueTomorrow, completedYesterday, unrelated]

        XCTAssertEqual(
            service.searchTasks(tasks, searchText: "昨天", date: today, calendar: calendar).map(\.title),
            ["昨日创建", "昨日完成"]
        )
        XCTAssertEqual(
            service.searchTasks(tasks, searchText: "明天", date: today, calendar: calendar).map(\.title),
            ["明日截止"]
        )
    }

    func testSearchTasksMatchesCompletionStatusAndXP() {
        let service = QuestProgressService()
        let completed = TaskItem(title: "完成验收", isCompleted: true, xpReward: 40)
        let open = TaskItem(title: "继续打磨", isCompleted: false, xpReward: 20)
        let dirtyNegativeXP = TaskItem(title: "旧负值任务", xpReward: -10)

        XCTAssertEqual(
            service.searchTasks([completed, open, dirtyNegativeXP], searchText: "已完成").map(\.title),
            ["完成验收"]
        )
        XCTAssertEqual(
            service.searchTasks([completed, open, dirtyNegativeXP], searchText: "未完成").map(\.title),
            ["继续打磨", "旧负值任务"]
        )
        XCTAssertEqual(
            service.searchTasks([completed, open, dirtyNegativeXP], searchText: "40 XP").map(\.title),
            ["完成验收"]
        )
        XCTAssertEqual(
            service.searchTasks([completed, open, dirtyNegativeXP], searchText: "0 XP").map(\.title),
            ["旧负值任务"]
        )
        XCTAssertTrue(service.searchTasks([completed, open, dirtyNegativeXP], searchText: "-10 XP").isEmpty)
    }

    func testTaskXPRewardTextClampsNegativeRewards() {
        let service = QuestProgressService()
        let dirtyNegativeXP = TaskItem(title: "旧负值任务", xpReward: -10)
        let positiveXP = TaskItem(title: "高价值任务", xpReward: 40)

        XCTAssertEqual(service.displayTaskXPRewardText(for: dirtyNegativeXP), "0 XP")
        XCTAssertEqual(service.displayTaskXPRewardText(for: positiveXP), "40 XP")
    }

    func testSortedIncompleteTasksForActionPrioritizesUrgency() {
        let service = QuestProgressService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400 * 5)
        let yesterday = Date(timeInterval: -86_400, since: today)
        let tomorrow = Date(timeInterval: 86_400, since: today)
        let overdue = TaskItem(title: "逾期任务", xpReward: 5, dueDate: yesterday)
        let todayHighXP = TaskItem(title: "今天高 XP", xpReward: 50, dueDate: today)
        let todayLowXP = TaskItem(title: "今天低 XP", xpReward: 10, dueDate: today)
        let dailyNoDate = TaskItem(title: "每日无日期", taskType: QuestType.daily.rawValue, xpReward: 30, dueDate: nil)
        let future = TaskItem(title: "明日任务", taskType: QuestType.side.rawValue, xpReward: 100, dueDate: tomorrow)
        let noDateSide = TaskItem(title: "无日期支线", taskType: QuestType.side.rawValue, xpReward: 100, dueDate: nil)

        let sortedTitles = service
            .sortedIncompleteTasksForAction(
                [noDateSide, future, todayLowXP, dailyNoDate, todayHighXP, overdue],
                date: today,
                calendar: calendar
            )
            .map(\.title)

        XCTAssertEqual(
            sortedTitles,
            ["逾期任务", "今天高 XP", "今天低 XP", "每日无日期", "明日任务", "无日期支线"]
        )
    }

    func testSortedIncompleteTasksForActionSkipsCompletedAndBlankTasks() {
        let service = QuestProgressService()
        let open = TaskItem(title: "继续推进")
        let completed = TaskItem(title: "已经完成", isCompleted: true, completedAt: Date())
        let blank = TaskItem(title: " \n\t ")

        let sortedTitles = service
            .sortedIncompleteTasksForAction([completed, blank, open])
            .map(\.title)

        XCTAssertEqual(sortedTitles, ["继续推进"])
    }

    func testTaskActionSortingTreatsNegativeXPAsZeroReward() {
        let service = QuestProgressService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400 * 5)
        let older = Date(timeInterval: -60, since: today)
        let newer = Date(timeInterval: 60, since: today)
        let zeroXPTask = TaskItem(title: "0 XP 旧任务", xpReward: 0, dueDate: nil, createdAt: older)
        let negativeXPTask = TaskItem(title: "负 XP 新任务", xpReward: -10, dueDate: nil, createdAt: newer)
        let zeroXPCompleted = TaskItem(
            title: "0 XP 旧完成",
            isCompleted: true,
            xpReward: 0,
            dueDate: today,
            createdAt: older,
            completedAt: today
        )
        let negativeXPCompleted = TaskItem(
            title: "负 XP 新完成",
            isCompleted: true,
            xpReward: -10,
            dueDate: today,
            createdAt: newer,
            completedAt: today
        )

        XCTAssertEqual(
            service.sortedIncompleteTasksForAction(
                [zeroXPTask, negativeXPTask],
                date: today,
                calendar: calendar
            ).map(\.title),
            ["负 XP 新任务", "0 XP 旧任务"]
        )
        XCTAssertEqual(
            service.actionOrderedTodayTasks(
                from: [zeroXPCompleted, negativeXPCompleted],
                date: today,
                calendar: calendar
            ).map(\.title),
            ["负 XP 新完成", "0 XP 旧完成"]
        )
        XCTAssertEqual(
            service.recentlyCompletedTasks([zeroXPCompleted, negativeXPCompleted]).map(\.title),
            ["负 XP 新完成", "0 XP 旧完成"]
        )
    }

    func testActionOrderedTodayTasksKeepsOpenWorkBeforeCompletedWork() {
        let service = QuestProgressService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400 * 5)
        let tomorrow = Date(timeInterval: 86_400, since: today)
        let oneHourLater = Date(timeInterval: 3_600, since: today)
        let todayHighXP = TaskItem(title: "今天高 XP", xpReward: 50, dueDate: today)
        let todayLowXP = TaskItem(title: "今天低 XP", xpReward: 10, dueDate: today)
        let dailyNoDate = TaskItem(title: "每日无日期", taskType: QuestType.daily.rawValue, xpReward: 30, dueDate: nil)
        let completedEarly = TaskItem(
            title: "早些完成",
            isCompleted: true,
            xpReward: 40,
            dueDate: today,
            completedAt: today
        )
        let completedRecent = TaskItem(
            title: "刚刚完成",
            isCompleted: true,
            xpReward: 5,
            dueDate: today,
            completedAt: oneHourLater
        )
        let future = TaskItem(title: "明日任务", taskType: QuestType.side.rawValue, xpReward: 100, dueDate: tomorrow)

        let sortedTitles = service
            .actionOrderedTodayTasks(
                from: [completedEarly, future, dailyNoDate, todayLowXP, completedRecent, todayHighXP],
                date: today,
                calendar: calendar
            )
            .map(\.title)

        XCTAssertEqual(
            sortedTitles,
            ["今天高 XP", "今天低 XP", "每日无日期", "刚刚完成", "早些完成"]
        )
    }

    func testRecentlyCompletedTasksSortsByLatestCompletionAndFiltersOpenWork() {
        let service = QuestProgressService()
        let baseDate = Date(timeIntervalSince1970: 1_000)
        let recentDate = Date(timeInterval: 300, since: baseDate)
        let openTask = TaskItem(title: "仍在推进", isCompleted: false, xpReward: 100, createdAt: recentDate)
        let olderCompleted = TaskItem(
            title: "较早完成",
            isCompleted: true,
            xpReward: 100,
            createdAt: baseDate,
            completedAt: baseDate
        )
        let recentCompleted = TaskItem(
            title: "最近完成",
            isCompleted: true,
            xpReward: 10,
            createdAt: baseDate,
            completedAt: recentDate
        )
        let sameTimeHigherXP = TaskItem(
            title: "同时间高 XP",
            isCompleted: true,
            xpReward: 80,
            createdAt: baseDate,
            completedAt: recentDate
        )

        let sortedTitles = service
            .recentlyCompletedTasks([openTask, olderCompleted, recentCompleted, sameTimeHigherXP])
            .map(\.title)

        XCTAssertEqual(sortedTitles, ["同时间高 XP", "最近完成", "较早完成"])
    }

    func testHasOpenTaskMatchesUnfinishedTasksOnly() {
        let service = QuestProgressService()
        let openTask = TaskItem(title: "补齐验收测试", isCompleted: false)
        let completedTask = TaskItem(title: "完成日报", isCompleted: true)

        XCTAssertTrue(service.hasOpenTask(titled: " 补齐验收测试 ", in: [openTask, completedTask]))
        XCTAssertTrue(service.hasOpenTask(titled: "补齐验收测试", in: [openTask]))
        XCTAssertFalse(service.hasOpenTask(titled: "完成日报", in: [completedTask]))
        XCTAssertFalse(service.hasOpenTask(titled: "", in: [openTask]))
    }

    func testHasOpenTaskCanExcludeCurrentTask() {
        let service = QuestProgressService()
        let currentTask = TaskItem(title: "补齐验收测试", isCompleted: false)
        let duplicateTask = TaskItem(title: "补齐验收测试", isCompleted: false)
        let completedTask = TaskItem(title: "补齐验收测试", isCompleted: true)

        XCTAssertFalse(service.hasOpenTask(titled: "补齐验收测试", excluding: currentTask.id, in: [currentTask, completedTask]))
        XCTAssertTrue(service.hasOpenTask(titled: "补齐验收测试", excluding: currentTask.id, in: [currentTask, duplicateTask]))
    }

    func testHasOpenTaskNormalizesTitleWhitespaceAndCase() {
        let service = QuestProgressService()
        let messyTitle = TaskItem(title: "  Ship   PersonaOS\nMVP  ", isCompleted: false)
        let completedMessyTitle = TaskItem(title: "  Ship   PersonaOS\nMVP  ", isCompleted: true)

        XCTAssertTrue(service.hasOpenTask(titled: "ship personaos mvp", in: [messyTitle]))
        XCTAssertFalse(service.hasOpenTask(titled: "ship personaos mvp", in: [completedMessyTitle]))
    }

    func testHasTodayTaskMatchesTitleWithinTodayScope() {
        let service = QuestProgressService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400 * 10)
        let tomorrow = Date(timeInterval: 86_400, since: today)
        let dueToday = TaskItem(title: "补齐验收测试", dueDate: today)
        let dailyWithoutDueDate = TaskItem(
            title: "每日复盘",
            taskType: QuestType.daily.rawValue,
            dueDate: nil
        )
        let completedToday = TaskItem(
            title: "完成于今天",
            taskType: QuestType.side.rawValue,
            isCompleted: true,
            dueDate: tomorrow,
            completedAt: today
        )
        let dueTomorrow = TaskItem(title: "补齐验收测试", dueDate: tomorrow)

        XCTAssertTrue(
            service.hasTodayTask(
                titled: " 补齐验收测试 ",
                in: [dueTomorrow, dueToday],
                date: today,
                calendar: calendar
            )
        )
        XCTAssertTrue(
            service.hasTodayTask(
                titled: "每日复盘",
                in: [dailyWithoutDueDate],
                date: today,
                calendar: calendar
            )
        )
        XCTAssertTrue(
            service.hasTodayTask(
                titled: "完成于今天",
                in: [completedToday],
                date: today,
                calendar: calendar
            )
        )
        XCTAssertFalse(
            service.hasTodayTask(
                titled: "补齐验收测试",
                in: [dueTomorrow],
                date: today,
                calendar: calendar
            )
        )
        XCTAssertFalse(service.hasTodayTask(titled: " ", in: [dueToday], date: today, calendar: calendar))
    }

    func testHasTodayTaskNormalizesTitleWhitespaceAndCase() {
        let service = QuestProgressService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400 * 10)
        let messyTodayTask = TaskItem(title: "  Review   PersonaOS\nPlan  ", dueDate: today)
        let futureTask = TaskItem(
            title: "  Review   PersonaOS\nPlan  ",
            dueDate: Date(timeInterval: 86_400, since: today)
        )

        XCTAssertTrue(
            service.hasTodayTask(
                titled: "review personaos plan",
                in: [messyTodayTask],
                date: today,
                calendar: calendar
            )
        )
        XCTAssertFalse(
            service.hasTodayTask(
                titled: "review personaos plan",
                in: [futureTask],
                date: today,
                calendar: calendar
            )
        )
    }

    func testHasTodayTaskCanExcludeCurrentTask() {
        let service = QuestProgressService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400 * 10)
        let currentTask = TaskItem(title: "今日闭环", dueDate: today)
        let duplicateTask = TaskItem(title: "今日闭环", dueDate: today)
        let tomorrowTask = TaskItem(title: "今日闭环", dueDate: Date(timeInterval: 86_400, since: today))

        XCTAssertFalse(
            service.hasTodayTask(
                titled: "今日闭环",
                excluding: currentTask.id,
                in: [currentTask, tomorrowTask],
                date: today,
                calendar: calendar
            )
        )
        XCTAssertTrue(
            service.hasTodayTask(
                titled: "今日闭环",
                excluding: currentTask.id,
                in: [currentTask, duplicateTask],
                date: today,
                calendar: calendar
            )
        )
    }

    func testAssignableQuestsForTaskType() {
        let service = QuestProgressService()
        let earlier = Date(timeIntervalSince1970: 10)
        let later = Date(timeIntervalSince1970: 20)
        let main = Quest(
            title: "主线",
            questType: QuestType.main.rawValue,
            priority: 2,
            createdAt: later
        )
        let side = Quest(
            title: "支线",
            questType: QuestType.side.rawValue,
            priority: 1,
            createdAt: earlier
        )
        let archivedMain = Quest(
            title: "归档主线",
            questType: QuestType.main.rawValue,
            status: QuestStatus.archived.rawValue,
            priority: 0,
            createdAt: earlier
        )
        let quests = [main, archivedMain, side]

        let dailyAssignableTitles = service
            .assignableQuests(for: .daily, from: quests)
            .map(\.title)
        let mainAssignableTitles = service
            .assignableQuests(for: .main, from: quests)
            .map(\.title)

        XCTAssertEqual(dailyAssignableTitles, ["支线", "主线"])
        XCTAssertEqual(mainAssignableTitles, ["主线"])
    }

    func testSelectableQuestsIncludeCurrentQuestAndSkipBlankDuplicates() {
        let service = QuestProgressService()
        let activeMain = Quest(
            title: "活跃主线",
            questType: QuestType.main.rawValue,
            priority: 2,
            createdAt: Date(timeIntervalSince1970: 20)
        )
        let activeSide = Quest(
            title: "活跃支线",
            questType: QuestType.side.rawValue,
            priority: 1,
            createdAt: Date(timeIntervalSince1970: 30)
        )
        let archivedCurrent = Quest(
            title: "旧归属",
            questType: QuestType.side.rawValue,
            status: QuestStatus.archived.rawValue,
            priority: 1,
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let blankCurrent = Quest(
            title: " \n\t ",
            questType: QuestType.side.rawValue,
            status: QuestStatus.archived.rawValue,
            priority: 1
        )

        let selectable = service.selectableQuests(
            for: .daily,
            currentQuestID: archivedCurrent.id,
            from: [activeMain, activeSide, archivedCurrent, blankCurrent]
        )
        let blankSelectable = service.selectableQuests(
            for: .daily,
            currentQuestID: blankCurrent.id,
            from: [activeMain, activeSide, archivedCurrent, blankCurrent]
        )
        let alreadyAssignable = service.selectableQuests(
            for: .daily,
            currentQuestID: activeSide.id,
            from: [activeMain, activeSide]
        )

        XCTAssertEqual(selectable.map(\.title), ["旧归属", "活跃支线", "活跃主线"])
        XCTAssertEqual(blankSelectable.map(\.title), ["活跃支线", "活跃主线"])
        XCTAssertEqual(alreadyAssignable.map(\.title), ["活跃支线", "活跃主线"])
    }

    func testQuestPrioritySortingClampsInvalidPriorityValues() {
        let service = QuestProgressService()
        let earlier = Date(timeIntervalSince1970: 10)
        let later = Date(timeIntervalSince1970: 20)
        let normalPriorityMain = Quest(
            title: "标准 P1 主线",
            questType: QuestType.main.rawValue,
            priority: 1,
            createdAt: earlier
        )
        let dirtyLowPriorityMain = Quest(
            title: "脏低值主线",
            questType: QuestType.main.rawValue,
            priority: -5,
            createdAt: later
        )
        let dirtyHighPrioritySide = Quest(
            title: "脏高值支线",
            questType: QuestType.side.rawValue,
            priority: 99,
            createdAt: earlier
        )
        let maxPrioritySide = Quest(
            title: "P10 支线",
            questType: QuestType.side.rawValue,
            priority: 10,
            createdAt: later
        )

        let quests = [dirtyHighPrioritySide, maxPrioritySide, dirtyLowPriorityMain, normalPriorityMain]

        XCTAssertEqual(
            service.assignableQuests(for: .daily, from: quests).map(\.title),
            ["标准 P1 主线", "脏低值主线", "脏高值支线", "P10 支线"]
        )
        XCTAssertEqual(
            service.activeQuests(from: quests).map(\.title),
            ["标准 P1 主线", "脏低值主线", "脏高值支线", "P10 支线"]
        )
        XCTAssertEqual(service.currentMainQuest(from: quests)?.title, "标准 P1 主线")
    }

    func testActiveQuestsSkipBlankTitlesAndExposeCleanDisplayTitle() {
        let service = QuestProgressService()
        let blankMain = Quest(
            title: " \n\t ",
            questType: QuestType.main.rawValue,
            priority: 1
        )
        let messyMain = Quest(
            title: " 构建\nPersonaOS\t主线 ",
            detail: "  主线\n详情\t说明  ",
            questType: QuestType.main.rawValue,
            priority: 5
        )
        let linkedTask = TaskItem(title: "推进任务线", questId: messyMain.id)
        let blankLinkedTask = TaskItem(title: "空白任务线", questId: blankMain.id)

        let dashboardWithBlankOnly = service.makeDashboardData(
            user: nil,
            companion: nil,
            tasks: [],
            quests: [blankMain],
            dailyReports: []
        )
        let dashboardWithMessyMain = service.makeDashboardData(
            user: nil,
            companion: nil,
            tasks: [],
            quests: [blankMain, messyMain],
            dailyReports: []
        )

        XCTAssertEqual(service.activeQuests(from: [blankMain, messyMain]).map { service.displayQuestTitle(for: $0) }, ["构建 PersonaOS 主线"])
        XCTAssertIdentical(service.currentMainQuest(from: [blankMain, messyMain]), messyMain)
        XCTAssertEqual(service.questTitle(for: linkedTask, quests: [messyMain]), "构建 PersonaOS 主线")
        XCTAssertEqual(service.displayQuestDetail(for: messyMain), "主线 详情 说明")
        XCTAssertNil(service.questTitle(for: blankLinkedTask, quests: [blankMain]))
        XCTAssertEqual(dashboardWithBlankOnly.currentMainQuestTitle, "尚未设定主线")
        XCTAssertEqual(dashboardWithMessyMain.currentMainQuestTitle, "构建 PersonaOS 主线")
    }

    func testClosedQuestsSkipBlankTitlesAndSortByUpdateDate() {
        let service = QuestProgressService()
        let olderDate = Date(timeIntervalSince1970: 100)
        let newerDate = Date(timeIntervalSince1970: 200)
        let activeQuest = Quest(
            title: "进行中任务线",
            status: QuestStatus.active.rawValue,
            updatedAt: newerDate
        )
        let blankClosedQuest = Quest(
            title: " \n ",
            status: QuestStatus.archived.rawValue,
            updatedAt: newerDate
        )
        let olderClosedQuest = Quest(
            title: "  旧\n任务线  ",
            status: QuestStatus.completed.rawValue,
            updatedAt: olderDate
        )
        let newerClosedQuest = Quest(
            title: "新\t任务线",
            status: QuestStatus.archived.rawValue,
            updatedAt: newerDate
        )

        let closedQuests = service.closedQuests(
            from: [olderClosedQuest, activeQuest, blankClosedQuest, newerClosedQuest]
        )

        XCTAssertEqual(
            closedQuests.map { service.displayQuestTitle(for: $0) },
            ["新 任务线", "旧 任务线"]
        )
    }

    func testQuestSummarySkipsBlankQuestsAndCountsStatuses() {
        let service = QuestProgressService()
        let active = Quest(
            title: "  主线\n推进  ",
            status: QuestStatus.active.rawValue
        )
        let completed = Quest(
            title: "已完成任务线",
            status: QuestStatus.completed.rawValue
        )
        let archived = Quest(
            title: "已归档任务线",
            status: QuestStatus.archived.rawValue
        )
        let unknownStatus = Quest(
            title: "旧状态任务线",
            status: "paused"
        )
        let blankActive = Quest(
            title: " \n\t ",
            status: QuestStatus.active.rawValue
        )
        let blankClosed = Quest(
            title: " ",
            status: QuestStatus.completed.rawValue
        )

        let summary = service.questSummary(
            for: [active, completed, archived, unknownStatus, blankActive, blankClosed]
        )

        XCTAssertEqual(
            summary,
            QuestCollectionSummary(totalCount: 4, activeCount: 1, closedCount: 3)
        )
    }

    func testActiveQuestLookupNormalizesTitleWhitespaceAndCase() {
        let service = QuestProgressService()
        let activeMain = Quest(
            title: "  Ship   PersonaOS\nMVP  ",
            questType: QuestType.main.rawValue,
            status: QuestStatus.active.rawValue
        )
        let sideWithSameTitle = Quest(
            title: "Ship PersonaOS MVP",
            questType: QuestType.side.rawValue,
            status: QuestStatus.active.rawValue
        )
        let archivedMain = Quest(
            title: "Ship PersonaOS MVP",
            questType: QuestType.main.rawValue,
            status: QuestStatus.archived.rawValue
        )

        let match = service.activeQuest(
            titled: "ship personaos mvp",
            ofType: .main,
            in: [archivedMain, sideWithSameTitle, activeMain]
        )

        XCTAssertIdentical(match, activeMain)
        XCTAssertTrue(service.hasActiveQuest(titled: "SHIP personaos MVP", ofType: .main, in: [activeMain]))
        XCTAssertFalse(service.hasActiveQuest(titled: "ship personaos mvp", ofType: .daily, in: [activeMain]))
    }

    func testActiveQuestLookupCanExcludeCurrentQuest() {
        let service = QuestProgressService()
        let current = Quest(title: "构建 PersonaOS", questType: QuestType.main.rawValue)
        let duplicate = Quest(title: " 构建   PersonaOS ", questType: QuestType.main.rawValue)

        XCTAssertNil(
            service.activeQuest(
                titled: "构建 PersonaOS",
                ofType: .main,
                excluding: current.id,
                in: [current]
            )
        )
        XCTAssertIdentical(
            service.activeQuest(
                titled: "构建 PersonaOS",
                ofType: .main,
                excluding: current.id,
                in: [current, duplicate]
            ),
            duplicate
        )
    }

    func testUpdateQuestStatus() {
        let service = QuestProgressService()
        let originalDate = Date(timeIntervalSince1970: 0)
        let updatedDate = Date(timeIntervalSince1970: 100)
        let quest = Quest(
            title: "任务线",
            status: QuestStatus.active.rawValue,
            updatedAt: originalDate
        )

        service.updateQuest(quest, status: .archived, now: updatedDate)

        XCTAssertEqual(quest.status, QuestStatus.archived.rawValue)
        XCTAssertEqual(quest.updatedAt, updatedDate)
    }

    func testQuestTaskProgressAndTitleLookup() {
        let service = QuestProgressService()
        let quest = Quest(title: "构建 PersonaOS")
        let relatedDone = TaskItem(title: "完成骨架", questId: quest.id, isCompleted: true)
        let relatedPending = TaskItem(title: "补充测试", questId: quest.id, isCompleted: false)
        let unrelated = TaskItem(title: "无关任务")

        let progress = service.questProgress(for: quest, tasks: [relatedDone, relatedPending, unrelated])

        XCTAssertEqual(progress.completedCount, 1)
        XCTAssertEqual(progress.totalCount, 2)
        XCTAssertEqual(progress.completionRate, 0.5, accuracy: 0.001)
        XCTAssertTrue(progress.hasTasks)
        XCTAssertEqual(progress.summaryText, "关联任务 1/2")
        XCTAssertEqual(service.questTitle(for: relatedDone, quests: [quest]), "构建 PersonaOS")
        XCTAssertNil(service.questTitle(for: unrelated, quests: [quest]))
    }

    func testQuestProgressMetricsClampInvalidValues() {
        let overCompleted = QuestTaskProgress(completedCount: 5, totalCount: 2)
        let negativeTotal = QuestTaskProgress(completedCount: 1, totalCount: -2)
        let recentProgress = QuestRecentProgress(
            dayProgress: [
                QuestDayProgress(date: Date(timeIntervalSince1970: 0), completedCount: -1, xpGained: -10),
                QuestDayProgress(date: Date(timeIntervalSince1970: 1), completedCount: 2, xpGained: 30)
            ]
        )

        XCTAssertEqual(overCompleted.completionRate, 1)
        XCTAssertTrue(overCompleted.hasTasks)
        XCTAssertEqual(overCompleted.summaryText, "关联任务 2/2")
        XCTAssertEqual(negativeTotal.completionRate, 0)
        XCTAssertFalse(negativeTotal.hasTasks)
        XCTAssertEqual(negativeTotal.summaryText, "关联任务 0/0")
        XCTAssertEqual(recentProgress.dayProgress[0].displayCompletedCount, 0)
        XCTAssertEqual(recentProgress.dayProgress[0].completionSummaryText, "完成 0 项")
        XCTAssertEqual(recentProgress.dayProgress[0].xpGainedText, "0 XP")
        XCTAssertEqual(recentProgress.dayProgress[1].displayCompletedCount, 2)
        XCTAssertEqual(recentProgress.dayProgress[1].completionSummaryText, "完成 2 项")
        XCTAssertEqual(recentProgress.dayProgress[1].xpGainedText, "30 XP")
        XCTAssertEqual(recentProgress.totalCompletedCount, 2)
        XCTAssertEqual(recentProgress.totalCompletedCountText, "2 项")
        XCTAssertEqual(recentProgress.totalXPGained, 30)
        XCTAssertEqual(recentProgress.totalXPGainedText, "30 XP")
    }

    func testRecentQuestProgressAggregatesCompletedTasksByDay() throws {
        let service = QuestProgressService()
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 12)))
        let today = calendar.startOfDay(for: now)
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))
        let oldDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -8, to: today))
        let startDate = try XCTUnwrap(calendar.date(byAdding: .day, value: -6, to: today))
        let quest = Quest(title: "构建 PersonaOS")
        let doneToday = TaskItem(
            title: "今日完成",
            questId: quest.id,
            isCompleted: true,
            xpReward: 10,
            completedAt: today
        )
        let doneYesterday = TaskItem(
            title: "昨日完成",
            questId: quest.id,
            isCompleted: true,
            xpReward: 20,
            completedAt: yesterday
        )
        let fallbackDueDate = TaskItem(
            title: "缺少完成时间",
            questId: quest.id,
            isCompleted: true,
            xpReward: 5,
            dueDate: yesterday
        )
        let negativeXP = TaskItem(
            title: "负 XP 不计入",
            questId: quest.id,
            isCompleted: true,
            xpReward: -10,
            completedAt: today
        )
        let oldDone = TaskItem(
            title: "窗口外",
            questId: quest.id,
            isCompleted: true,
            xpReward: 99,
            completedAt: oldDay
        )
        let pending = TaskItem(title: "未完成", questId: quest.id, isCompleted: false)
        let unrelated = TaskItem(
            title: "其他任务线",
            isCompleted: true,
            xpReward: 50,
            completedAt: today
        )

        let progress = service.recentProgress(
            for: quest,
            tasks: [doneToday, doneYesterday, fallbackDueDate, negativeXP, oldDone, pending, unrelated],
            days: 7,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(progress.dayProgress.count, 7)
        XCTAssertEqual(progress.dayProgress.first?.date, startDate)
        XCTAssertEqual(progress.dayProgress.last?.date, today)
        XCTAssertEqual(progress.dayProgress[5].completedCount, 2)
        XCTAssertEqual(progress.dayProgress[5].xpGained, 25)
        XCTAssertEqual(progress.dayProgress[6].completedCount, 2)
        XCTAssertEqual(progress.dayProgress[6].xpGained, 10)
        XCTAssertEqual(progress.totalCompletedCount, 4)
        XCTAssertEqual(progress.totalXPGained, 35)
    }

    func testDashboardDataIncludesCountsAndNextLevelXP() {
        let service = QuestProgressService()
        let today = Date()
        let yesterday = Date(timeInterval: -86_400, since: today)
        let user = UserProfile(level: 1, currentXP: 75)
        let companion = CompanionPersona()
        let mainQuest = Quest(title: "构建 PersonaOS", questType: QuestType.main.rawValue, priority: 1)
        let done = TaskItem(title: "已完成", isCompleted: true, xpReward: 20, dueDate: today, completedAt: today)
        let pending = TaskItem(title: "未完成", isCompleted: false, dueDate: today)
        let overdue = TaskItem(title: "逾期", taskType: QuestType.side.rawValue, isCompleted: false, dueDate: yesterday)

        let data = service.makeDashboardData(
            user: user,
            companion: companion,
            tasks: [done, pending, overdue],
            quests: [mainQuest],
            dailyReports: [],
            date: today
        )

        XCTAssertEqual(data.currentXP, 75)
        XCTAssertEqual(data.currentXPText, "75 XP")
        XCTAssertEqual(data.xpToNextLevel, 25)
        XCTAssertEqual(data.xpToNextLevelText, "距下级 25 XP")
        XCTAssertEqual(data.todayCompletedCount, 1)
        XCTAssertEqual(data.todayTotalCount, 2)
        XCTAssertEqual(data.todayCompletionPercent, 50)
        XCTAssertEqual(data.todayCompletionPercentText, "50%")
        XCTAssertEqual(data.overdueTaskCount, 1)
        XCTAssertEqual(data.currentMainQuestTitle, "构建 PersonaOS")
        XCTAssertFalse(data.hasTodayReport)
        XCTAssertEqual(data.todayRecommendation.kind, .overdue)
        XCTAssertEqual(data.todayPlanSummary.totalOpenCount, 2)
        XCTAssertEqual(data.todayPlanSummary.availableXP, 60)
        XCTAssertEqual(data.todayPlanSummary.availableXPText, "60 XP")
        XCTAssertEqual(data.todayPlanSummary.completedXP, 20)
        XCTAssertEqual(data.todayPlanSummary.completedXPText, "20 XP")
        XCTAssertEqual(data.todayPlanSummary.remainingXP, 40)
        XCTAssertEqual(data.todayPlanSummary.remainingXPText, "40 XP")
    }

    func testDashboardDataNormalizesProfileDisplayValues() {
        let service = QuestProgressService()
        let user = UserProfile(
            name: "   ",
            level: 99,
            currentXP: -25,
            energy: -10,
            focus: 120,
            stress: 150
        )
        let companion = CompanionPersona(name: "   ")

        let data = service.makeDashboardData(
            user: user,
            companion: companion,
            tasks: [],
            quests: [],
            dailyReports: []
        )

        XCTAssertEqual(data.userName, "智")
        XCTAssertEqual(data.companionName, "药老")
        XCTAssertEqual(data.currentXP, 0)
        XCTAssertEqual(data.currentXPText, "0 XP")
        XCTAssertEqual(data.level, 1)
        XCTAssertEqual(data.xpToNextLevel, 100)
        XCTAssertEqual(data.xpToNextLevelText, "距下级 100 XP")
        XCTAssertEqual(data.energy, 0)
        XCTAssertEqual(data.focus, 100)
        XCTAssertEqual(data.stress, 100)
    }

    func testDisplayNameCleansWhitespaceAndUsesFallback() {
        let service = QuestProgressService()

        XCTAssertEqual(service.displayName(" 智\n者\t一号 ", fallback: "智"), "智 者 一号")
        XCTAssertEqual(service.displayName(" \n\t ", fallback: "药老"), "药老")
        XCTAssertEqual(service.displayName(nil, fallback: "智"), "智")
    }

    func testDashboardDataDetectsTodayReport() {
        let service = QuestProgressService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400 * 10)
        let todayReport = DailyReport(
            date: today,
            companionComment: "  今天已经完成\n复盘。  "
        )

        let data = service.makeDashboardData(
            user: UserProfile(),
            companion: CompanionPersona(),
            tasks: [],
            quests: [],
            dailyReports: [todayReport],
            date: today,
            calendar: calendar
        )

        XCTAssertTrue(data.hasTodayReport)
        XCTAssertEqual(data.companionComment, "今天已经完成 复盘。")
    }

    func testDashboardDataFallsBackWhenTodayReportCommentIsBlank() {
        let service = QuestProgressService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400 * 10)
        let todayReport = DailyReport(
            date: today,
            companionComment: " \n "
        )

        let data = service.makeDashboardData(
            user: UserProfile(),
            companion: CompanionPersona(),
            tasks: [],
            quests: [],
            dailyReports: [todayReport],
            date: today,
            calendar: calendar
        )

        XCTAssertTrue(data.hasTodayReport)
        XCTAssertEqual(data.companionComment, "药老已苏醒。先完成一件能推进主线的小事。")
    }

    func testTodayPlanSummaryIncludesTodayAndOverdueWork() {
        let service = QuestProgressService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400 * 10)
        let yesterday = Date(timeInterval: -86_400, since: today)
        let tomorrow = Date(timeInterval: 86_400, since: today)
        let mainQuest = Quest(title: "构建 PersonaOS", questType: QuestType.main.rawValue)
        let completed = TaskItem(
            title: "已完成主线",
            taskType: QuestType.main.rawValue,
            questId: mainQuest.id,
            isCompleted: true,
            xpReward: 30,
            dueDate: today,
            completedAt: today
        )
        let linkedMain = TaskItem(
            title: "主线今日",
            taskType: QuestType.daily.rawValue,
            questId: mainQuest.id,
            xpReward: 20,
            dueDate: today
        )
        let daily = TaskItem(
            title: "每日训练",
            taskType: QuestType.daily.rawValue,
            xpReward: 10,
            dueDate: nil
        )
        let overdue = TaskItem(
            title: "逾期债务",
            taskType: QuestType.side.rawValue,
            xpReward: 15,
            dueDate: yesterday
        )
        let future = TaskItem(
            title: "明日任务",
            taskType: QuestType.side.rawValue,
            xpReward: 80,
            dueDate: tomorrow
        )

        let summary = service.todayPlanSummary(
            tasks: [completed, linkedMain, daily, overdue, future],
            quests: [mainQuest],
            date: today,
            calendar: calendar
        )

        XCTAssertEqual(summary.totalOpenCount, 3)
        XCTAssertEqual(summary.overdueOpenCount, 1)
        XCTAssertEqual(summary.mainOpenCount, 1)
        XCTAssertEqual(summary.dailyOpenCount, 2)
        XCTAssertEqual(summary.availableXP, 75)
        XCTAssertEqual(summary.availableXPText, "75 XP")
        XCTAssertEqual(summary.completedXP, 30)
        XCTAssertEqual(summary.completedXPText, "30 XP")
        XCTAssertEqual(summary.remainingXP, 45)
        XCTAssertEqual(summary.remainingXPText, "45 XP")
        XCTAssertEqual(summary.scopeSummaryText, "逾期 1 · 未完成 3 · 主线 1 · 每日 2")
    }

    func testTodayPlanSummaryXPTextClampsDirtyValues() {
        let negativeCompleted = TodayPlanSummary(
            totalOpenCount: 1,
            overdueOpenCount: 0,
            mainOpenCount: 1,
            dailyOpenCount: 0,
            availableXP: 10,
            completedXP: -5
        )
        let overCompleted = TodayPlanSummary(
            totalOpenCount: 0,
            overdueOpenCount: 0,
            mainOpenCount: 0,
            dailyOpenCount: 0,
            availableXP: 40,
            completedXP: 80
        )

        XCTAssertEqual(negativeCompleted.displayAvailableXP, 10)
        XCTAssertEqual(negativeCompleted.displayCompletedXP, 0)
        XCTAssertEqual(negativeCompleted.availableXPText, "10 XP")
        XCTAssertEqual(negativeCompleted.completedXPText, "0 XP")
        XCTAssertEqual(negativeCompleted.remainingXP, 10)
        XCTAssertEqual(negativeCompleted.remainingXPText, "10 XP")
        XCTAssertEqual(overCompleted.displayAvailableXP, 40)
        XCTAssertEqual(overCompleted.displayCompletedXP, 40)
        XCTAssertEqual(overCompleted.completedXPText, "40 XP")
        XCTAssertEqual(overCompleted.remainingXPText, "0 XP")
    }

    func testTodayPlanSummaryTextOmitsOverdueWhenClean() {
        let summary = TodayPlanSummary(
            totalOpenCount: 2,
            overdueOpenCount: 0,
            mainOpenCount: 1,
            dailyOpenCount: 1,
            availableXP: 40,
            completedXP: 10
        )

        XCTAssertEqual(summary.scopeSummaryText, "未完成 2 · 主线 1 · 每日 1")
    }

    func testTodayPlanSummaryTextShowsClearStateWhenNoOpenWork() {
        let summary = TodayPlanSummary(
            totalOpenCount: 0,
            overdueOpenCount: 0,
            mainOpenCount: 0,
            dailyOpenCount: 0,
            availableXP: 40,
            completedXP: 40
        )

        XCTAssertEqual(summary.scopeSummaryText, "今日已清空")
    }

    func testTodayActionRecommendationPrioritizesOverdueTask() {
        let service = QuestProgressService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400)
        let yesterday = Date(timeIntervalSince1970: 0)
        let overdue = TaskItem(title: "补齐验收测试", xpReward: 10, dueDate: yesterday)
        let todayMain = TaskItem(title: "推进主线", taskType: QuestType.main.rawValue, xpReward: 50, dueDate: today)

        let recommendation = service.todayActionRecommendation(
            tasks: [todayMain, overdue],
            quests: [Quest(title: "构建 PersonaOS")],
            date: today,
            calendar: calendar
        )

        XCTAssertEqual(recommendation.kind, .overdue)
        XCTAssertEqual(recommendation.taskTitle, "补齐验收测试")
    }

    func testTodayActionRecommendationPrefersCurrentMainQuestTask() {
        let service = QuestProgressService()
        let today = Date()
        let mainQuest = Quest(title: "构建 PersonaOS", questType: QuestType.main.rawValue)
        let mainTask = TaskItem(title: "完成主线闭环", questId: mainQuest.id, xpReward: 20, dueDate: today)
        let genericTask = TaskItem(title: "整理杂项", xpReward: 80, dueDate: today)

        let recommendation = service.todayActionRecommendation(
            tasks: [genericTask, mainTask],
            quests: [mainQuest],
            date: today
        )

        XCTAssertEqual(recommendation.kind, .mainQuest)
        XCTAssertEqual(recommendation.taskTitle, "完成主线闭环")
    }

    func testTodayActionRecommendationMovesToReviewWhenTodayTasksAreDone() {
        let service = QuestProgressService()
        let today = Date()
        let done = TaskItem(title: "完成闭环", isCompleted: true, dueDate: today, completedAt: today)

        let recommendation = service.todayActionRecommendation(tasks: [done], quests: [], date: today)

        XCTAssertEqual(recommendation.kind, .review)
        XCTAssertNil(recommendation.taskTitle)
    }

    func testTodayActionRecommendationHandlesEmptyDay() {
        let service = QuestProgressService()

        let recommendation = service.todayActionRecommendation(tasks: [], quests: [])

        XCTAssertEqual(recommendation.kind, .noTask)
        XCTAssertNil(recommendation.taskTitle)
    }
}

final class PersonaDateTests: XCTestCase {
    func testRelativeDayTitle() {
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 0)
        let yesterday = Date(timeInterval: -86_400, since: today)
        let tomorrow = Date(timeInterval: 86_400, since: today)
        let threeDaysLater = Date(timeInterval: 86_400 * 3, since: today)
        let threeDaysAgo = Date(timeInterval: -86_400 * 3, since: today)

        XCTAssertEqual(PersonaDate.relativeDayTitle(today, relativeTo: today, calendar: calendar), "今天")
        XCTAssertEqual(PersonaDate.relativeDayTitle(tomorrow, relativeTo: today, calendar: calendar), "明天")
        XCTAssertEqual(PersonaDate.relativeDayTitle(yesterday, relativeTo: today, calendar: calendar), "昨天")
        XCTAssertEqual(PersonaDate.relativeDayTitle(threeDaysLater, relativeTo: today, calendar: calendar), "3 天后")
        XCTAssertEqual(PersonaDate.relativeDayTitle(threeDaysAgo, relativeTo: today, calendar: calendar), "已过期 3 天")
    }
}
