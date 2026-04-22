import SwiftUI
import SwiftData

struct PersonalCalendarView: View {
    let services: Services

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonalEvent.date, order: .forward)
    private var events: [PersonalEvent]

    @State private var showingAdd = false
    @State private var editing: PersonalEvent?
    @State private var newTitle: String = ""
    @FocusState private var addFocused: Bool
    private let deepLinks = DeepLinks.shared

    var body: some View {
        ZStack {
            ThemedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if events.isEmpty {
                        emptyState
                    } else {
                        ForEach(buckets, id: \.0) { bucket, items in
                            bucketSection(bucket: bucket, items: items)
                        }
                    }
                    inlineAddField
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAdd) {
            PersonalEventEditSheet(services: services, existing: nil)
        }
        .sheet(item: $editing) { event in
            PersonalEventEditSheet(services: services, existing: event)
        }
        .onChange(of: deepLinks.pendingAction) { _, action in
            if action == .addReminder {
                showingAdd = true
                deepLinks.clear()
            }
        }
        .onAppear {
            if deepLinks.pendingAction == .addReminder {
                showingAdd = true
                deepLinks.clear()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Reminders")
                .font(AppType.displayTitle)
                .foregroundStyle(AppColors.primary)
            Text("\(events.count) total")
                .font(AppType.caption)
                .foregroundStyle(AppColors.secondary)
        }
    }

    private var emptyState: some View {
        Text("No reminders yet.")
            .font(AppType.body)
            .foregroundStyle(AppColors.secondary)
            .padding(.vertical, 20)
    }

    private var buckets: [(DueBucket, [PersonalEvent])] {
        var map: [DueBucket: [PersonalEvent]] = [:]
        for e in events {
            let b = DueBucket.bucket(for: e.date)
            map[b, default: []].append(e)
        }
        return map.keys.sorted { $0.order < $1.order }.map { key in
            let items = (map[key] ?? []).sorted { $0.date < $1.date }
            return (key, items)
        }
    }

    private func bucketSection(bucket: DueBucket, items: [PersonalEvent]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(bucket.title.uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .kerning(1.4)
                    .foregroundStyle(bucket.isUrgent ? AppColors.accent : AppColors.primary)
                if let subtitle = bucket.subtitle {
                    Text(subtitle)
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.tertiary)
                }
                Spacer()
                Text("\(items.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppColors.tertiary)
            }
            Rectangle()
                .fill(bucket.isUrgent ? AppColors.accent : AppColors.primary)
                .frame(height: bucket.isUrgent ? 2 : 1)
                .padding(.bottom, 2)
            ForEach(items) { e in
                reminderRow(e)
                HairlineDivider()
            }
        }
    }

    private func reminderRow(_ e: PersonalEvent) -> some View {
        ReminderRow(
            event: e,
            dateLabel: rowDateLabel(for: e),
            onOpen: { editing = e },
            onDelete: { delete(e) },
            onCommitTitle: { commitTitle(e, $0) }
        )
    }

    private func rowDateLabel(for e: PersonalEvent) -> String {
        let cal = Calendar.current
        let df = DateFormatter()
        if e.isAllDay {
            df.dateFormat = "EEE MMM d"
            return df.string(from: e.date)
        }
        if cal.isDateInToday(e.date) {
            df.dateFormat = "HH:mm"
            return df.string(from: e.date)
        }
        if cal.isDateInTomorrow(e.date) {
            df.dateFormat = "'Tmrw' HH:mm"
            return df.string(from: e.date)
        }
        df.dateFormat = "EEE MMM d · HH:mm"
        return df.string(from: e.date)
    }

    private var inlineAddField: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.tertiary)
            TextField("Add reminder…", text: $newTitle)
                .font(AppType.body)
                .foregroundStyle(AppColors.primary)
                .focused($addFocused)
                .submitLabel(.done)
                .onSubmit { commitNewReminder() }
            if !newTitle.isEmpty {
                Button { showingAdd = true } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
    }

    private func commitTitle(_ e: PersonalEvent, _ newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != e.title else { return }
        e.title = trimmed
        try? modelContext.save()
        SnapshotStore.publishReminders(from: modelContext)
        WidgetReloader.reloadReminderWidgets()
    }

    private func commitNewReminder() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let defaultDate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        let event = PersonalEvent(title: trimmed, date: defaultDate)
        modelContext.insert(event)
        try? modelContext.save()
        SnapshotStore.publishReminders(from: modelContext)
        WidgetReloader.reloadReminderWidgets()
        newTitle = ""
        addFocused = true
    }

    private func delete(_ e: PersonalEvent) {
        services.notifications.cancel(for: e)
        modelContext.delete(e)
        try? modelContext.save()
        SnapshotStore.publishReminders(from: modelContext)
        WidgetReloader.reloadReminderWidgets()
    }
}
