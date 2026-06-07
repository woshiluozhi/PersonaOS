import Foundation
import SwiftData

enum MemoryStatusFilter: String, CaseIterable, Identifiable {
    case all
    case confirmed
    case candidates
    case dismissed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .confirmed:
            return "已确认"
        case .candidates:
            return "候选"
        case .dismissed:
            return "忽略"
        }
    }
}

struct MemoryMetrics: Equatable {
    var importance: Int
    var confidence: Double
    var sensitivityLevel: Int

    var confidenceText: String {
        String(format: "%.2f", confidence)
    }
}

struct MemoryCollectionSummary: Equatable {
    var totalCount: Int
    var confirmedCount: Int
    var candidateCount: Int
    var dismissedCount: Int
}

struct MemoryEngine {
    func statusTitle(for memory: MemoryRecord) -> String {
        if memory.isDismissed {
            return "已忽略"
        }
        return memory.isUserConfirmed ? "已确认" : "候选"
    }

    func metrics(for memory: MemoryRecord) -> MemoryMetrics {
        MemoryMetrics(
            importance: min(max(memory.importance, 1), 10),
            confidence: min(max(memory.confidence, 0), 1),
            sensitivityLevel: min(max(memory.sensitivityLevel, 0), 5)
        )
    }

    func displayContent(for memory: MemoryRecord) -> String {
        cleanedMemoryContent(memory.content)
    }

    func cleanMemoryContent(_ content: String) -> String {
        cleanedMemoryContent(content)
    }

    func summary(for memories: [MemoryRecord]) -> MemoryCollectionSummary {
        let displayableMemories = memories.filter { !displayContent(for: $0).isEmpty }
        let dismissedCount = displayableMemories.filter(\.isDismissed).count
        let confirmedCount = displayableMemories.filter { $0.isUserConfirmed && !$0.isDismissed }.count
        let candidateCount = displayableMemories.filter { !$0.isUserConfirmed && !$0.isDismissed }.count

        return MemoryCollectionSummary(
            totalCount: displayableMemories.count,
            confirmedCount: confirmedCount,
            candidateCount: candidateCount,
            dismissedCount: dismissedCount
        )
    }

    func memoryDeleteConfirmationTitle(for memories: [MemoryRecord]) -> String {
        memories.count > 1 ? "删除 \(memories.count) 条记忆" : "删除这条记忆"
    }

    func memoryDeleteConfirmationMessage(for memories: [MemoryRecord]) -> String {
        if memories.count == 1, let memory = memories.first {
            return "这会删除「\(memoryDeletionPreviewContent(for: memory))」这条本地记忆。"
        }

        return "这会删除选中的 \(memories.count) 条本地记忆。"
    }

    func tags(from tagsText: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",，;；")
        var seen = Set<String>()

        return tagsText
            .components(separatedBy: separators)
            .compactMap { rawTag in
                let tag = cleanedTag(rawTag)
                guard !tag.isEmpty else {
                    return nil
                }

                let key = normalizedTagKey(tag)
                guard !seen.contains(key) else {
                    return nil
                }

                seen.insert(key)
                return tag
            }
    }

    func hasMemory(content: String, source: String? = nil, in memories: [MemoryRecord]) -> Bool {
        let normalizedContent = normalizedMemoryContent(content)
        guard !normalizedContent.isEmpty else {
            return false
        }

        let normalizedSource = source.map(normalizedMemorySource)

        return memories.contains { memory in
            let contentMatches = normalizedMemoryContent(memory.content) == normalizedContent
            let sourceMatches = normalizedSource.map { normalizedMemorySource(memory.source) == $0 } ?? true
            return contentMatches && sourceMatches
        }
    }

    private func normalizedMemoryContent(_ content: String) -> String {
        cleanedMemoryContent(content).lowercased()
    }

    private func cleanedMemoryContent(_ content: String) -> String {
        content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func memoryDeletionPreviewContent(for memory: MemoryRecord) -> String {
        let content = displayContent(for: memory)
        guard !content.isEmpty else {
            return "空白记忆"
        }
        guard content.count > 28 else {
            return content
        }
        return String(content.prefix(28)) + "..."
    }

    private func cleanedMemorySource(_ source: String) -> String {
        source
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func normalizedMemorySource(_ source: String) -> String {
        cleanedMemorySource(source).lowercased()
    }

    func makeCandidateMemory(from content: String, source: String = "chat", now: Date = Date()) -> MemoryRecord {
        let cleanedSource = cleanedMemorySource(source)

        return MemoryRecord(
            content: cleanedMemoryContent(content),
            source: cleanedSource.isEmpty ? "chat" : cleanedSource,
            tagsText: "候选",
            importance: 5,
            confidence: 0.55,
            sensitivityLevel: 1,
            isUserConfirmed: false,
            createdAt: now,
            updatedAt: now
        )
    }

    func saveMemory(
        content: String,
        source: String = "manual",
        tagsText: String = "",
        importance: Int = 5,
        confidence: Double = 0.7,
        sensitivityLevel: Int = 1,
        isUserConfirmed: Bool = true,
        context: ModelContext
    ) {
        let cleanedContent = cleanedMemoryContent(content)
        guard !cleanedContent.isEmpty else {
            return
        }

        let cleanedSource = cleanedMemorySource(source)
        let now = Date()
        let memory = MemoryRecord(
            content: cleanedContent,
            source: cleanedSource.isEmpty ? "manual" : cleanedSource,
            tagsText: tags(from: tagsText).joined(separator: ", "),
            importance: min(max(importance, 1), 10),
            confidence: min(max(confidence, 0), 1),
            sensitivityLevel: min(max(sensitivityLevel, 0), 5),
            isUserConfirmed: isUserConfirmed,
            createdAt: now,
            updatedAt: now
        )
        context.insert(memory)
    }

    func confirmMemory(_ memory: MemoryRecord, now: Date = Date()) {
        let cleanedSource = cleanedMemorySource(memory.source)

        memory.content = cleanedMemoryContent(memory.content)
        memory.source = cleanedSource.isEmpty ? "manual" : cleanedSource
        memory.tagsText = tags(from: memory.tagsText).joined(separator: ", ")
        memory.isUserConfirmed = true
        memory.isDismissed = false
        memory.confidence = max(metrics(for: memory).confidence, 0.8)
        memory.updatedAt = now
    }

    func dismissMemory(_ memory: MemoryRecord, now: Date = Date()) {
        memory.isDismissed = true
        memory.updatedAt = now
    }

    func restoreMemory(_ memory: MemoryRecord, now: Date = Date()) {
        memory.isDismissed = false
        memory.updatedAt = now
    }

    func deleteMemory(_ memory: MemoryRecord, context: ModelContext) {
        context.delete(memory)
    }

    @discardableResult
    func deleteDismissedMemories(_ memories: [MemoryRecord], context: ModelContext) -> Int {
        let dismissedMemories = memories.filter(\.isDismissed)
        dismissedMemories.forEach(context.delete)
        return dismissedMemories.count
    }

    func queryMemories(
        _ memories: [MemoryRecord],
        statusFilter: MemoryStatusFilter = .all,
        searchText: String = "",
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [MemoryRecord] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchTerms = trimmedSearch
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        return memories
            .filter { memory in
                let displayContent = displayContent(for: memory)
                guard !displayContent.isEmpty else {
                    return false
                }

                switch statusFilter {
                case .all:
                    guard !memory.isDismissed else {
                        return false
                    }
                case .confirmed:
                    guard memory.isUserConfirmed && !memory.isDismissed else {
                        return false
                    }
                case .candidates:
                    guard !memory.isUserConfirmed && !memory.isDismissed else {
                        return false
                    }
                case .dismissed:
                    guard memory.isDismissed else {
                        return false
                    }
                }

                if searchTerms.isEmpty {
                    return true
                }

                let metrics = metrics(for: memory)
                let importanceTitle = "重要 \(metrics.importance)"
                let confidenceTitle = "置信 \(metrics.confidenceText)"
                let sensitivityTitle = "敏感 \(metrics.sensitivityLevel)"
                let searchableFields = [
                    displayContent,
                    memory.tagsText,
                    cleanedMemorySource(memory.source),
                    statusTitle(for: memory),
                    importanceTitle,
                    confidenceTitle,
                    sensitivityTitle,
                    PersonaDate.displayDate(memory.createdAt),
                    PersonaDate.relativeDayTitle(memory.createdAt, relativeTo: referenceDate, calendar: calendar),
                    PersonaDate.displayDate(memory.updatedAt),
                    PersonaDate.relativeDayTitle(memory.updatedAt, relativeTo: referenceDate, calendar: calendar)
                ]

                return searchTerms.allSatisfy { term in
                    searchableFields.contains { $0.localizedCaseInsensitiveContains(term) }
                }
            }
            .sorted { lhs, rhs in
                let lhsImportance = metrics(for: lhs).importance
                let rhsImportance = metrics(for: rhs).importance
                if lhsImportance == rhsImportance {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhsImportance > rhsImportance
            }
    }

    func queryMemories(
        _ memories: [MemoryRecord],
        confirmedOnly: Bool,
        searchText: String = "",
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [MemoryRecord] {
        queryMemories(
            memories,
            statusFilter: confirmedOnly ? .confirmed : .all,
            searchText: searchText,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    private func cleanedTag(_ tag: String) -> String {
        tag
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .folding(options: [.widthInsensitive], locale: .current)
    }

    private func normalizedTagKey(_ tag: String) -> String {
        cleanedTag(tag)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
    }
}
