import SwiftUI
import SwiftData

struct AssignmentsView: View {
    let services: Services

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Todo> { $0.externalID != nil })
    private var canvasTodos: [Todo]

    @State private var isRefreshing = false
    @State private var syncError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if canvasTodos.isEmpty {
                    emptyState
                } else {
                    assignmentsList
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(AppColors.background.ignoresSafeArea())
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
        let open = canvasTodos.filter { !$0.isDone }.count
        let done = canvasTodos.filter { $0.isDone }.count
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
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "To do")
            HairlineDivider()
            ForEach(sorted) { todo in
                TodoRow(todo: todo, services: services)
                HairlineDivider()
            }
        }
    }

    private var sorted: [Todo] {
        let open = canvasTodos.filter { !$0.isDone }.sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (.some(l), .some(r)): return l < r
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return lhs.createdAt > rhs.createdAt
            }
        }
        let done = canvasTodos.filter { $0.isDone }.sorted { $0.createdAt > $1.createdAt }
        return open + done
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
