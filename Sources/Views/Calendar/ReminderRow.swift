import SwiftUI
import SwiftData

struct ReminderRow: View {
    @Bindable var event: PersonalEvent
    let dateLabel: String
    let onOpen: () -> Void
    let onDelete: () -> Void
    let onCommitTitle: (String) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var titleDraft: String = ""
    @State private var notesDraft: String = ""
    @State private var datePickerShown = false
    @FocusState private var titleFocused: Bool
    @FocusState private var notesFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(dateLabel)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColors.secondary)
                .frame(width: 96, alignment: .leading)
                .onTapGesture { onOpen() }

            VStack(alignment: .leading, spacing: 2) {
                TextField("", text: $titleDraft)
                    .font(AppType.bodyMedium)
                    .foregroundStyle(AppColors.primary)
                    .focused($titleFocused)
                    .submitLabel(.done)
                    .onSubmit { commitTitle() }
                    .onChange(of: titleFocused) { _, focused in
                        if !focused { commitTitle() }
                    }
                TextField("", text: $notesDraft, prompt: Text("Add note…").foregroundColor(AppColors.tertiary), axis: .vertical)
                    .font(AppType.caption)
                    .foregroundStyle(AppColors.secondary)
                    .focused($notesFocused)
                    .lineLimit(1...3)
                    .submitLabel(.done)
                    .onChange(of: notesFocused) { _, focused in
                        if !focused { commitNotes() }
                    }
            }

            Button { datePickerShown = true } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.tertiary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $datePickerShown) {
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker(
                        "Due",
                        selection: Binding(
                            get: { event.date },
                            set: { newVal in
                                event.date = Calendar.current.startOfDay(for: newVal)
                                try? modelContext.save()
                                SnapshotStore.publishReminders(from: modelContext)
                                WidgetReloader.reloadReminderWidgets()
                            }
                        ),
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                }
                .padding()
                .frame(minWidth: 320)
                .presentationCompactAdaptation(.popover)
            }

            Button { onDelete() } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .onAppear {
            titleDraft = event.title
            notesDraft = event.notes ?? ""
        }
        .onChange(of: event.title) { _, new in
            if !titleFocused { titleDraft = new }
        }
        .onChange(of: event.notes) { _, new in
            if !notesFocused { notesDraft = new ?? "" }
        }
    }

    private func commitTitle() {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            titleDraft = event.title
            return
        }
        if trimmed != event.title {
            onCommitTitle(trimmed)
        }
    }

    private func commitNotes() {
        let trimmed = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let newVal: String? = trimmed.isEmpty ? nil : trimmed
        if newVal != event.notes {
            event.notes = newVal
            try? modelContext.save()
            SnapshotStore.publishReminders(from: modelContext)
            WidgetReloader.reloadReminderWidgets()
        }
    }
}
