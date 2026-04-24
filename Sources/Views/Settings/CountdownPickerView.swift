import SwiftUI
import SwiftData

struct CountdownPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selected: Set<String> = CountdownSubscriptions.selectedIDs
    @State private var events: [CachedEvent] = []

    private var grouped: [(Date, [CachedEvent])] {
        let cal = Calendar.current
        let upcoming = events.filter { $0.start >= cal.startOfDay(for: .now) }
        let map = Dictionary(grouping: upcoming) { cal.startOfDay(for: $0.start) }
        return map.keys.sorted().map { key in
            (key, (map[key] ?? []).sorted { $0.start < $1.start })
        }
    }

    var body: some View {
        ZStack {
            ThemedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if events.isEmpty {
                        Text("No school events synced yet. Pull to refresh on dashboard first.")
                            .font(AppType.body)
                            .foregroundStyle(AppColors.secondary)
                            .padding(.top, 20)
                    } else {
                        ForEach(grouped, id: \.0) { day, dayEvents in
                            daySection(day: day, events: dayEvents)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Pick countdowns")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("COUNTDOWN EVENTS")
                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                .kerning(1.5)
                .foregroundStyle(AppColors.primary)
            Text("Tick events to count down to on the dashboard.")
                .font(AppType.caption)
                .foregroundStyle(AppColors.tertiary)
            if !selected.isEmpty {
                Rectangle().fill(AppColors.primary).frame(height: 2).padding(.top, 4)
                HStack {
                    Text("\(selected.count) SELECTED")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .kerning(1.3)
                        .foregroundStyle(AppColors.primary)
                    Spacer()
                    Button { clearAll() } label: {
                        Text("CLEAR")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .kerning(1.1)
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .overlay(Rectangle().strokeBorder(AppColors.accent, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func daySection(day: Date, events: [CachedEvent]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dayHeader(day).uppercased())
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .kerning(1.3)
                .foregroundStyle(AppColors.primary)
            Rectangle().fill(AppColors.primary).frame(height: 1)
            ForEach(events) { event in
                eventRow(event)
                HairlineDivider()
            }
        }
    }

    private func eventRow(_ event: CachedEvent) -> some View {
        let on = selected.contains(event.id)
        return Button { toggle(event, on: !on) } label: {
            HStack(spacing: 12) {
                ZStack {
                    Rectangle()
                        .strokeBorder(AppColors.primary, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if on {
                        Rectangle()
                            .fill(AppColors.primary)
                            .frame(width: 14, height: 14)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(AppType.body)
                        .foregroundStyle(AppColors.primary)
                        .multilineTextAlignment(.leading)
                    Text("\(daysUntil(event.start))d away")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .kerning(1.1)
                        .foregroundStyle(AppColors.tertiary)
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dayHeader(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEE MMM d"
        return df.string(from: d)
    }

    private func daysUntil(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: date)).day ?? 0
    }

    private func toggle(_ event: CachedEvent, on: Bool) {
        if on { selected.insert(event.id) } else { selected.remove(event.id) }
        CountdownSubscriptions.set(event.id, selected: on)
    }

    private func clearAll() {
        for id in selected { CountdownSubscriptions.set(id, selected: false) }
        selected.removeAll()
    }

    private func reload() {
        let descriptor = FetchDescriptor<CachedEvent>(
            sortBy: [SortDescriptor(\CachedEvent.start)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        events = all.filter { ($0.source ?? "") == "school" }
    }
}
