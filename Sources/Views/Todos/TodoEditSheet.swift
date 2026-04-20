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
            }
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let due = hasDueDate ? dueDate : nil

        if let existing {
            let titleChanged = existing.title != trimmed
            let dueChanged = existing.dueDate != due
            existing.title = trimmed
            existing.dueDate = due
            if titleChanged || dueChanged { existing.userEdited = true }

            services.notifications.cancel(for: existing)
            if let d = due, d > .now, !existing.isDone {
                Task { await services.notifications.schedule(for: existing) }
            }
        } else {
            let new = Todo(title: trimmed, dueDate: due)
            modelContext.insert(new)
            if let d = due, d > .now {
                Task { await services.notifications.schedule(for: new) }
            }
        }
        try? modelContext.save()
        dismiss()
    }
}
