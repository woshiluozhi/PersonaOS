import SwiftData
import SwiftUI

struct MemoryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var memories: [MemoryRecord]

    @State private var showingAddMemory = false
    @State private var statusFilter: MemoryStatusFilter = .all
    @State private var searchText = ""
    @State private var memoriesPendingDeletion: [MemoryRecord] = []

    private let engine = MemoryEngine()

    private var displayedMemories: [MemoryRecord] {
        engine.queryMemories(memories, statusFilter: statusFilter, searchText: searchText)
    }

    private var displayedSummary: MemoryCollectionSummary {
        engine.summary(for: displayedMemories)
    }

    private var isSearchingMemories: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("记忆状态", selection: $statusFilter) {
                        ForEach(MemoryStatusFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    MemorySearchField(searchText: $searchText)

                    MemoryFilterSummaryRow(
                        filterTitle: statusFilter.title,
                        summary: displayedSummary,
                        isSearching: isSearchingMemories
                    )
                }

                Section("长期记忆") {
                    if displayedMemories.isEmpty {
                        Text("暂无符合条件的记忆。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(displayedMemories, id: \.id) { memory in
                            MemoryRow(
                                content: engine.displayContent(for: memory),
                                memory: memory,
                                statusTitle: engine.statusTitle(for: memory),
                                tags: engine.tags(from: memory.tagsText),
                                metrics: engine.metrics(for: memory),
                                onConfirm: {
                                    engine.confirmMemory(memory)
                                    try? modelContext.save()
                                },
                                onDismiss: {
                                    engine.dismissMemory(memory)
                                    try? modelContext.save()
                                },
                                onRestore: {
                                    engine.restoreMemory(memory)
                                    try? modelContext.save()
                                }
                            )
                        }
                        .onDelete { offsets in
                            queueDelete(offsets: offsets)
                        }
                    }
                }
            }
            .navigationTitle("记忆")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddMemory = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新增记忆")
                }
            }
            .sheet(isPresented: $showingAddMemory) {
                AddMemorySheet()
            }
            .confirmationDialog(
                "删除记忆",
                isPresented: Binding(
                    get: { !memoriesPendingDeletion.isEmpty },
                    set: { isPresented in
                        if !isPresented {
                            memoriesPendingDeletion = []
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button(engine.memoryDeleteConfirmationTitle(for: memoriesPendingDeletion), role: .destructive) {
                    deletePendingMemories()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text(engine.memoryDeleteConfirmationMessage(for: memoriesPendingDeletion))
            }
        }
    }

    private func queueDelete(offsets: IndexSet) {
        memoriesPendingDeletion = offsets.map { displayedMemories[$0] }
    }

    private func deletePendingMemories() {
        for memory in memoriesPendingDeletion {
            engine.deleteMemory(memory, context: modelContext)
        }
        try? modelContext.save()
        memoriesPendingDeletion = []
    }
}

private struct MemorySearchField: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜索内容、标签、来源、状态、日期、权重", text: $searchText)
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("清空记忆搜索")
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct MemoryFilterSummaryRow: View {
    let filterTitle: String
    let summary: MemoryCollectionSummary
    let isSearching: Bool

    private var title: String {
        let baseTitle = filterTitle == "全部" ? "全部可用记忆" : "\(filterTitle)记忆"
        return isSearching ? "\(baseTitle) · 搜索结果" : baseTitle
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 78), alignment: .leading)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "brain.head.profile")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                MemoryFilterMetric(title: "总计", value: summary.totalCount, systemImage: "list.bullet")
                MemoryFilterMetric(title: "确认", value: summary.confirmedCount, systemImage: "checkmark.seal")
                MemoryFilterMetric(title: "候选", value: summary.candidateCount, systemImage: "sparkle")
                if summary.dismissedCount > 0 {
                    MemoryFilterMetric(title: "忽略", value: summary.dismissedCount, systemImage: "eye.slash")
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MemoryFilterMetric: View {
    let title: String
    let value: Int
    let systemImage: String

    var body: some View {
        Label {
            Text("\(value) \(title)")
                .font(.caption)
                .monospacedDigit()
        } icon: {
            Image(systemName: systemImage)
        }
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

private struct MemoryRow: View {
    let content: String
    let memory: MemoryRecord
    let statusTitle: String
    let tags: [String]
    let metrics: MemoryMetrics
    let onConfirm: () -> Void
    let onDismiss: () -> Void
    let onRestore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(content)
                .font(.headline)

            tagRow

            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
                Label("重要 \(metrics.importance)", systemImage: "star")
                Label("置信 \(metrics.confidenceText)", systemImage: "checkmark.seal")
                Label("敏感 \(metrics.sensitivityLevel)", systemImage: "lock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            HStack {
                Text(statusTitle)
                    .font(.caption.bold())
                    .foregroundStyle(statusColor)

                Spacer()

                if memory.isDismissed {
                    Button("恢复", action: onRestore)
                        .buttonStyle(.bordered)
                } else {
                    Button("忽略", action: onDismiss)
                        .buttonStyle(.bordered)
                }

                if !memory.isUserConfirmed && !memory.isDismissed {
                    Button("确认记忆", action: onConfirm)
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var statusColor: Color {
        if memory.isDismissed {
            return .secondary
        }
        return memory.isUserConfirmed ? .green : .orange
    }

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 86), alignment: .leading)]
    }

    @ViewBuilder
    private var tagRow: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2.bold())
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

private struct AddMemorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var existingMemories: [MemoryRecord]

    @State private var content = ""
    @State private var source = "manual"
    @State private var tagsText = ""
    @State private var importance = 5
    @State private var confidence = 0.7
    @State private var sensitivityLevel = 1
    @State private var isConfirmed = true

    private let engine = MemoryEngine()

    private var cleanedContent: String {
        engine.cleanMemoryContent(content)
    }

    private var isDuplicate: Bool {
        engine.hasMemory(content: cleanedContent, in: existingMemories)
    }

    private var canSave: Bool {
        !cleanedContent.isEmpty && !isDuplicate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("内容") {
                    TextField("记忆内容", text: $content, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("来源", text: $source)
                    TextField("标签，逗号分隔", text: $tagsText)
                    if isDuplicate {
                        Label("已有相同内容的记忆", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Section("权重") {
                    Stepper("重要性：\(importance)", value: $importance, in: 1...10)
                    Slider(value: $confidence, in: 0...1) {
                        Text("置信度")
                    }
                    Text(String(format: "置信度 %.2f", confidence))
                        .foregroundStyle(.secondary)
                    Stepper("敏感级别：\(sensitivityLevel)", value: $sensitivityLevel, in: 0...5)
                    Toggle("用户已确认", isOn: $isConfirmed)
                }
            }
            .navigationTitle("新增记忆")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        engine.saveMemory(
            content: cleanedContent,
            source: source,
            tagsText: tagsText,
            importance: importance,
            confidence: confidence,
            sensitivityLevel: sensitivityLevel,
            isUserConfirmed: isConfirmed,
            context: modelContext
        )
        try? modelContext.save()
        dismiss()
    }
}
