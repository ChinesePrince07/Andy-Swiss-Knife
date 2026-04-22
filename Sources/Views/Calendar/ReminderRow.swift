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
    @State private var datePickerShown = false
    @FocusState private var titleFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(dateLabel)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColors.secondary)
                .frame(width: 96, alignment: .leading)
                .onTapGesture { onOpen() }

            VStack(alignment: .leading, spacing: 1) {
                TextField("", text: $titleDraft)
                    .font(AppType.bodyMedium)
                    .foregroundStyle(AppColors.primary)
                    .focused($titleFocused)
                    .submitLabel(.done)
                    .onSubmit { commit() }
                    .onChange(of: titleFocused) { _, focused in
                        if !focused { commit() }
                    }
                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.secondary)
                        .lineLimit(1)
                        .onTapGesture { onOpen() }
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
        .onAppear { titleDraft = event.title }
        .onChange(of: event.title) { _, new in
            if !titleFocused { titleDraft = new }
        }
    }

    private func commit() {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            titleDraft = event.title
            return
        }
        if trimmed != event.title {
            onCommitTitle(trimmed)
        }
    }
}
