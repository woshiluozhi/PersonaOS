import SwiftData
import SwiftUI

struct DailyReviewView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var tasks: [TaskItem]
    @Query private var quests: [Quest]
    @Query private var reports: [DailyReport]

    @State private var reportSearchText = ""
    @State private var reportsPendingDeletion: [DailyReport] = []

    private let service = DailyReviewService()

    private var sortedReports: [DailyReport] {
        service.sortedReportsNewestFirst(reports)
    }

    private var displayedReports: [DailyReport] {
        service.searchReports(sortedReports, searchText: reportSearchText)
    }

    private var displayedReportSummary: DailyReviewCollectionSummary {
        service.summary(from: displayedReports)
    }

    private var isSearchingReports: Bool {
        !reportSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var trend: DailyReviewTrend {
        service.trend(from: reports)
    }

    private var todayReport: DailyReport? {
        service.report(from: reports)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        generateTodayReport()
                    } label: {
                        Label(todayReport == nil ? "生成今日总结" : "更新今日总结", systemImage: "sparkles")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)

                    if let todayReport {
                        TodayReportStatusRow(report: todayReport)
                    } else {
                        Label("今天还没有日报", systemImage: "doc.badge.plus")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    DailyReportSearchField(searchText: $reportSearchText)

                    DailyReportSearchSummaryRow(
                        summary: displayedReportSummary,
                        totalReportCount: sortedReports.count,
                        isSearching: isSearchingReports
                    )
                }

                Section("最近 7 天") {
                    DailyReviewTrendView(
                        trend: trend,
                        insight: service.insight(from: trend)
                    )
                }

                Section("最近总结") {
                    if displayedReports.isEmpty {
                        Text(reports.isEmpty ? "暂无日报。" : "暂无符合条件的日报。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(displayedReports, id: \.id) { report in
                            DailyReportRow(report: report)
                        }
                        .onDelete { offsets in
                            queueDeleteReports(at: offsets)
                        }
                    }
                }
            }
            .navigationTitle("每日复盘")
            .confirmationDialog(
                "删除日报",
                isPresented: Binding(
                    get: { !reportsPendingDeletion.isEmpty },
                    set: { isPresented in
                        if !isPresented {
                            reportsPendingDeletion = []
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button(service.reportDeleteConfirmationTitle(for: reportsPendingDeletion), role: .destructive) {
                    deletePendingReports()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text(service.reportDeleteConfirmationMessage(for: reportsPendingDeletion))
            }
        }
    }

    private func generateTodayReport() {
        _ = try? service.upsertTodayReport(
            tasks: tasks,
            quests: quests,
            reports: reports,
            context: modelContext
        )
    }

    private func queueDeleteReports(at offsets: IndexSet) {
        reportsPendingDeletion = offsets.map { displayedReports[$0] }
    }

    private func deletePendingReports() {
        for report in reportsPendingDeletion {
            modelContext.delete(report)
        }
        try? modelContext.save()
        reportsPendingDeletion = []
    }
}

private struct TodayReportStatusRow: View {
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
            Label("今天已复盘", systemImage: "checkmark.seal.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.green)

            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
                Label(metrics.xpGainedText, systemImage: "bolt.fill")
                Label(metrics.completionSummaryText, systemImage: "checkmark.circle")
                Label("完成率 \(metrics.completionPercentText)", systemImage: "chart.bar")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !displayComment.isEmpty {
                Text(displayComment)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 96), alignment: .leading)]
    }
}

private struct DailyReportSearchField: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜索正文、点评、日期、XP、完成率", text: $searchText)
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("清空日报搜索")
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct DailyReportSearchSummaryRow: View {
    let summary: DailyReviewCollectionSummary
    let totalReportCount: Int
    let isSearching: Bool

    private var title: String {
        isSearching ? "搜索结果 \(summary.reportCount)/\(totalReportCount)" : "全部日报"
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 86), alignment: .leading)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "doc.text.magnifyingglass")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                DailyReportSummaryMetric(title: "篇", value: "\(summary.reportCount)", systemImage: "doc.text")
                DailyReportSummaryMetric(title: "XP", value: summary.totalXPGainedText, systemImage: "bolt")
                DailyReportSummaryMetric(
                    title: "完成",
                    value: summary.completionCountText,
                    systemImage: "checkmark.circle"
                )
                DailyReportSummaryMetric(
                    title: "完成率",
                    value: summary.completionPercentText,
                    systemImage: "chart.bar"
                )
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DailyReportSummaryMetric: View {
    let title: String
    let value: String
    let systemImage: String

    private var displayText: String {
        value.hasSuffix(title) ? value : "\(value) \(title)"
    }

    var body: some View {
        Label {
            Text(displayText)
                .font(.caption)
                .monospacedDigit()
        } icon: {
            Image(systemName: systemImage)
        }
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

private struct DailyReviewTrendView: View {
    let trend: DailyReviewTrend
    let insight: DailyReviewInsight

    var body: some View {
        if trend.reportCount == 0 {
            VStack(alignment: .leading, spacing: 12) {
                Text("暂无趋势数据。")
                    .foregroundStyle(.secondary)

                DailyReviewInsightRow(insight: insight)
            }
            .padding(.vertical, 4)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
                    ReviewTrendMetric(title: "记录", value: "\(trend.reportCount) 天")
                    ReviewTrendMetric(title: "连续", value: "\(trend.currentStreakDays) 天")
                    ReviewTrendMetric(title: "XP", value: trend.totalXPGainedText)
                    ReviewTrendMetric(title: "完成", value: trend.averageCompletionPercentText)
                }

                DailyReviewTrendChart(dayTrends: trend.dayTrends)

                ProgressView(value: trend.displayAverageCompletionRate)

                DailyReviewInsightRow(insight: insight)

                VStack(alignment: .leading, spacing: 4) {
                    Text(trend.completionSummaryText)
                        .font(.subheadline)

                    if let bestDayDate = trend.bestDayDate {
                        Text("最佳：\(PersonaDate.displayDate(bestDayDate)) · \(trend.bestCompletionPercentText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("最长连续 \(trend.bestStreakDays) 天")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 72), alignment: .leading)]
    }
}

private struct DailyReviewInsightRow: View {
    let insight: DailyReviewInsight

    private var systemImage: String {
        switch insight.kind {
        case .noData:
            return "doc.badge.plus"
        case .brokenStreak:
            return "arrow.counterclockwise"
        case .weakExecution:
            return "exclamationmark.triangle"
        case .strongMomentum:
            return "flame"
        case .steadyExecution:
            return "checkmark.seal"
        case .focus:
            return "scope"
        }
    }

    private var tint: Color {
        switch insight.kind {
        case .noData:
            return .accentColor
        case .brokenStreak, .weakExecution:
            return .orange
        case .strongMomentum, .steadyExecution:
            return .green
        case .focus:
            return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(insight.title, systemImage: systemImage)
                .font(.subheadline.bold())
                .foregroundStyle(tint)

            Text(insight.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct DailyReviewTrendChart: View {
    let dayTrends: [DailyReviewDayTrend]

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(dayTrends, id: \.date) { dayTrend in
                DailyReviewTrendBar(dayTrend: dayTrend)
            }
        }
        .frame(height: 104)
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct DailyReviewTrendBar: View {
    let dayTrend: DailyReviewDayTrend

    var body: some View {
        VStack(spacing: 6) {
            Text(dayTrend.completionPercentText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            GeometryReader { proxy in
                let filledHeight = max(
                    dayTrend.totalTaskCount == 0 ? 2 : 6,
                    proxy.size.height * dayTrend.completionRate
                )

                ZStack(alignment: .bottom) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.16))

                    Capsule()
                        .fill(dayTrend.totalTaskCount == 0 ? Color.secondary.opacity(0.35) : Color.accentColor)
                        .frame(height: filledHeight)
                }
            }
            .frame(height: 56)

            Text(PersonaDate.shortWeekday(dayTrend.date))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(PersonaDate.displayDate(dayTrend.date))，\(dayTrend.completionSummaryText)，\(dayTrend.xpGainedText)")
    }
}

private struct ReviewTrendMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DailyReportRow: View {
    let report: DailyReport

    private let service = DailyReviewService()

    private var metrics: DailyReportMetrics {
        service.metrics(for: report)
    }

    private var displayComment: String {
        service.displayComment(for: report)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(PersonaDate.displayDate(report.date))
                    .font(.headline)
                Spacer()
                Text(metrics.xpGainedText)
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }

            Text(metrics.completionSummaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(service.displaySummary(for: report))
                .font(.body)

            if !displayComment.isEmpty {
                Text(displayComment)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
