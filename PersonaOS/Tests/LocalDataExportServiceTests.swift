import Foundation
import XCTest
@testable import PersonaOS

final class LocalDataExportServiceTests: XCTestCase {
    func testExportIncludesLocalCollectionsAndExcludesAPIKeySecrets() throws {
        let service = LocalDataExportService()
        let exportedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let questID = UUID()
        let user = UserProfile(
            name: "智",
            level: 2,
            currentXP: 120,
            energy: 80,
            focus: 70,
            stress: 20,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let companion = CompanionPersona(name: "药老", createdAt: createdAt, updatedAt: createdAt)
        let quest = Quest(
            id: questID,
            title: "上架 PersonaOS",
            detail: "准备审核材料",
            questType: QuestType.main.rawValue,
            status: QuestStatus.active.rawValue,
            priority: 1,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let task = TaskItem(
            title: "补齐隐私控制",
            detail: "导出本地数据",
            questId: questID,
            xpReward: 40,
            dueDate: createdAt,
            createdAt: createdAt
        )
        let memory = MemoryRecord(
            content: "用户重视本地优先",
            source: "test",
            tagsText: "隐私,导出",
            importance: 8,
            confidence: 0.9,
            sensitivityLevel: 1,
            isUserConfirmed: true,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let report = DailyReport(
            date: createdAt,
            completedTaskCount: 1,
            totalTaskCount: 2,
            xpGained: 40,
            summary: "完成数据导出",
            companionComment: "做得实在。",
            createdAt: createdAt
        )
        let message = ChatMessage(
            role: ChatRole.assistant.rawValue,
            content: "先把本地数据边界做好。",
            createdAt: createdAt
        )

        let data = try service.makeExportData(
            users: [user],
            companions: [companion],
            quests: [quest],
            tasks: [task],
            memories: [memory],
            reports: [report],
            messages: [message],
            exportedAt: exportedAt
        )
        let export = try decodeExport(data)
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertEqual(export.schemaVersion, 1)
        XCTAssertEqual(export.appName, "PersonaOS")
        XCTAssertEqual(export.exportedAt, exportedAt)
        XCTAssertEqual(export.counts, LocalDataExportCounts(
            users: 1,
            companions: 1,
            quests: 1,
            tasks: 1,
            memories: 1,
            dailyReports: 1,
            chatMessages: 1
        ))
        XCTAssertEqual(export.users.first?.name, "智")
        XCTAssertEqual(export.companions.first?.name, "药老")
        XCTAssertEqual(export.quests.first?.title, "上架 PersonaOS")
        XCTAssertEqual(export.tasks.first?.questId, questID)
        XCTAssertEqual(export.memories.first?.content, "用户重视本地优先")
        XCTAssertEqual(export.dailyReports.first?.summary, "完成数据导出")
        XCTAssertEqual(export.chatMessages.first?.content, "先把本地数据边界做好。")
        XCTAssertFalse(json.contains("sk-test-secret"))
        XCTAssertFalse(json.contains("\"apiKey\""))
    }

    func testExportSortsCollectionsByCreationDateThenText() throws {
        let service = LocalDataExportService()
        let earlier = Date(timeIntervalSince1970: 1_700_000_000)
        let later = Date(timeIntervalSince1970: 1_700_000_100)
        let alpha = Quest(title: "Alpha", createdAt: earlier, updatedAt: later)
        let beta = Quest(title: "Beta", createdAt: earlier, updatedAt: later)
        let late = Quest(title: "Late", createdAt: later, updatedAt: later)

        let data = try service.makeExportData(
            users: [],
            companions: [],
            quests: [late, beta, alpha],
            tasks: [],
            memories: [],
            reports: [],
            messages: []
        )
        let export = try decodeExport(data)

        XCTAssertEqual(export.quests.map(\.title), ["Alpha", "Beta", "Late"])
    }

    func testSuggestedFilenameUsesJSONExtension() {
        let service = LocalDataExportService()
        let filename = service.suggestedFilename(exportedAt: Date(timeIntervalSince1970: 1_800_000_000))

        XCTAssertTrue(filename.hasPrefix("personaos-export-"))
        XCTAssertTrue(filename.hasSuffix(".json"))
        XCTAssertFalse(filename.contains(" "))
    }

    private func decodeExport(_ data: Data) throws -> PersonaOSLocalDataExport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PersonaOSLocalDataExport.self, from: data)
    }
}
