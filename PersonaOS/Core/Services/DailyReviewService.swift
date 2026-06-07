import Foundation
import SwiftData

struct DailyReviewDayTrend {
    var date: Date
    var completedTaskCount: Int
    var totalTaskCount: Int
    var xpGained: Int

    var displayTotalTaskCount: Int {
        max(0, totalTaskCount)
    }

    var displayCompletedTaskCount: Int {
        min(max(0, completedTaskCount), displayTotalTaskCount)
    }

    var completionCountText: String {
        "\(displayCompletedTaskCount)/\(displayTotalTaskCount)"
    }

    var completionSummaryText: String {
        "完成 \(completionCountText)"
    }

    var completionRate: Double {
        guard displayTotalTaskCount > 0 else {
            return 0
        }

        return Double(displayCompletedTaskCount) / Double(displayTotalTaskCount)
    }

    var completionPercent: Int {
        Int(completionRate * 100)
    }

    var completionPercentText: String {
        "\(completionPercent)%"
    }

    var xpGainedText: String {
        "\(max(0, xpGained)) XP"
    }
}

struct DailyReviewTrend {
    var reportCount: Int
    var totalCompletedTaskCount: Int
    var totalTaskCount: Int
    var totalXPGained: Int
    var averageCompletionRate: Double
    var bestCompletionRate: Double
    var currentStreakDays: Int
    var bestStreakDays: Int
    var bestDayDate: Date?
    var latestReportDate: Date?
    var dayTrends: [DailyReviewDayTrend]

    var displayAverageCompletionRate: Double {
        min(max(averageCompletionRate, 0), 1)
    }

    var displayBestCompletionRate: Double {
        min(max(bestCompletionRate, 0), 1)
    }

    var averageCompletionPercent: Int {
        Int(displayAverageCompletionRate * 100)
    }

    var averageCompletionPercentText: String {
        "\(averageCompletionPercent)%"
    }

    var bestCompletionPercent: Int {
        Int(displayBestCompletionRate * 100)
    }

    var bestCompletionPercentText: String {
        "\(bestCompletionPercent)%"
    }

    var totalXPGainedText: String {
        "\(max(0, totalXPGained)) XP"
    }

    var displayTotalTaskCount: Int {
        max(0, totalTaskCount)
    }

    var displayCompletedTaskCount: Int {
        min(max(0, totalCompletedTaskCount), displayTotalTaskCount)
    }

    var completionCountText: String {
        "\(displayCompletedTaskCount)/\(displayTotalTaskCount)"
    }

    var completionSummaryText: String {
        "完成 \(completionCountText)"
    }
}

enum DailyReviewInsightKind: Equatable {
    case noData
    case brokenStreak
    case weakExecution
    case strongMomentum
    case steadyExecution
    case focus
}

struct DailyReviewInsight: Equatable {
    var kind: DailyReviewInsightKind
    var title: String
    var detail: String
}

struct DailyReviewCollectionSummary: Equatable {
    var reportCount: Int
    var totalXPGained: Int
    var completedTaskCount: Int
    var totalTaskCount: Int

    var displayTotalTaskCount: Int {
        max(0, totalTaskCount)
    }

    var displayCompletedTaskCount: Int {
        min(max(0, completedTaskCount), displayTotalTaskCount)
    }

    var completionCountText: String {
        "\(displayCompletedTaskCount)/\(displayTotalTaskCount)"
    }

    var completionSummaryText: String {
        "完成 \(completionCountText)"
    }

    var completionRate: Double {
        guard displayTotalTaskCount > 0 else {
            return 0
        }

        return Double(displayCompletedTaskCount) / Double(displayTotalTaskCount)
    }

    var completionPercent: Int {
        Int(completionRate * 100)
    }

    var completionPercentText: String {
        "\(completionPercent)%"
    }

    var totalXPGainedText: String {
        "\(max(0, totalXPGained)) XP"
    }
}

struct DailyReportMetrics: Equatable {
    var completedTaskCount: Int
    var totalTaskCount: Int
    var xpGained: Int

    var xpGainedText: String {
        "\(max(0, xpGained)) XP"
    }

    var displayTotalTaskCount: Int {
        max(0, totalTaskCount)
    }

    var displayCompletedTaskCount: Int {
        min(max(0, completedTaskCount), displayTotalTaskCount)
    }

    var completionCountText: String {
        "\(displayCompletedTaskCount)/\(displayTotalTaskCount)"
    }

    var completionSummaryText: String {
        "完成 \(completionCountText)"
    }

    var completionRate: Double {
        guard displayTotalTaskCount > 0 else {
            return 0
        }
        return Double(displayCompletedTaskCount) / Double(displayTotalTaskCount)
    }

    var completionPercent: Int {
        Int(completionRate * 100)
    }

    var completionPercentText: String {
        "\(completionPercent)%"
    }
}

struct DailyReviewService {
    func generateReport(
        tasks: [TaskItem],
        quests: [Quest] = [],
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> DailyReport {
        let progressService = QuestProgressService()
        let todayTasks = progressService.todayTasks(from: tasks, date: date, calendar: calendar)
        let completedToday = todayTasks.filter { task in
            progressService.isTaskCompleted(task, on: date, calendar: calendar)
        }

        let totalCount = todayTasks.count
        let completedCount = completedToday.count
        let xpGained = completedToday.reduce(0) { $0 + max(0, $1.xpReward) }
        let rate = totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
        let completedTodayIDs = Set(completedToday.map(\.id))
        let activeMainQuests = progressService.activeQuests(from: quests)
            .filter { $0.questType == QuestType.main.rawValue }
        let activeMainQuestIDs = Set(activeMainQuests.map(\.id))
        let mainTasks = todayTasks.filter { task in
            task.taskType == QuestType.main.rawValue || task.questId.map(activeMainQuestIDs.contains) == true
        }
        let completedMainTasks = mainTasks.filter { completedTodayIDs.contains($0.id) }
        let hasMainPressure = !mainTasks.isEmpty || !activeMainQuests.isEmpty

        let summary: String
        if totalCount == 0 {
            summary = "今日暂无任务记录。明天至少写下一件能推进主线的任务。"
        } else {
            let completedTitles = limitedTitles(completedToday.map { progressService.displayTaskTitle(for: $0) })
            let pendingTitles = limitedTitles(todayTasks.filter { !$0.isCompleted }.map {
                progressService.displayTaskTitle(for: $0)
            })
            let completedBeforeTodayTitles = limitedTitles(
                todayTasks
                    .filter { $0.isCompleted && !completedTodayIDs.contains($0.id) }
                    .map { progressService.displayTaskTitle(for: $0) }
            )
            var parts = ["今日完成 \(completedCount)/\(totalCount) 项任务，获得 \(xpGained) XP。"]

            if !completedTitles.isEmpty {
                parts.append("完成：\(completedTitles)。")
            }

            if !completedBeforeTodayTitles.isEmpty {
                parts.append("非今日完成：\(completedBeforeTodayTitles)。")
            }

            if !pendingTitles.isEmpty {
                parts.append("未完成：\(pendingTitles)。")
            }

            if let activeMainQuest = progressService.currentMainQuest(from: activeMainQuests) {
                parts.append("当前主线：\(progressService.displayQuestTitle(for: activeMainQuest))。")
            }

            summary = parts.joined(separator: "\n")
        }

        let comment: String
        if totalCount == 0 {
            comment = "空白不是失败，但不能连续空白。先建立记录，再谈优化。"
        } else if hasMainPressure && completedMainTasks.isEmpty {
            comment = "主线推进不足。你完成了事务，却没有击中真正改变局面的部分。"
        } else if rate >= 0.8 {
            comment = "完成率高，值得肯定。但别膨胀，明天继续保留一件主线核心动作。"
        } else if rate >= 0.4 {
            comment = "有推进，但节奏还松。明天把任务减到更少、更硬、更可验收。"
        } else {
            comment = "今日执行偏弱。不要补一堆计划，先找出一个阻塞并处理掉。"
        }

        return DailyReport(
            date: date,
            completedTaskCount: completedCount,
            totalTaskCount: totalCount,
            xpGained: xpGained,
            summary: summary,
            companionComment: comment,
            createdAt: Date()
        )
    }

    @discardableResult
    func upsertTodayReport(
        tasks: [TaskItem],
        quests: [Quest],
        reports: [DailyReport],
        context: ModelContext,
        date: Date = Date(),
        calendar: Calendar = .current
    ) throws -> DailyReport {
        let generated = generateReport(tasks: tasks, quests: quests, date: date, calendar: calendar)

        if let existing = report(on: generated.date, from: reports, calendar: calendar) {
            apply(generated, to: existing)
            try context.save()
            return existing
        }

        context.insert(generated)
        try context.save()
        return generated
    }

    func trend(
        from reports: [DailyReport],
        days: Int = 7,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DailyReviewTrend {
        let safeDays = max(1, days)
        let todayStart = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -(safeDays - 1), to: todayStart) ?? todayStart
        let endDate = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
        let scopedReports = latestReportsPerDay(
            from: reports
                .filter { $0.date >= startDate && $0.date < endDate }
                .sorted { $0.date < $1.date },
            calendar: calendar
        )
        let dayTrends = makeDayTrends(
            from: scopedReports,
            startDate: startDate,
            days: safeDays,
            calendar: calendar
        )

        guard !scopedReports.isEmpty else {
            return DailyReviewTrend(
                reportCount: 0,
                totalCompletedTaskCount: 0,
                totalTaskCount: 0,
                totalXPGained: 0,
                averageCompletionRate: 0,
                bestCompletionRate: 0,
                currentStreakDays: 0,
                bestStreakDays: 0,
                bestDayDate: nil,
                latestReportDate: nil,
                dayTrends: dayTrends
            )
        }

        let rates = scopedReports.map { completionRate(for: $0) }
        let bestReport = scopedReports.max { lhs, rhs in
            completionRate(for: lhs) < completionRate(for: rhs)
        }
        let streak = streakMetrics(
            for: scopedReports.map(\.date),
            todayStart: todayStart,
            calendar: calendar
        )

        return DailyReviewTrend(
            reportCount: scopedReports.count,
            totalCompletedTaskCount: scopedReports.reduce(0) { $0 + metrics(for: $1).completedTaskCount },
            totalTaskCount: scopedReports.reduce(0) { $0 + metrics(for: $1).totalTaskCount },
            totalXPGained: scopedReports.reduce(0) { $0 + metrics(for: $1).xpGained },
            averageCompletionRate: rates.reduce(0, +) / Double(rates.count),
            bestCompletionRate: bestReport.map { completionRate(for: $0) } ?? 0,
            currentStreakDays: streak.current,
            bestStreakDays: streak.best,
            bestDayDate: bestReport?.date,
            latestReportDate: scopedReports.last?.date,
            dayTrends: dayTrends
        )
    }

    func completionRate(for report: DailyReport) -> Double {
        metrics(for: report).completionRate
    }

    func metrics(for report: DailyReport) -> DailyReportMetrics {
        let counts = sanitizedTaskCounts(for: report)
        return DailyReportMetrics(
            completedTaskCount: counts.completed,
            totalTaskCount: counts.total,
            xpGained: max(0, report.xpGained)
        )
    }

    func displaySummary(for report: DailyReport) -> String {
        let summary = cleanedReportText(report.summary)
        return summary.isEmpty ? "空白复盘" : summary
    }

    func displayComment(for report: DailyReport) -> String {
        cleanedReportText(report.companionComment)
    }

    func reportDeleteConfirmationTitle(for reports: [DailyReport]) -> String {
        reports.count > 1 ? "删除 \(reports.count) 篇日报" : "删除这篇日报"
    }

    func reportDeleteConfirmationMessage(for reports: [DailyReport]) -> String {
        if reports.count == 1, let report = reports.first {
            return "这会删除 \(PersonaDate.displayDate(report.date)) 的本地复盘日报。"
        }

        return "这会删除选中的 \(reports.count) 篇本地复盘日报。"
    }

    func contextText(for report: DailyReport) -> String {
        [
            cleanedReportText(report.summary),
            cleanedReportText(report.companionComment)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    func report(
        on date: Date = Date(),
        from reports: [DailyReport],
        calendar: Calendar = .current
    ) -> DailyReport? {
        reports
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    func insight(from trend: DailyReviewTrend) -> DailyReviewInsight {
        if trend.reportCount == 0 {
            return DailyReviewInsight(
                kind: .noData,
                title: "先建立记录",
                detail: "没有复盘，就没有校准。今天先生成一份日报。"
            )
        }

        if trend.currentStreakDays == 0 && trend.bestStreakDays > 0 {
            return DailyReviewInsight(
                kind: .brokenStreak,
                title: "连续已中断",
                detail: "别急着补仪式感。先恢复今天这一条记录，再谈长期节奏。"
            )
        }

        if trend.displayAverageCompletionRate < 0.4 {
            return DailyReviewInsight(
                kind: .weakExecution,
                title: "执行偏弱",
                detail: "任务量或颗粒度需要下调。明天只保留一件主线硬动作。"
            )
        }

        if trend.currentStreakDays >= 3 && trend.displayAverageCompletionRate >= 0.7 {
            return DailyReviewInsight(
                kind: .strongMomentum,
                title: "节奏稳定",
                detail: "连续记录已经形成惯性。继续把注意力压在主线上。"
            )
        }

        if trend.displayAverageCompletionRate >= 0.8 {
            return DailyReviewInsight(
                kind: .steadyExecution,
                title: "完成率高",
                detail: "数字不错，但要检查完成的是否是真正改变局面的任务。"
            )
        }

        return DailyReviewInsight(
            kind: .focus,
            title: "压缩范围",
            detail: "有推进，但还不够锋利。减少低价值任务，保留可验收动作。"
        )
    }

    func searchReports(
        _ reports: [DailyReport],
        searchText: String,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [DailyReport] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchTerms = trimmedSearch
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard !searchTerms.isEmpty else {
            return reports
        }

        return reports.filter { report in
            let metrics = metrics(for: report)
            let searchableFields = [
                displaySummary(for: report),
                displayComment(for: report),
                PersonaDate.displayDate(report.date),
                PersonaDate.relativeDayTitle(report.date, relativeTo: referenceDate, calendar: calendar),
                metrics.xpGainedText,
                "\(metrics.xpGained)xp",
                metrics.completionSummaryText,
                metrics.completionCountText,
                "完成率 \(metrics.completionPercentText)",
                metrics.completionPercentText
            ]

            return searchTerms.allSatisfy { term in
                searchableFields.contains { $0.localizedCaseInsensitiveContains(term) }
            }
        }
    }

    func summary(from reports: [DailyReport]) -> DailyReviewCollectionSummary {
        DailyReviewCollectionSummary(
            reportCount: reports.count,
            totalXPGained: reports.reduce(0) { $0 + metrics(for: $1).xpGained },
            completedTaskCount: reports.reduce(0) { $0 + metrics(for: $1).completedTaskCount },
            totalTaskCount: reports.reduce(0) { $0 + metrics(for: $1).totalTaskCount }
        )
    }

    func sortedReportsNewestFirst(_ reports: [DailyReport]) -> [DailyReport] {
        reports.sorted(by: isReportMoreRecent)
    }

    func reports(relatedTo quest: Quest, from reports: [DailyReport]) -> [DailyReport] {
        let trimmedTitle = QuestProgressService().displayQuestTitle(for: quest)
        guard !trimmedTitle.isEmpty else {
            return []
        }

        return sortedReportsNewestFirst(searchReports(reports, searchText: trimmedTitle))
    }

    private func streakMetrics(for dates: [Date], todayStart: Date, calendar: Calendar) -> (current: Int, best: Int) {
        let dayStarts = Set(dates.map { calendar.startOfDay(for: $0) })
        var current = 0
        var cursor = todayStart

        while dayStarts.contains(cursor) {
            current += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        let sortedDays = dayStarts.sorted()
        var best = 0
        var run = 0
        var previousDay: Date?

        for day in sortedDays {
            if let previousDay,
               let expectedDay = calendar.date(byAdding: .day, value: 1, to: previousDay),
               day == expectedDay {
                run += 1
            } else {
                run = 1
            }

            best = max(best, run)
            previousDay = day
        }

        return (current, best)
    }

    private func makeDayTrends(
        from reports: [DailyReport],
        startDate: Date,
        days: Int,
        calendar: Calendar
    ) -> [DailyReviewDayTrend] {
        let reportsByDay = Dictionary(grouping: reports) { report in
            calendar.startOfDay(for: report.date)
        }

        return (0..<days).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
            let dayReports = reportsByDay[day] ?? []

            return DailyReviewDayTrend(
                date: day,
                completedTaskCount: dayReports.reduce(0) { $0 + metrics(for: $1).completedTaskCount },
                totalTaskCount: dayReports.reduce(0) { $0 + metrics(for: $1).totalTaskCount },
                xpGained: dayReports.reduce(0) { $0 + metrics(for: $1).xpGained }
            )
        }
    }

    private func sanitizedTaskCounts(for report: DailyReport) -> (completed: Int, total: Int) {
        let total = max(0, report.totalTaskCount)
        let completed = min(max(0, report.completedTaskCount), total)
        return (completed, total)
    }

    private func latestReportsPerDay(from reports: [DailyReport], calendar: Calendar) -> [DailyReport] {
        var latestByDay: [Date: DailyReport] = [:]

        for report in reports {
            let day = calendar.startOfDay(for: report.date)
            guard let currentReport = latestByDay[day] else {
                latestByDay[day] = report
                continue
            }

            if isNewer(report, than: currentReport) {
                latestByDay[day] = report
            }
        }

        return latestByDay.values.sorted { $0.date < $1.date }
    }

    private func isNewer(_ lhs: DailyReport, than rhs: DailyReport) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.date > rhs.date
    }

    private func isReportMoreRecent(_ lhs: DailyReport, than rhs: DailyReport) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date > rhs.date
        }

        return lhs.createdAt > rhs.createdAt
    }

    private func limitedTitles(_ titles: [String]) -> String {
        let cleanedTitles = titles
            .map(cleanedReportText)
            .filter { !$0.isEmpty }
        let visibleTitles = Array(cleanedTitles.prefix(3))
        guard !visibleTitles.isEmpty else {
            return ""
        }

        let suffix = cleanedTitles.count > visibleTitles.count ? " 等 \(cleanedTitles.count) 项" : ""
        return visibleTitles.joined(separator: "、") + suffix
    }

    private func cleanedReportText(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func apply(_ generated: DailyReport, to existing: DailyReport) {
        existing.completedTaskCount = generated.completedTaskCount
        existing.totalTaskCount = generated.totalTaskCount
        existing.xpGained = generated.xpGained
        existing.summary = generated.summary
        existing.companionComment = generated.companionComment
    }
}
