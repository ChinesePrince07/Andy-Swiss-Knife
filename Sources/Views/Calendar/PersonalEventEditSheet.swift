import SwiftUI
import SwiftData

struct PersonalEventEditSheet: View {
    let services: Services
    let existing: PersonalEvent?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var date: Date = .now
    @State private var isAllDay: Bool = false
    @State private var notes: String = ""
    @State private var notify: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .font(AppType.body)
                }

                Section {
                    Toggle("All day", isOn: $isAllDay)
                    DatePicker(
                        isAllDay ? "Date" : "When",
                        selection: $date,
                        displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                    )
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .font(AppType.body)
                        .lineLimit(3...6)
                }

                Section {
                    Toggle("Notify me", isOn: $notify)
                }
            }
            .navigationTitle(existing == nil ? "New reminder" : "Edit reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            if let existing {
                title = existing.title
                date = existing.date
                isAllDay = existing.isAllDay
                notes = existing.notes ?? ""
                notify = existing.notificationID != nil
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing {
            existing.title = trimmedTitle
            existing.date = date
            existing.isAllDay = isAllDay
            existing.notes = trimmedNotes.isEmpty ? nil : trimmedNotes

            if notify {
                Task { await services.notifications.schedule(for: existing) }
            } else {
                services.notifications.cancel(for: existing)
            }
        } else {
            let new = PersonalEvent(
                title: trimmedTitle,
                date: date,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                isAllDay: isAllDay
            )
            modelContext.insert(new)
            if notify {
                Task { await services.notifications.schedule(for: new) }
            }
        }
        try? modelContext.save()
        dismiss()
    }
}
