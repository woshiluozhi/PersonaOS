import SwiftData
import XCTest
@testable import PersonaOS

@MainActor
final class DailyReviewServiceTests: XCTestCase {
    private var retainedContainers: [ModelContainer] = []

    func testGenerateReportFromTasks() {
        let service = DailyReviewService()
        let today = Date()
        let completed = TaskItem(title: "完成 MVP", isCompleted: true, xpReward: 40, dueDate: today, completedAt: today)
        let pending = TaskItem(title: "复盘主线", isCompleted: false, xpReward: 20, dueDate: today)

        let report = service.generateReport(tasks: [completed, pending], date: today)

        XCTAssertEqual(report.completedTaskCount, 1)
        XCTAssertEqual(report.totalTaskCount, 2)
        XCTAssertEqual(report.xpGained, 40)
        XCTAssertTrue(report.summary.contains("完成 MVP"))
        XCTAssertTrue(report.summary.contains("复盘主线"))
    }

    func testDifferentCompletionRatesProduceDifferentComments() {
        let service = DailyReviewService()
        let today = Date()
        let completed = TaskItem(title: "完成", isCompleted: true, xpReward: 10, dueDate: today, completedAt: today)
        let pending = TaskItem(title: "未完成", isCompleted: false, xpReward: 10, dueDate: today)

        let high = service.generateReport(tasks: [completed], date: today)
        let low = service.generateReport(tasks: [completed, pending, pending], date: today)

        XCTAssertNotEqual(high.companionComment, low.companionComment)
    }

    func testEmptyTasksDoNotCrash() {
        let service = DailyReviewService()

        let report = service.generateReport(tasks: [])

        XCTAssertEqual(report.completedTaskCount, 0)
        XCTAssertEqual(report.totalTaskCount, 0)
        XCTAssertFalse(report.companionComment.isEmpty)
    }

    func testActiveMainQuestWithoutCompletedMainTaskIsCalledOut() {
        let service = DailyReviewService()
        let today = Date()
        let activeMainQuest = Quest(title: "构建 PersonaOS", questType: QuestType.main.rawValue)
        let dailyDone = TaskItem(title: "整理资料", isCompleted: true, xpReward: 10, dueDate: today, completedAt: today)

        let report = service.generateReport(tasks: [dailyDone], quests: [activeMainQuest], date: today)

        XCTAssertTrue(report.summary.contains("当前主线：构建 PersonaOS"))
        XCTAssertTrue(report.companionComment.contains("主线推进不足"))
    }

    func testDailyTaskLinkedToMainQuestCountsAsMainProgress() {
        let service = DailyReviewService()
        let today = Date()
        let activeMainQuest = Quest(title: "构建 PersonaOS", questType: QuestType.main.rawValue)
        let linkedDailyDone = TaskItem(
            title: "推进 MVP",
            taskType: QuestType.daily.rawValue,
            questId: activeMainQuest.id,
            isCompleted: true,
            xpReward: 20,
            dueDate: today,
            completedAt: today
        )

        let report = service.generateReport(tasks: [linkedDailyDone], quests: [activeMainQuest], date: today)

        XCTAssertFalse(report.companionComment.contains("主线推进不足"))
        XCTAssertTrue(report.summary.contains("当前主线：构建 PersonaOS"))
    }

    func testMainProgressRequiresCompletionOnReportDate() {
        let service = DailyReviewService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400 * 10)
        let yesterday = Date(timeInterval: -86_400, since: today)
        let mainDoneYesterday = TaskItem(
            title: "提前完成主线",
            taskType: QuestType.main.rawValue,
            isCompleted: true,
            xpReward: 30,
            dueDate: today,
            completedAt: yesterday
        )

        let report = service.generateReport(
            tasks: [mainDoneYesterday],
            date: today,
            calendar: calendar
        )

        XCTAssertEqual(report.completedTaskCount, 0)
        XCTAssertTrue(report.companionComment.contains("主线推进不足"))
    }

    func testReportSummaryCallsOutTasksCompletedBeforeReportDate() {
        let service = DailyReviewService()
        let calendar = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 86_400 * 10)
        let yesterday = Date(timeInterval: -86_400, since: today)
        let completedYesterday = TaskItem(
            title: "提前完成",
            taskType: QuestType.side.rawValue,
            isCompleted: true,
            xpReward: 20,
            dueDate: today,
            completedAt: yesterday
        )
        let pending = TaskItem(
            title: "今日未做",
            xpReward: 10,
            dueDate: today
        )

        let report = service.generateReport(
            tasks: [completedYesterday, pending],
            date: today,
            calendar: calendar
        )

        XCTAssertEqual(report.completedTaskCount, 0)
        XCTAssertEqual(report.totalTaskCount, 2)
        XCTAssertEqual(report.xpGained, 0)
        XCTAssertTrue(report.summary.contains("非今日完成：提前完成"))
        XCTAssertTrue(report.summary.contains("未完成：今日未做"))
    }

    func testUpsertTodayReportCreatesReport() throws {
        let context = try makeContext()
        let service = DailyReviewService()
        let today = Date()
        let task = TaskItem(title: "完成一个闭环", isCompleted: true, xpReward: 25, dueDate: today, completedAt: today)
        context.insert(task)

        let report = try service.upsertTodayReport(
            tasks: [task],
            quests: [],
            reports: [],
            context: context,
            date: today
        )

        let storedReports = try context.fetch(FetchDescriptor<DailyReport>())
        XCTAssertEqual(storedReports.count, 1)
        XCTAssertEqual(report.xpGained, 25)
        XCTAssertEqual(storedReports.first?.completedTaskCount, 1)
    }

    func testUpsertTodayReportUpdatesExistingReport() throws {
        let context = try makeContext()
        let service = DailyReviewService()
        let today = Date()
        let existing = DailyReport(
            date: today,
            completedTaskCount: 0,
            totalTaskCount: 1,
            xpGained: 0,
            summary: "旧总结",
            companionComment: "旧点评"
        )
        let task = TaskItem(title: "完成主线动作", isCompleted: true, xpReward: 35, dueDate: today, completedAt: today)
        context.insert(existing)
        context.insert(task)
        try context.save()

        let report = try service.upsertTodayReport(
            tasks: [task],
            quests: [],
            reports: [existing],
            context: context,
            date: today
        )

        let storedReports = try context.fetch(FetchDescriptor<DailyReport>())
        XCTAssertEqual(storedReports.count, 1)
        XCTAssertIdentical(report, existing)
        XCTAssertEqual(existing.completedTaskCount, 1)
        XCTAssertEqual(existing.xpGained, 35)
        XCTAssertNotEqual(existing.summary, "旧总结")
    }

    func testReportOnDateReturnsNewestReportForThatDay() throws {
        let service = DailyReviewService()
        let calendar = Calendar(identifier: .gregorian)
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 9)))
        let sameDayLater = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 18)))
        let otherDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 9)))
        let older = DailyReport(date: day, summary: "旧日报", createdAt: day)
        let newer = DailyReport(date: sameDayLater, summary: "新日报", createdAt: sameDayLater)
        let unrelated = DailyReport(date: otherDay, summary: "明天日报", createdAt: otherDay)

        let report = service.report(on: day, from: [older, unrelated, newer], calendar: calendar)

        XCTAssertIdentical(report, newer)
        XCTAssertNil(service.report(on: Date(timeIntervalSince1970: 0), from: [older, newer], calendar: calendar))
    }

    func testTrendUsesRecentReportsOnly() throws {
        let service = DailyReviewService()
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 12)))
        let today = calendar.startOfDay(for: now)
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))
        let oldDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -8, to: today))
        let todayReport = DailyReport(
            date: today,
            completedTaskCount: 1,
            totalTaskCount: 2,
            xpGained: 10
        )
        let yesterdayReport = DailyReport(
            date: yesterday,
            completedTaskCount: 2,
            totalTaskCount: 2,
            xpGained: 25
        )
        let oldReport = DailyReport(
            date: oldDay,
            completedTaskCount: 3,
            totalTaskCount: 3,
            xpGained: 50
        )

        let trend = service.trend(
            from: [oldReport, todayReport, yesterdayReport],
            days: 7,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(trend.reportCount, 2)
        XCTAssertEqual(trend.totalCompletedTaskCount, 3)
        XCTAssertEqual(trend.totalTaskCount, 4)
        XCTAssertEqual(trend.completionCountText, "3/4")
        XCTAssertEqual(trend.completionSummaryText, "完成 3/4")
        XCTAssertEqual(trend.totalXPGained, 35)
        XCTAssertEqual(trend.totalXPGainedText, "35 XP")
        XCTAssertEqual(trend.averageCompletionRate, 0.75, accuracy: 0.001)
        XCTAssertEqual(trend.bestCompletionRate, 1.0, accuracy: 0.001)
        XCTAssertEqual(trend.displayAverageCompletionRate, 0.75, accuracy: 0.001)
        XCTAssertEqual(trend.displayBestCompletionRate, 1.0, accuracy: 0.001)
        XCTAssertEqual(trend.averageCompletionPercent, 75)
        XCTAssertEqual(trend.averageCompletionPercentText, "75%")
        XCTAssertEqual(trend.bestCompletionPercent, 100)
        XCTAssertEqual(trend.bestCompletionPercentText, "100%")
        XCTAssertEqual(trend.currentStreakDays, 2)
        XCTAssertEqual(trend.bestStreakDays, 2)
        XCTAssertEqual(trend.bestDayDate, yesterday)
        XCTAssertEqual(trend.latestReportDate, today)
    }

    func testTrendUsesNewestReportPerDay() throws {
        let service = DailyReviewService()
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 12)))
        let sameDayMorning = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 9)))
        let sameDayEvening = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 20)))
        let olderReport = DailyReport(
            date: sameDayMorning,
            completedTaskCount: 1,
            totalTaskCount: 3,
            xpGained: 10,
            createdAt: sameDayMorning
        )
        let newerReport = DailyReport(
            date: sameDayEvening,
            completedTaskCount: 2,
            totalTaskCount: 2,
            xpGained: 30,
            createdAt: sameDayEvening
        )

        let trend = service.trend(
            from: [olderReport, newerReport],
            days: 7,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(trend.reportCount, 1)
        XCTAssertEqual(trend.totalCompletedTaskCount, 2)
        XCTAssertEqual(trend.totalTaskCount, 2)
        XCTAssertEqual(trend.completionCountText, "2/2")
        XCTAssertEqual(trend.totalXPGained, 30)
        XCTAssertEqual(trend.totalXPGainedText, "30 XP")
        XCTAssertEqual(trend.averageCompletionRate, 1.0, accuracy: 0.001)
        XCTAssertEqual(trend.averageCompletionPercent, 100)
        XCTAssertEqual(trend.averageCompletionPercentText, "100%")
        XCTAssertEqual(trend.bestDayDate, sameDayEvening)
        XCTAssertEqual(trend.latestReportDate, sameDayEvening)
        XCTAssertEqual(trend.dayTrends.last?.completedTaskCount, 2)
        XCTAssertEqual(trend.dayTrends.last?.totalTaskCount, 2)
        XCTAssertEqual(trend.dayTrends.last?.xpGained, 30)
    }

    func testTrendBuildsDailySnapshotsForFullWindow() throws {
        let service = DailyReviewService()
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 12)))
        let today = calendar.startOfDay(for: now)
        let twoDaysAgo = try XCTUnwrap(calendar.date(byAdding: .day, value: -2, to: today))
        let startDate = try XCTUnwrap(calendar.date(byAdding: .day, value: -6, to: today))
        let todayReport = DailyReport(
            date: today,
            completedTaskCount: 1,
            totalTaskCount: 2,
            xpGained: 10
        )
        let earlierReport = DailyReport(
            date: twoDaysAgo,
            completedTaskCount: 3,
            totalTaskCount: 4,
            xpGained: 40
        )

        let trend = service.trend(
            from: [todayReport, earlierReport],
            days: 7,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(trend.dayTrends.count, 7)
        XCTAssertEqual(trend.dayTrends.first?.date, startDate)
        XCTAssertEqual(trend.dayTrends.last?.date, today)
        XCTAssertEqual(trend.dayTrends[4].date, twoDaysAgo)
        XCTAssertEqual(trend.dayTrends[4].completedTaskCount, 3)
        XCTAssertEqual(trend.dayTrends[4].totalTaskCount, 4)
        XCTAssertEqual(trend.dayTrends[4].completionCountText, "3/4")
        XCTAssertEqual(trend.dayTrends[4].completionSummaryText, "完成 3/4")
        XCTAssertEqual(trend.dayTrends[4].xpGained, 40)
        XCTAssertEqual(trend.dayTrends[4].xpGainedText, "40 XP")
        XCTAssertEqual(trend.dayTrends[4].completionRate, 0.75, accuracy: 0.001)
        XCTAssertEqual(trend.dayTrends[4].completionPercent, 75)
        XCTAssertEqual(trend.dayTrends[4].completionPercentText, "75%")
        XCTAssertEqual(trend.dayTrends[5].totalTaskCount, 0)
        XCTAssertEqual(trend.dayTrends[5].completionRate, 0)
        XCTAssertEqual(trend.dayTrends[5].completionPercent, 0)
        XCTAssertEqual(trend.dayTrends[5].completionPercentText, "0%")
    }

    func testSearchReportsMatchesSummaryAndComment() {
        let service = DailyReviewService()
        let mainReport = DailyReport(summary: "主线推进明显", companionComment: "继续保持")
        let riskReport = DailyReport(summary: "普通记录", companionComment: "主线推进不足")
        let unrelated = DailyReport(summary: "无关", companionComment: "无关")

        let summaryResults = service.searchReports([mainReport, riskReport, unrelated], searchText: "明显")
        let commentResults = service.searchReports([mainReport, riskReport, unrelated], searchText: "不足")

        XCTAssertEqual(summaryResults.map(\.summary), ["主线推进明显"])
        XCTAssertEqual(commentResults.map(\.companionComment), ["主线推进不足"])
    }

    func testSearchReportsUsesCleanTextAndBlankSummaryFallback() {
        let service = DailyReviewService()
        let blank = DailyReport(summary: " \n\t ", companionComment: "  ")
        let messy = DailyReport(summary: " 主线\n\n推进\t记录 ", companionComment: " 点评\n细节 ")

        XCTAssertEqual(service.displaySummary(for: blank), "空白复盘")
        XCTAssertEqual(service.displayComment(for: blank), "")
        XCTAssertEqual(service.contextText(for: blank), "")
        XCTAssertEqual(service.displaySummary(for: messy), "主线 推进 记录")
        XCTAssertEqual(service.displayComment(for: messy), "点评 细节")
        XCTAssertEqual(service.contextText(for: messy), "主线 推进 记录 点评 细节")
        XCTAssertEqual(service.searchReports([blank, messy], searchText: "主线 记录").map(\.summary), [" 主线\n\n推进\t记录 "])
        XCTAssertEqual(service.searchReports([messy], searchText: "点评 细节").map(\.summary), [" 主线\n\n推进\t记录 "])
        XCTAssertEqual(service.searchReports([blank], searchText: "空白复盘").map(\.summary), [" \n\t "])
    }

    func testSearchReportsMatchesDateXPAndCompletionRatio() throws {
        let service = DailyReviewService()
        let calendar = Calendar(identifier: .gregorian)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7)))
        let report = DailyReport(
            date: date,
            completedTaskCount: 1,
            totalTaskCount: 2,
            xpGained: 40,
            summary: "普通日报"
        )
        let unrelated = DailyReport(
            date: Date(timeIntervalSince1970: 0),
            completedTaskCount: 0,
            totalTaskCount: 3,
            xpGained: 5,
            summary: "无关日报"
        )
        let reports = [report, unrelated]

        XCTAssertEqual(service.searchReports(reports, searchText: "2026").map(\.summary), ["普通日报"])
        XCTAssertEqual(service.searchReports(reports, searchText: "40 XP").map(\.summary), ["普通日报"])
        XCTAssertEqual(service.searchReports(reports, searchText: "1/2").map(\.summary), ["普通日报"])
        XCTAssertEqual(service.searchReports(reports, searchText: "50%").map(\.summary), ["普通日报"])
    }

    func testSearchReportsMatchesRelativeDateMetadata() throws {
        let service = DailyReviewService()
        let calendar = Calendar(identifier: .gregorian)
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7)))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))
        let yesterdayReport = DailyReport(date: yesterday, summary: "昨日日报")
        let todayReport = DailyReport(date: today, summary: "今日日报")

        let results = service.searchReports(
            [todayReport, yesterdayReport],
            searchText: "昨天",
            referenceDate: today,
            calendar: calendar
        )

        XCTAssertEqual(results.map(\.summary), ["昨日日报"])
    }

    func testSearchReportsMatchesMultipleTermsAcrossSummaryAndDate() throws {
        let service = DailyReviewService()
        let calendar = Calendar(identifier: .gregorian)
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7)))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))
        let yesterdayMain = DailyReport(date: yesterday, summary: "主线推进明显")
        let todayMain = DailyReport(date: today, summary: "主线推进明显")
        let yesterdaySide = DailyReport(date: yesterday, summary: "支线推进明显")

        let results = service.searchReports(
            [todayMain, yesterdaySide, yesterdayMain],
            searchText: "主线 昨天",
            referenceDate: today,
            calendar: calendar
        )

        XCTAssertEqual(results.map(\.summary), ["主线推进明显"])
        XCTAssertEqual(results.first?.date, yesterday)
    }

    func testSummaryAggregatesReports() {
        let service = DailyReviewService()
        let first = DailyReport(
            completedTaskCount: 1,
            totalTaskCount: 2,
            xpGained: 40
        )
        let second = DailyReport(
            completedTaskCount: 2,
            totalTaskCount: 3,
            xpGained: 30
        )

        let summary = service.summary(from: [first, second])

        XCTAssertEqual(summary.reportCount, 2)
        XCTAssertEqual(summary.totalXPGained, 70)
        XCTAssertEqual(summary.totalXPGainedText, "70 XP")
        XCTAssertEqual(summary.completedTaskCount, 3)
        XCTAssertEqual(summary.totalTaskCount, 5)
        XCTAssertEqual(summary.completionCountText, "3/5")
        XCTAssertEqual(summary.completionSummaryText, "完成 3/5")
        XCTAssertEqual(summary.completionRate, 0.6, accuracy: 0.001)
        XCTAssertEqual(summary.completionPercent, 60)
        XCTAssertEqual(summary.completionPercentText, "60%")
    }

    func testSummaryClampsInvalidReportMetrics() {
        let service = DailyReviewService()
        let overCompleted = DailyReport(
            completedTaskCount: 5,
            totalTaskCount: 2,
            xpGained: -10
        )
        let negativeCompleted = DailyReport(
            completedTaskCount: -1,
            totalTaskCount: 3,
            xpGained: 20
        )

        let summary = service.summary(from: [overCompleted, negativeCompleted])

        XCTAssertEqual(summary.reportCount, 2)
        XCTAssertEqual(summary.totalXPGained, 20)
        XCTAssertEqual(summary.totalXPGainedText, "20 XP")
        XCTAssertEqual(summary.completedTaskCount, 2)
        XCTAssertEqual(summary.totalTaskCount, 5)
        XCTAssertEqual(summary.completionCountText, "2/5")
        XCTAssertEqual(summary.completionRate, 0.4, accuracy: 0.001)
        XCTAssertEqual(summary.completionPercent, 40)
        XCTAssertEqual(summary.completionPercentText, "40%")
    }

    func testReportDeleteConfirmationCopyUsesDateAndCount() throws {
        let service = DailyReviewService()
        let calendar = Calendar(identifier: .gregorian)
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 7)))
        let report = DailyReport(date: day)
        let second = DailyReport(date: Date(timeInterval: 86_400, since: day))

        XCTAssertEqual(service.reportDeleteConfirmationTitle(for: [report]), "删除这篇日报")
        XCTAssertEqual(
            service.reportDeleteConfirmationMessage(for: [report]),
            "这会删除 \(PersonaDate.displayDate(day)) 的本地复盘日报。"
        )
        XCTAssertEqual(service.reportDeleteConfirmationTitle(for: [report, second]), "删除 2 篇日报")
        XCTAssertEqual(
            service.reportDeleteConfirmationMessage(for: [report, second]),
            "这会删除选中的 2 篇本地复盘日报。"
        )
    }

    func testSortedReportsUseReportDateBeforeCreatedAt() {
        let service = DailyReviewService()
        let oldDateCreatedLater = DailyReport(
            date: Date(timeIntervalSince1970: 10),
            summary: "旧日期后创建",
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let newestDateCreatedEarlier = DailyReport(
            date: Date(timeIntervalSince1970: 30),
            summary: "新日期先创建",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let sameDateCreatedLater = DailyReport(
            date: Date(timeIntervalSince1970: 30),
            summary: "新日期后创建",
            createdAt: Date(timeIntervalSince1970: 2)
        )

        let results = service.sortedReportsNewestFirst([
            oldDateCreatedLater,
            newestDateCreatedEarlier,
            sameDateCreatedLater
        ])

        XCTAssertEqual(results.map(\.summary), [
            "新日期后创建",
            "新日期先创建",
            "旧日期后创建"
        ])
    }

    func testMetricsAndSearchUseClampedReportValues() {
        let service = DailyReviewService()
        let report = DailyReport(
            completedTaskCount: 5,
            totalTaskCount: 2,
            xpGained: -10,
            summary: "异常日报"
        )

        let metrics = service.metrics(for: report)

        XCTAssertEqual(metrics.completedTaskCount, 2)
        XCTAssertEqual(metrics.totalTaskCount, 2)
        XCTAssertEqual(metrics.completionCountText, "2/2")
        XCTAssertEqual(metrics.completionSummaryText, "完成 2/2")
        XCTAssertEqual(metrics.xpGained, 0)
        XCTAssertEqual(metrics.xpGainedText, "0 XP")
        XCTAssertEqual(metrics.completionPercent, 100)
        XCTAssertEqual(metrics.completionPercentText, "100%")
        XCTAssertEqual(service.searchReports([report], searchText: "2/2").map(\.summary), ["异常日报"])
        XCTAssertEqual(service.searchReports([report], searchText: "0 XP").map(\.summary), ["异常日报"])
        XCTAssertTrue(service.searchReports([report], searchText: "-10 XP").isEmpty)
        XCTAssertTrue(service.searchReports([report], searchText: "5/2").isEmpty)
    }

    func testTrendClampsInvalidReportMetrics() {
        let service = DailyReviewService()
        let calendar = Calendar(identifier: .gregorian)
        let report = DailyReport(
            date: Date(timeIntervalSince1970: 0),
            completedTaskCount: 3,
            totalTaskCount: 2,
            xpGained: -10
        )

        let trend = service.trend(
            from: [report],
            days: 1,
            now: report.date,
            calendar: calendar
        )

        XCTAssertEqual(trend.totalCompletedTaskCount, 2)
        XCTAssertEqual(trend.totalTaskCount, 2)
        XCTAssertEqual(trend.completionCountText, "2/2")
        XCTAssertEqual(trend.totalXPGained, 0)
        XCTAssertEqual(trend.totalXPGainedText, "0 XP")
        XCTAssertEqual(trend.averageCompletionRate, 1, accuracy: 0.001)
        XCTAssertEqual(trend.bestCompletionRate, 1, accuracy: 0.001)
        XCTAssertEqual(trend.averageCompletionPercent, 100)
        XCTAssertEqual(trend.averageCompletionPercentText, "100%")
        XCTAssertEqual(trend.bestCompletionPercent, 100)
        XCTAssertEqual(trend.bestCompletionPercentText, "100%")
        XCTAssertEqual(trend.dayTrends.first?.completedTaskCount, 2)
        XCTAssertEqual(trend.dayTrends.first?.totalTaskCount, 2)
        XCTAssertEqual(trend.dayTrends.first?.completionCountText, "2/2")
        XCTAssertEqual(trend.dayTrends.first?.xpGained, 0)
        XCTAssertEqual(trend.dayTrends.first?.xpGainedText, "0 XP")
        XCTAssertEqual(trend.dayTrends.first?.completionRate, 1)
        XCTAssertEqual(trend.dayTrends.first?.completionPercent, 100)
    }

    func testReviewXPTextClampsDirtyValues() {
        let dayTrend = DailyReviewDayTrend(
            date: Date(timeIntervalSince1970: 0),
            completedTaskCount: 0,
            totalTaskCount: 1,
            xpGained: -10
        )
        let trend = makeTrend(reportCount: 1, totalXPGained: -20)
        let summary = DailyReviewCollectionSummary(
            reportCount: 1,
            totalXPGained: -30,
            completedTaskCount: 0,
            totalTaskCount: 1
        )
        let metrics = DailyReportMetrics(
            completedTaskCount: 0,
            totalTaskCount: 1,
            xpGained: -40
        )

        XCTAssertEqual(dayTrend.xpGainedText, "0 XP")
        XCTAssertEqual(trend.totalXPGainedText, "0 XP")
        XCTAssertEqual(summary.totalXPGainedText, "0 XP")
        XCTAssertEqual(metrics.xpGainedText, "0 XP")
    }

    func testReviewCompletionCountTextClampsDirtyValues() {
        let dayTrend = DailyReviewDayTrend(
            date: Date(timeIntervalSince1970: 0),
            completedTaskCount: 5,
            totalTaskCount: 2,
            xpGained: 0
        )
        let trend = makeTrend(
            reportCount: 1,
            totalCompletedTaskCount: 5,
            totalTaskCount: 2
        )
        let summary = DailyReviewCollectionSummary(
            reportCount: 1,
            totalXPGained: 0,
            completedTaskCount: 5,
            totalTaskCount: 2
        )
        let metrics = DailyReportMetrics(
            completedTaskCount: 5,
            totalTaskCount: 2,
            xpGained: 0
        )

        XCTAssertEqual(dayTrend.displayCompletedTaskCount, 2)
        XCTAssertEqual(dayTrend.displayTotalTaskCount, 2)
        XCTAssertEqual(dayTrend.completionCountText, "2/2")
        XCTAssertEqual(dayTrend.completionSummaryText, "完成 2/2")
        XCTAssertEqual(trend.completionCountText, "2/2")
        XCTAssertEqual(trend.completionSummaryText, "完成 2/2")
        XCTAssertEqual(summary.completionCountText, "2/2")
        XCTAssertEqual(summary.completionSummaryText, "完成 2/2")
        XCTAssertEqual(metrics.completionCountText, "2/2")
        XCTAssertEqual(metrics.completionSummaryText, "完成 2/2")
    }

    func testReviewCompletionPercentTextClampsDirtyRates() {
        let low = makeTrend(
            reportCount: 1,
            averageCompletionRate: -0.2,
            bestCompletionRate: -0.1
        )
        let high = makeTrend(
            reportCount: 1,
            averageCompletionRate: 1.2,
            bestCompletionRate: 1.5
        )

        XCTAssertEqual(low.displayAverageCompletionRate, 0)
        XCTAssertEqual(low.displayBestCompletionRate, 0)
        XCTAssertEqual(low.averageCompletionPercent, 0)
        XCTAssertEqual(low.averageCompletionPercentText, "0%")
        XCTAssertEqual(low.bestCompletionPercent, 0)
        XCTAssertEqual(low.bestCompletionPercentText, "0%")
        XCTAssertEqual(high.displayAverageCompletionRate, 1)
        XCTAssertEqual(high.displayBestCompletionRate, 1)
        XCTAssertEqual(high.averageCompletionPercent, 100)
        XCTAssertEqual(high.averageCompletionPercentText, "100%")
        XCTAssertEqual(high.bestCompletionPercent, 100)
        XCTAssertEqual(high.bestCompletionPercentText, "100%")
    }

    func testRelatedReportsMatchQuestTitleAndSortNewestFirst() {
        let service = DailyReviewService()
        let quest = Quest(title: "构建 PersonaOS")
        let oldReport = DailyReport(
            date: Date(timeIntervalSince1970: 10),
            summary: "构建 PersonaOS 有推进"
        )
        let sameDayOlderReport = DailyReport(
            date: Date(timeIntervalSince1970: 20),
            summary: "构建 PersonaOS 同日早些记录",
            createdAt: Date(timeIntervalSince1970: 21)
        )
        let newReport = DailyReport(
            date: Date(timeIntervalSince1970: 20),
            summary: "普通日报",
            companionComment: "构建 PersonaOS 的主线压力仍在",
            createdAt: Date(timeIntervalSince1970: 22)
        )
        let unrelated = DailyReport(
            date: Date(timeIntervalSince1970: 30),
            summary: "无关日报"
        )

        let results = service.reports(
            relatedTo: quest,
            from: [oldReport, sameDayOlderReport, unrelated, newReport]
        )

        XCTAssertEqual(results.map(\.summary), [
            "普通日报",
            "构建 PersonaOS 同日早些记录",
            "构建 PersonaOS 有推进"
        ])
    }

    func testInsightAsksForRecordWhenTrendIsEmpty() {
        let service = DailyReviewService()

        let insight = service.insight(from: makeTrend(reportCount: 0))

        XCTAssertEqual(insight.kind, .noData)
        XCTAssertTrue(insight.detail.contains("日报"))
    }

    func testInsightCallsOutBrokenStreakBeforeWeakExecution() {
        let service = DailyReviewService()
        let trend = makeTrend(
            reportCount: 2,
            averageCompletionRate: 0.2,
            currentStreakDays: 0,
            bestStreakDays: 2
        )

        let insight = service.insight(from: trend)

        XCTAssertEqual(insight.kind, .brokenStreak)
    }

    func testInsightCallsOutWeakExecution() {
        let service = DailyReviewService()
        let trend = makeTrend(
            reportCount: 2,
            averageCompletionRate: 0.3,
            currentStreakDays: 1,
            bestStreakDays: 1
        )

        let insight = service.insight(from: trend)

        XCTAssertEqual(insight.kind, .weakExecution)
    }

    func testInsightRecognizesStrongMomentum() {
        let service = DailyReviewService()
        let trend = makeTrend(
            reportCount: 4,
            averageCompletionRate: 0.75,
            currentStreakDays: 4,
            bestStreakDays: 4
        )

        let insight = service.insight(from: trend)

        XCTAssertEqual(insight.kind, .strongMomentum)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Quest.self,
            TaskItem.self,
            DailyReport.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        retainedContainers.append(container)
        return container.mainContext
    }

    private func makeTrend(
        reportCount: Int,
        totalCompletedTaskCount: Int = 0,
        totalTaskCount: Int = 0,
        totalXPGained: Int = 0,
        averageCompletionRate: Double = 0,
        bestCompletionRate: Double = 0,
        currentStreakDays: Int = 0,
        bestStreakDays: Int = 0
    ) -> DailyReviewTrend {
        DailyReviewTrend(
            reportCount: reportCount,
            totalCompletedTaskCount: totalCompletedTaskCount,
            totalTaskCount: totalTaskCount,
            totalXPGained: totalXPGained,
            averageCompletionRate: averageCompletionRate,
            bestCompletionRate: bestCompletionRate,
            currentStreakDays: currentStreakDays,
            bestStreakDays: bestStreakDays,
            bestDayDate: nil,
            latestReportDate: nil,
            dayTrends: []
        )
    }
}
