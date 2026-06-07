import SwiftData
import SwiftUI

struct DashboardView: View {
    @Binding var selection: MainTab
    let startupNote: String?

    @Environment(\.modelContext) private var modelContext

    @Query private var users: [UserProfile]
    @Query private var companions: [CompanionPersona]
    @Query private var tasks: [TaskItem]
    @Query private var quests: [Quest]
    @Query private var reports: [DailyReport]

    @State private var showingAddTask = false
    @State private var showingSettings = false

    private let service = QuestProgressService()
    private let dailyReviewService = DailyReviewService()

    private var dashboardData: DashboardData {
        service.makeDashboardData(
            user: users.first,
            companion: companions.first,
            tasks: tasks,
            quests: quests,
            dailyReports: reports
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let startupNote {
                        DashboardCard(title: "启动提示") {
                            Text(startupNote)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    DashboardCard(title: "PersonaOS") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("药老已苏醒。")
                                .font(.title2.bold())

                            Text("今日主线：\(dashboardData.currentMainQuestTitle)。")
                                .font(.headline)

                            Text(dashboardData.companionComment)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    DashboardCard(title: "今日行动") {
                        TodayActionCard(
                            recommendation: dashboardData.todayRecommendation,
                            hasTodayReport: dashboardData.hasTodayReport,
                            action: handleTodayAction
                        )
                    }

                    DashboardCard(title: "状态面板") {
                        VStack(spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(dashboardData.userName)
                                        .font(.title3.bold())
                                    Text("伴生智能体：\(dashboardData.companionName)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Lv. \(dashboardData.level)")
                                        .font(.title3.bold())
                                    Text(dashboardData.currentXPText)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(dashboardData.xpToNextLevelText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Divider()

                            HStack(spacing: 10) {
                                StatMetric(title: "精力", value: dashboardData.energy, tint: .green)
                                StatMetric(title: "专注", value: dashboardData.focus, tint: .blue)
                                StatMetric(title: "压力", value: dashboardData.stress, tint: .orange)
                            }
                        }
                    }

                    DashboardCard(title: "今日推进") {
                        VStack(alignment: .leading, spacing: 10) {
                            ProgressView(value: dashboardData.todayCompletionRate)
                            Text("完成 \(dashboardData.todayCompletedCount)/\(dashboardData.todayTotalCount)，完成率 \(dashboardData.todayCompletionPercentText)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if dashboardData.overdueTaskCount > 0 {
                                Label("\(dashboardData.overdueTaskCount) 项逾期", systemImage: "exclamationmark.triangle")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.orange)
                            }

                            TodayPlanSummaryView(summary: dashboardData.todayPlanSummary)
                        }
                    }

                    DashboardCard(title: "快速入口") {
                        VStack(spacing: 10) {
                            Button {
                                showingAddTask = true
                            } label: {
                                Label("新增任务", systemImage: "plus.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            HStack(spacing: 10) {
                                Button {
                                    selection = .chat
                                } label: {
                                    Label("开始对话", systemImage: "message")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    generateTodayReport()
                                    selection = .review
                                } label: {
                                    Label(dashboardData.hasTodayReport ? "更新总结" : "生成总结", systemImage: "doc.text")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .padding()
                .padding(.bottom, 96)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("首页")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("设置")
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskSheet()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    private func generateTodayReport() {
        _ = try? dailyReviewService.upsertTodayReport(
            tasks: tasks,
            quests: quests,
            reports: reports,
            context: modelContext
        )
    }

    private func handleTodayAction() {
        switch dashboardData.todayRecommendation.kind {
        case .review:
            generateTodayReport()
            selection = .review
        case .noTask:
            showingAddTask = true
        case .overdue, .mainQuest, .daily:
            selection = .quests
        }
    }
}

struct DashboardCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct StatMetric: View {
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(value)")
                    .font(.caption.bold())
            }

            ProgressView(value: Double(value), total: 100)
                .tint(tint)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TodayPlanSummaryView: View {
    let summary: TodayPlanSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
                TodayPlanMetric(title: "可得 XP", value: summary.availableXPText, tint: .blue)
                TodayPlanMetric(title: "已得 XP", value: summary.completedXPText, tint: .green)
                TodayPlanMetric(title: "剩余 XP", value: summary.remainingXPText, tint: .orange)
            }

            Text(summary.scopeSummaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.top, 4)
    }

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 82), alignment: .leading)]
    }
}

private struct TodayPlanMetric: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TodayActionCard: View {
    let recommendation: TodayActionRecommendation
    let hasTodayReport: Bool
    let action: () -> Void

    private var iconName: String {
        switch recommendation.kind {
        case .overdue:
            return "exclamationmark.triangle.fill"
        case .mainQuest:
            return "target"
        case .daily:
            return "checkmark.circle.fill"
        case .review:
            return "doc.text.fill"
        case .noTask:
            return "plus.circle.fill"
        }
    }

    private var tint: Color {
        switch recommendation.kind {
        case .overdue:
            return .orange
        case .mainQuest:
            return .blue
        case .daily:
            return .green
        case .review:
            return .purple
        case .noTask:
            return .accentColor
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    titleLabel
                    Spacer()
                    actionButton
                }

                VStack(alignment: .leading, spacing: 10) {
                    titleLabel
                    actionButton
                }
            }

            Text(recommendation.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var titleLabel: some View {
        Label {
            Text(recommendation.title)
                .font(.headline)
        } icon: {
            Image(systemName: iconName)
                .foregroundStyle(tint)
        }
    }

    private var actionButton: some View {
        Button(action: action) {
            Label(recommendation.actionButtonTitle(hasTodayReport: hasTodayReport), systemImage: "arrow.right.circle")
        }
        .buttonStyle(.bordered)
    }
}
