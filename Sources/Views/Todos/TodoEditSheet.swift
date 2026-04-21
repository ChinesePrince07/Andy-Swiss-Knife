import SwiftUI
import SwiftData

struct TodoEditSheet: View {
    let services: Services
    let existing: Todo?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = .now
    @State private var notes: String = ""

    private var isReadOnly: Bool {
        existing?.source == .canvas
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .font(AppType.body)
                        .disabled(isReadOnly)
                } header: {
                    if isReadOnly {
                        Text("From Canvas · read only")
                            .foregroundStyle(AppColors.secondary)
                    }
                }

                Section {
                    Toggle("Due date", isOn: $hasDueDate)
                        .disabled(isReadOnly)
                    if hasDueDate {
                        DatePicker(
                            "",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                        .disabled(isReadOnly)
                    }
                }

                Section("Notes") {
                    if isReadOnly {
                        Text(notes.isEmpty ? "—" : notes)
                            .font(AppType.body)
                            .foregroundStyle(AppColors.primary)
                            .textSelection(.enabled)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        TextField("Optional", text: $notes, axis: .vertical)
                            .font(AppType.body)
                            .lineLimit(3...)
                    }
                }

                if let existing, existing.source == .manual {
                    Section {
                        Button("Delete task", role: .destructive) {
                            deleteExisting(existing)
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New task" : "Edit task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isReadOnly)
                }
            }
        }
        .onAppear {
            if let existing {
                title = existing.title
                hasDueDate = existing.dueDate != nil
                dueDate = existing.dueDate ?? .now
                notes = existing.notes ?? ""
            }
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let due = hasDueDate ? dueDate : nil

        if let existing {
            let titleChanged = existing.title != trimmed
            let dueChanged = existing.dueDate != due
            let notesChanged = (existing.notes ?? "") != trimmedNotes
            existing.title = trimmed
            existing.dueDate = due
            existing.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            if titleChanged || dueChanged || notesChanged { existing.userEdited = true }

            services.notifications.cancel(for: existing)
            if let d = due, d > .now, !existing.isDone {
                Task { await services.notifications.schedule(for: existing) }
            }
        } else {
            let new = Todo(
                title: trimmed,
                dueDate: due,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            modelContext.insert(new)
            if let d = due, d > .now {
                Task { await services.notifications.schedule(for: new) }
            }
        }
        try? modelContext.save()
        SnapshotStore.publishTodos(from: modelContext)
        WidgetReloader.reloadTodoWidgets()
        dismiss()
    }

    private func deleteExisting(_ todo: Todo) {
        services.notifications.cancel(for: todo)
        modelContext.delete(todo)
        try? modelContext.save()
        SnapshotStore.publishTodos(from: modelContext)
        WidgetReloader.reloadTodoWidgets()
        dismiss()
    }
}
