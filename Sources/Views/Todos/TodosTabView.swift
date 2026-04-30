import SwiftUI
import SwiftData

struct TodosTabView: View {
    let services: Services

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Todo> { $0.externalID == nil })
    private var allTodos: [Todo]

    @State private var newTodoTitle: String = ""
    @FocusState private var addFieldFocused: Bool

    private var openTodos: [Todo] {
        allTodos.filter { !$0.isDone }.sorted { lhs, rhs in
            let l = lhs.sortOrder ?? lhs.createdAt.timeIntervalSince1970
            let r = rhs.sortOrder ?? rhs.createdAt.timeIntervalSince1970
            return l > r
        }
    }

    private var doneTodos: [Todo] {
        allTodos.filter { $0.isDone }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel(text: "To do")
                    Spacer()
                    if !doneTodos.isEmpty {
                        Button("Clear done") { clearDone() }
                            .font(AppType.caption)
                            .foregroundStyle(AppColors.secondary)
                    }
                }
                .padding(.top, 8)

                if allTodos.isEmpty {
                    HairlineDivider()
                    Text("No tasks yet.")
                        .font(AppType.body)
                        .foregroundStyle(AppColors.secondary)
                        .padding(.vertical, 12)
                } else {
                    VStack(spacing: 0) {
                        HairlineDivider()
                        ReorderableTodoList(items: openTodos, services: services)
                    }
                    if !doneTodos.isEmpty {
                        doneSection
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.secondary)
                    TextField("", text: $newTodoTitle, prompt: Text("Add task…").foregroundColor(AppColors.secondary))
                        .font(AppType.body)
                        .foregroundStyle(AppColors.primary)
                        .focused($addFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { commitNewTodo() }
                }
                .padding(.vertical, 10)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(ThemedBackground())
        .navigationTitle("To Do")
        .navigationBarTitleDisplayMode(.inline)
        .contentShape(Rectangle())
        .onTapGesture { dismissKeyboard() }
    }

    private var doneSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DONE")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .kerning(1.3)
                .foregroundStyle(AppColors.tertiary)
                .padding(.top, 10)
            Rectangle().fill(AppColors.tertiary).frame(height: 1)
            ForEach(doneTodos) { todo in
                TodoRow(todo: todo, services: services)
                HairlineDivider()
            }
        }
    }

    private func commitNewTodo() {
        let trimmed = newTodoTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let maxOrder = allTodos.compactMap(\.sortOrder).max() ?? 0
        let todo = Todo(title: trimmed, sortOrder: maxOrder + 1)
        modelContext.insert(todo)
        try? modelContext.save()
        SnapshotStore.publishTodos(from: modelContext)
        WidgetReloader.reloadTodoWidgets()
        newTodoTitle = ""
        addFieldFocused = true
    }

    private func clearDone() {
        for t in allTodos where t.isDone {
            services.notifications.cancel(for: t)
            modelContext.delete(t)
        }
        try? modelContext.save()
        SnapshotStore.publishTodos(from: modelContext)
        WidgetReloader.reloadTodoWidgets()
    }
}
