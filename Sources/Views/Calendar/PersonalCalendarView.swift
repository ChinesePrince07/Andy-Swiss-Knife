import SwiftUI
import SwiftData

struct PersonalCalendarView: View {
    let services: Services

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonalEvent.date, order: .forward)
    private var events: [PersonalEvent]

    @State private var showingAdd = false
    @State private var editing: PersonalEvent?
    private let deepLinks = DeepLinks.shared

    var body: some View {
        ZStack {
            ThemedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if visibleEvents.isEmpty {
                        emptyState
                    } else {
                        ForEach(grouped, id: \.0) { (day, dayEvents) in
                            SectionLabel(text: Self.dayFormatter.string(from: day))
                                .padding(.top, 4)
                            HairlineDivider()
                            ForEach(dayEvents) { e in
                                eventRow(e)
                                HairlineDivider()
                            }
                        }
                    }

                    Button {
                        showingAdd = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Add event")
                        }
                        .font(AppType.body)
                        .foregroundStyle(AppColors.primary)
                        .padding(.vertical, 10)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Calendar")
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
            Text("\(visibleEvents.count) upcoming")
                .font(AppType.caption)
                .foregroundStyle(AppColors.secondary)
        }
    }

    private var visibleEvents: [PersonalEvent] {
        events.filter { $0.date >= Calendar.current.startOfDay(for: .now) }
    }

    private var grouped: [(Date, [PersonalEvent])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: visibleEvents) { cal.startOfDay(for: $0.date) }
        return groups.keys.sorted().map { ($0, (groups[$0] ?? []).sorted { $0.date < $1.date }) }
    }

    private var emptyState: some View {
        Text("No reminders yet.")
            .font(AppType.body)
            .foregroundStyle(AppColors.secondary)
            .padding(.vertical, 20)
    }

    private func eventRow(_ e: PersonalEvent) -> some View {
        Button {
            editing = e
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(timeLabel(for: e))
                    .font(AppType.caption)
                    .foregroundStyle(AppColors.secondary)
                    .frame(width: 78, alignment: .leading)
                VStack(alignment: .leading, spacing: 1) {
                    Text(e.title)
                        .font(AppType.bodyMedium)
                        .foregroundStyle(AppColors.primary)
                    if let notes = e.notes, !notes.isEmpty {
                        Text(notes)
                            .font(AppType.caption)
                            .foregroundStyle(AppColors.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                delete(e)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func timeLabel(for e: PersonalEvent) -> String {
        if e.isAllDay { return "All day" }
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        return df.string(from: e.date)
    }

    private func delete(_ e: PersonalEvent) {
        services.notifications.cancel(for: e)
        modelContext.delete(e)
        try? modelContext.save()
        SnapshotStore.publishReminders(from: modelContext)
        WidgetReloader.reloadReminderWidgets()
    }

    static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMM d"
        return df
    }()
}
