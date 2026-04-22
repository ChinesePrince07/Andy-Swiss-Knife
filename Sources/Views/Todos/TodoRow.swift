import SwiftUI
import SwiftData

struct TodoRow: View {
    @Bindable var todo: Todo
    let services: Services

    @Environment(\.modelContext) private var modelContext
    @State private var showingEdit = false
    @State private var titleDraft: String = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button {
                toggle()
            } label: {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(todo.isDone ? AppColors.primary : AppColors.tertiary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                if todo.source == .manual && !todo.isDone {
                    TextField("", text: $titleDraft)
                        .font(AppType.body)
                        .foregroundStyle(AppColors.primary)
                        .multilineTextAlignment(.leading)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            commitTitle()
                            titleFocused = false
                        }
                        .onChange(of: titleFocused) { _, focused in
                            if !focused { commitTitle() }
                        }
                } else {
                    Text(todo.title)
                        .font(AppType.body)
                        .foregroundStyle(todo.isDone ? AppColors.tertiary : AppColors.primary)
                        .strikethrough(todo.isDone)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture { showingEdit = true }
                }
                if let notes = todo.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !notes.isEmpty {
                    Text(notes)
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture { showingEdit = true }
                }
            }

            Spacer(minLength: 8)

            if let status = dueLabel {
                Button {
                    showingEdit = true
                } label: {
                    Text(status.text)
                        .font(AppType.tiny)
                        .kerning(0.8)
                        .foregroundStyle(status.isOverdue ? AppColors.accent : AppColors.secondary)
                }
                .buttonStyle(.plain)
            } else if todo.source == .manual {
                Button {
                    showingEdit = true
                } label: {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.tertiary)
                }
                .buttonStyle(.plain)
            }

            if todo.source == .manual {
                Button { delete() } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.tertiary)
                        .padding(.leading, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .onAppear {
            titleDraft = todo.title
        }
        .onChange(of: todo.title) { _, newVal in
            if !titleFocused { titleDraft = newVal }
        }
        .sheet(isPresented: $showingEdit) {
            TodoEditSheet(services: services, existing: todo)
        }
    }

    private struct DueLabel {
        let text: String
        let isOverdue: Bool
    }

    private var dueLabel: DueLabel? {
        guard let due = todo.dueDate else { return nil }
        if todo.isDone { return nil }
        if due < .now {
            return DueLabel(text: "OVERDUE", isOverdue: true)
        }
        if Calendar.current.isDateInToday(due) {
            return DueLabel(text: "DUE TODAY", isOverdue: false)
        }
        if Calendar.current.isDateInTomorrow(due) {
            return DueLabel(text: "TOMORROW", isOverdue: false)
        }
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return DueLabel(text: df.string(from: due).uppercased(), isOverdue: false)
    }

    private func commitTitle() {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != todo.title else {
            titleDraft = todo.title
            return
        }
        todo.title = trimmed
        try? modelContext.save()
        SnapshotStore.publishTodos(from: modelContext)
        WidgetReloader.reloadTodoWidgets()
    }

    private func toggle() {
        todo.isDone.toggle()
        todo.completedAt = todo.isDone ? .now : nil
        if todo.isDone {
            services.notifications.cancel(for: todo)
        } else if todo.dueDate != nil, todo.dueDate! > .now {
            Task { await services.notifications.schedule(for: todo) }
        }
        try? modelContext.save()
        SnapshotStore.publishTodos(from: modelContext)
        WidgetReloader.reloadTodoWidgets()
    }

    private func delete() {
        services.notifications.cancel(for: todo)
        modelContext.delete(todo)
        try? modelContext.save()
        SnapshotStore.publishTodos(from: modelContext)
        WidgetReloader.reloadTodoWidgets()
    }
}
