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
    @State private var newDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var showingDatePopover = false
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }
            }
            .scrollDismissesKeyboard(.interactively)
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
            let items = (map[key] ?? []).sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                let l = lhs.sortOrder ?? 0
                let r = rhs.sortOrder ?? 0
                return l > r
            }
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
                    .draggable(e.id.uuidString)
                    .dropDestination(for: String.self) { dropped, _ in
                        reorder(droppedIDs: dropped, target: e, within: items)
                    }
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
        if cal.isDateInToday(e.date) { return "Today" }
        if cal.isDateInTomorrow(e.date) { return "Tomorrow" }
        let df = DateFormatter()
        df.dateFormat = "EEE MMM d"
        return df.string(from: e.date)
    }

    private var inlineAddField: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.secondary)
            TextField("", text: $newTitle, prompt: Text("Add reminder…").foregroundColor(AppColors.secondary))
                .font(AppType.body)
                .foregroundStyle(AppColors.primary)
                .focused($addFocused)
                .submitLabel(.done)
                .onSubmit { commitNewReminder() }
            Button { showingDatePopover = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                    Text(shortDate(newDate))
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundStyle(AppColors.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingDatePopover) {
                DatePicker(
                    "Due",
                    selection: Binding(
                        get: { newDate },
                        set: { newDate = Calendar.current.startOfDay(for: $0) }
                    ),
                    displayedComponents: [.date]
                )
                    .datePickerStyle(.graphical)
                    .padding()
                    .presentationCompactAdaptation(.popover)
            }
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

    private func shortDate(_ d: Date) -> String {
        let cal = Calendar.current
        let df = DateFormatter()
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInTomorrow(d) { return "Tmrw" }
        df.dateFormat = "MMM d"
        return df.string(from: d)
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
        let event = PersonalEvent(title: trimmed, date: newDate)
        modelContext.insert(event)
        try? modelContext.save()
        SnapshotStore.publishReminders(from: modelContext)
        WidgetReloader.reloadReminderWidgets()
        newTitle = ""
        newDate = Calendar.current.startOfDay(for: .now)
        addFocused = true
    }

    private func delete(_ e: PersonalEvent) {
        services.notifications.cancel(for: e)
        modelContext.delete(e)
        try? modelContext.save()
        SnapshotStore.publishReminders(from: modelContext)
        WidgetReloader.reloadReminderWidgets()
    }

    private func reorder(droppedIDs: [String], target: PersonalEvent, within bucket: [PersonalEvent]) -> Bool {
        guard let raw = droppedIDs.first, let id = UUID(uuidString: raw),
              let dropped = bucket.first(where: { $0.id == id }), dropped.id != target.id else { return false }
        var arr = bucket
        arr.removeAll { $0.id == dropped.id }
        guard let idx = arr.firstIndex(where: { $0.id == target.id }) else { return false }
        arr.insert(dropped, at: idx)
        let total = arr.count
        for (i, r) in arr.enumerated() {
            r.sortOrder = Double(total - i)
        }
        try? modelContext.save()
        SnapshotStore.publishReminders(from: modelContext)
        WidgetReloader.reloadReminderWidgets()
        return true
    }
}
