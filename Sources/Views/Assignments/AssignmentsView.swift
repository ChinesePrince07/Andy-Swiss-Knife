import SwiftUI
import SwiftData

struct AssignmentsView: View {
    let services: Services

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Todo> { $0.externalID != nil })
    private var allCanvasTodos: [Todo]

    @State private var isRefreshing = false
    @State private var syncError = false

    private var visibleTodos: [Todo] {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return allCanvasTodos.filter { todo in
            guard let due = todo.dueDate else { return true }
            return due >= startOfToday
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if visibleTodos.isEmpty {
                    emptyState
                } else {
                    assignmentsList
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(ThemedBackground())
        .navigationTitle("Canvas")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await sync()
        }
        .task {
            await sync()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Assignments")
                .font(AppType.displayTitle)
                .foregroundStyle(AppColors.primary)
            Text(counterLine)
                .font(AppType.caption)
                .foregroundStyle(AppColors.secondary)
        }
    }

    private var counterLine: String {
        let open = visibleTodos.filter { !$0.isDone }.count
        let done = visibleTodos.filter { $0.isDone }.count
        if syncError {
            return "\(open) open · \(done) done · sync error"
        }
        return "\(open) open · \(done) done"
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(syncError ? "Couldn't sync Canvas" : "No Canvas assignments yet.")
                .font(AppType.body)
                .foregroundStyle(syncError ? AppColors.accent : AppColors.secondary)
            if syncError {
                Button("Retry") { Task { await sync() } }
                    .font(AppType.body)
                    .foregroundStyle(AppColors.primary)
            } else {
                Text("Pull to refresh to sync your assignment feed.")
                    .font(AppType.caption)
                    .foregroundStyle(AppColors.tertiary)
            }
        }
        .padding(.top, 20)
    }

    private var assignmentsList: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(groupedBuckets, id: \.0) { bucket, todos in
                DueGroupSection(
                    title: bucket.title,
                    subtitle: bucket.subtitle,
                    isUrgent: bucket.isUrgent,
                    items: todos,
                    services: services,
                    allowReorder: bucket != .done
                )
            }
        }
    }

    private var groupedBuckets: [(DueBucket, [Todo])] {
        let open = visibleTodos.filter { !$0.isDone }
        let grouped = DueBucket.group(todos: open)
        // Keep done list at bottom only if there are any.
        var result = grouped
        let done = visibleTodos.filter { $0.isDone }
        if !done.isEmpty {
            result.append((DueBucket.done, done.sorted { $0.createdAt > $1.createdAt }))
        }
        return result
    }

    private func sync() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try await services.assignments.syncCanvas()
            syncError = false
        } catch {
            syncError = true
        }
    }
}
