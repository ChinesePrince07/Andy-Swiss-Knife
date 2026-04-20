import SwiftUI
import SwiftData

struct TodoRow: View {
    @Bindable var todo: Todo
    let services: Services

    @Environment(\.modelContext) private var modelContext
    @State private var showingEdit = false

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

            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .font(AppType.body)
                    .foregroundStyle(todo.isDone ? AppColors.tertiary : AppColors.primary)
                    .strikethrough(todo.isDone)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let notes = todo.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !notes.isEmpty {
                    Text(notes)
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer(minLength: 8)

            if let status = dueLabel {
                Text(status.text)
                    .font(AppType.tiny)
                    .kerning(0.8)
                    .foregroundStyle(status.isOverdue ? AppColors.accent : AppColors.secondary)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            if todo.source == .manual {
                showingEdit = true
            } else {
                showingEdit = true
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if todo.source == .manual {
                Button(role: .destructive) {
                    delete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
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

    private func toggle() {
        todo.isDone.toggle()
        if todo.isDone {
            services.notifications.cancel(for: todo)
        } else if todo.dueDate != nil, todo.dueDate! > .now {
            Task { await services.notifications.schedule(for: todo) }
        }
        try? modelContext.save()
    }

    private func delete() {
        services.notifications.cancel(for: todo)
        modelContext.delete(todo)
        try? modelContext.save()
    }
}
