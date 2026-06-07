import SwiftUI
import UIKit

enum MainTab: Hashable {
    case dashboard
    case quests
    case chat
    case memory
    case review
}

struct MainTabView: View {
    let startupNote: String?

    @State private var selection: MainTab = .dashboard

    init(startupNote: String?) {
        self.startupNote = startupNote

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.backgroundEffect = nil
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selection) {
            DashboardView(selection: $selection, startupNote: startupNote)
                .tabItem { Label("首页", systemImage: "gauge.with.dots.needle.bottom.50percent") }
                .tag(MainTab.dashboard)

            QuestListView()
                .tabItem { Label("任务", systemImage: "checklist") }
                .tag(MainTab.quests)

            CompanionChatView()
                .tabItem { Label("对话", systemImage: "message") }
                .tag(MainTab.chat)

            MemoryView()
                .tabItem { Label("记忆", systemImage: "archivebox") }
                .tag(MainTab.memory)

            DailyReviewView()
                .tabItem { Label("复盘", systemImage: "calendar.badge.clock") }
                .tag(MainTab.review)
        }
        .toolbarBackground(Color(.systemBackground), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
