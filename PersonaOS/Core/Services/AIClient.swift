import Foundation

protocol AIClientProtocol {
    func sendMessage(userMessage: String, context: AIRequestContext) async throws -> AIResponse
}

struct AIRequestContext: Equatable {
    var userName: String
    var companionName: String
    var userLevel: Int
    var currentXP: Int
    var activeQuestTitles: [String]
    var todayTaskTitles: [String]
    var completedTodayTaskTitles: [String]
    var overdueTaskTitles: [String]
    var recentMemories: [String]
    var recentDailyReports: [String]
}

struct AIResponse: Equatable {
    var assistantMessage: String
    var suggestedMemories: [String]
    var suggestedTasks: [String]
    var riskFlags: [String]
}

struct MockAIClient: AIClientProtocol {
    func sendMessage(userMessage: String, context: AIRequestContext) async throws -> AIResponse {
        let trimmed = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        let cleanedUserMessage = displayTaskTitle(trimmed)
        let userName = displayName(context.userName, fallback: "你")
        let companionName = displayName(context.companionName, fallback: "药老")
        let activeQuestTitles = cleanedTaskTitles(context.activeQuestTitles)
        let recentMemories = context.recentMemories.compactMap { memory in
            let cleaned = displayTaskTitle(memory)
            return cleaned.isEmpty ? nil : cleaned
        }
        let recentDailyReports = context.recentDailyReports.compactMap { report in
            let cleaned = displayTaskTitle(report)
            return cleaned.isEmpty ? nil : cleaned
        }
        let mainQuest = activeQuestTitles.first ?? "当前主线尚未明确"
        let todayTaskTitles = cleanedTaskTitles(context.todayTaskTitles)
        let completedTodayTaskTitles = cleanedTaskTitles(context.completedTodayTaskTitles)
        let overdueTaskTitles = cleanedTaskTitles(context.overdueTaskTitles)
        let unfinishedTasks = unfinishedTaskTitles(
            todayTaskTitles: todayTaskTitles,
            completedTodayTaskTitles: completedTodayTaskTitles
        )
        let firstTask = unfinishedTasks.first ?? todayTaskTitles.first ?? "写下下一步可执行动作"

        var suggestedMemories: [String] = []
        var suggestedTasks: [String] = []
        var riskFlags: [String] = []
        var reply: String

        if lowercased.contains("我该做什么") || lowercased.contains("做什么") || lowercased.contains("what should") {
            if let firstOverdueTask = overdueTaskTitles.first {
                reply = "\(userName)，先清逾期：「\(firstOverdueTask)」。主线是「\(mainQuest)」，但逾期任务会持续吞掉注意力。先处理一个真实阻塞，再回到主线。"
                suggestedTasks = Array(overdueTaskTitles.prefix(2))
                riskFlags = ["overdue_tasks"]
            } else if !todayTaskTitles.isEmpty && unfinishedTasks.isEmpty {
                reply = "\(userName)，今天的任务已经闭环。现在进入每日复盘，确认哪件事真正推进了「\(mainQuest)」，再决定明天的第一步。"
                suggestedTasks = ["生成今日总结"]
            } else {
                reply = "\(userName)，先看主线：\(mainQuest)。今天不要把精力摊开，先完成「\(firstTask)」。能闭环的动作，比漂亮的新计划更值钱。"
                suggestedTasks = unfinishedTasks.isEmpty ? [firstTask] : Array(unfinishedTasks.prefix(2))
            }
        } else if lowercased.contains("风险") || lowercased.contains("阻塞") || lowercased.contains("risk") {
            if overdueTaskTitles.isEmpty {
                reply = "当前没有明显逾期任务。真正的风险会藏在范围膨胀和主线不清里：今天只保留一个可验收动作，其他都先降级。"
            } else {
                let overdueList = overdueTaskTitles.prefix(2).joined(separator: "、")
                reply = "先处理逾期：\(overdueList)。逾期任务不是待办列表的装饰，它们会持续吞掉注意力。今天先清掉一个，再谈加新动作。"
                suggestedTasks = Array(overdueTaskTitles.prefix(2))
                riskFlags = ["overdue_tasks"]
            }
        } else if lowercased.contains("开新项目") || lowercased.contains("新项目") || lowercased.contains("new project") {
            reply = "可以想，但现在先别急着开。你已有主线是「\(mainQuest)」，若它还没有一个可运行闭环，新项目大概率只是逃避复杂度。先把旧主线推进到可验收，再决定是否扩展。"
            riskFlags = ["scope_creep", "unfinished_main_quest"]
            suggestedTasks = ["列出当前主线剩余阻塞", "完成一个能验收的最小闭环"]
        } else if lowercased.contains("总结今天") || lowercased.contains("复盘") || lowercased.contains("daily review") {
            reply = "该进入每日复盘了。先看完成数，再看主线是否推进。不要只记录忙碌，要记录哪件事让局面发生了变化。"
            suggestedTasks = ["生成今日总结", "写下今日关键事件"]
        } else if trimmed.isEmpty {
            reply = "先把问题说清楚。含糊的问题，只会得到含糊的行动。"
        } else {
            let contextHint = recentMemories.first.map {
                "我记得你重视「\($0)」。"
            } ?? recentDailyReports.first.map {
                "最近复盘提到「\(limitedContextText($0))」。"
            } ?? ""
            reply = "\(contextHint)\(companionName)的判断：先把这句话落到行动上。围绕「\(mainQuest)」选一个今天能完成的动作，不要用讨论替代推进。"
            if cleanedUserMessage.count > 12 {
                suggestedMemories.append("用户提到：\(cleanedUserMessage)")
            }
        }

        return AIResponse(
            assistantMessage: reply,
            suggestedMemories: suggestedMemories,
            suggestedTasks: suggestedTasks,
            riskFlags: riskFlags
        )
    }

    private func unfinishedTaskTitles(
        todayTaskTitles: [String],
        completedTodayTaskTitles: [String]
    ) -> [String] {
        var completedCounts: [String: Int] = [:]
        for title in completedTodayTaskTitles {
            let key = normalizedTaskTitle(title)
            guard !key.isEmpty else {
                continue
            }
            completedCounts[key, default: 0] += 1
        }

        return todayTaskTitles.filter { title in
            let key = normalizedTaskTitle(title)
            guard !key.isEmpty else {
                return false
            }
            guard let count = completedCounts[key], count > 0 else {
                return true
            }

            completedCounts[key] = count - 1
            return false
        }
    }

    private func normalizedTaskTitle(_ title: String) -> String {
        title
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func cleanedTaskTitles(_ titles: [String]) -> [String] {
        titles.compactMap { title in
            let cleaned = displayTaskTitle(title)
            return cleaned.isEmpty ? nil : cleaned
        }
    }

    private func displayTaskTitle(_ title: String) -> String {
        title
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func displayName(_ name: String, fallback: String) -> String {
        let cleaned = displayTaskTitle(name)
        return cleaned.isEmpty ? fallback : cleaned
    }

    private func limitedContextText(_ text: String, maxLength: Int = 60) -> String {
        guard text.count > maxLength else {
            return text
        }

        return String(text.prefix(maxLength)) + "..."
    }
}
