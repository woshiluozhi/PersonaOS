import SwiftData
import SwiftUI

@main
struct PersonaOSApp: App {
    private let startupState = StartupState.create()

    var body: some Scene {
        WindowGroup {
            switch startupState {
            case .ready(let container, let note):
                SeededRootView(startupNote: note)
                    .modelContainer(container)
            case .failed(let message):
                StartupErrorView(message: message)
            }
        }
    }
}

private enum StartupState {
    case ready(ModelContainer, String?)
    case failed(String)

    static func create() -> StartupState {
        do {
            return .ready(try makeContainer(isInMemory: false), nil)
        } catch {
            do {
                let container = try makeContainer(isInMemory: true)
                return .ready(container, "SwiftData 持久化初始化失败，已降级为本次启动内存模式：\(error.localizedDescription)")
            } catch {
                return .failed("SwiftData 初始化失败：\(error.localizedDescription)")
            }
        }
    }

    private static func makeContainer(isInMemory: Bool) throws -> ModelContainer {
        let schema = Schema([
            UserProfile.self,
            CompanionPersona.self,
            Quest.self,
            TaskItem.self,
            MemoryRecord.self,
            DailyReport.self,
            ChatMessage.self
        ])
        if !isInMemory {
            try prepareApplicationSupportDirectory()
        }
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isInMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func prepareApplicationSupportDirectory() throws {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }

        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

private struct SeededRootView: View {
    let startupNote: String?

    @Environment(\.modelContext) private var modelContext
    @State private var didSeed = false

    var body: some View {
        MainTabView(startupNote: startupNote)
            .task {
                guard !didSeed else {
                    return
                }
                DemoDataSeeder.seedIfNeeded(context: modelContext)
                didSeed = true
            }
    }
}

private struct StartupErrorView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("PersonaOS 启动失败")
                .font(.title2.bold())
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
            Text("请查看 CODEX_REPORT.md 与 Xcode 控制台日志。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}
