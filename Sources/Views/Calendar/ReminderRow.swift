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
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(dateLabel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppColors.secondary)
                if !event.isAllDay {
                    Text(timeLabel)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .kerning(0.8)
                        .foregroundStyle(AppColors.tertiary)
                }
            }
            .frame(width: 80, alignment: .leading)
            .onTapGesture { onOpen() }

            TextField("", text: $titleDraft)
                .font(AppType.bodyMedium)
                .foregroundStyle(AppColors.primary)
                .focused($titleFocused)
                .submitLabel(.done)
                .onSubmit {
                    commitTitle()
                    titleFocused = false
                }
                .onChange(of: titleFocused) { _, focused in
                    if !focused { commitTitle() }
                }

            Button { datePickerShown = true } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.tertiary)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $datePickerShown) {
                reminderDateSheet
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

    private var timeLabel: String {
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        return df.string(from: event.date)
    }

    private var reminderDateSheet: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button("Done") { datePickerShown = false }
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.primary)
            }
            .padding(.horizontal).padding(.top, 12)
            DatePicker(
                "Date",
                selection: Binding(
                    get: { event.date },
                    set: { newVal in
                        event.date = event.isAllDay ? Calendar.current.startOfDay(for: newVal) : newVal
                        try? modelContext.save()
                        SnapshotStore.publishReminders(from: modelContext)
                        WidgetReloader.reloadReminderWidgets()
                    }
                ),
                displayedComponents: event.isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal)

            Toggle("Include time", isOn: Binding(
                get: { !event.isAllDay },
                set: { hasTime in
                    event.isAllDay = !hasTime
                    if hasTime {
                        let cal = Calendar.current
                        var comps = cal.dateComponents([.year, .month, .day], from: event.date)
                        comps.hour = 9; comps.minute = 0
                        event.date = cal.date(from: comps) ?? event.date
                    } else {
                        event.date = Calendar.current.startOfDay(for: event.date)
                    }
                    try? modelContext.save()
                    SnapshotStore.publishReminders(from: modelContext)
                    WidgetReloader.reloadReminderWidgets()
                }
            ))
            .font(AppType.body)
            .tint(AppColors.accent)
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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
}
