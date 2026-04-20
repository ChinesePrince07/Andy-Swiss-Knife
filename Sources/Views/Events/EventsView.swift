import SwiftUI
import SwiftData

struct EventsView: View {
    let services: Services

    @State private var events: [Event] = []
    @State private var didLoad = false
    @State private var loadError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Upcoming")
                    .font(AppType.displayTitle)
                    .padding(.top, 8)

                if !didLoad {
                    ProgressView()
                        .padding()
                } else if events.isEmpty {
                    if loadError {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Couldn't load events")
                                .font(AppType.body)
                                .foregroundStyle(AppColors.accent)
                            Button("Retry") {
                                Task { await load(force: true) }
                            }
                            .font(AppType.body)
                        }
                    } else {
                        Text("No events in the next 7 days.")
                            .font(AppType.body)
                            .foregroundStyle(AppColors.secondary)
                    }
                } else {
                    ForEach(grouped, id: \.0) { (day, events) in
                        SectionLabel(text: Self.dayFormatter.string(from: day))
                            .padding(.top, 4)
                        HairlineDivider()
                        ForEach(events) { e in
                            eventRow(e)
                            HairlineDivider()
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(ThemedBackground())
        .navigationTitle("Events")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await load(force: true)
        }
        .task {
            await load(force: false)
        }
    }

    private func eventRow(_ e: Event) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(timeLabel(for: e))
                .font(AppType.caption)
                .foregroundStyle(AppColors.secondary)
                .frame(width: 90, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(e.title)
                    .font(AppType.bodyMedium)
                    .foregroundStyle(AppColors.primary)
                if let location = e.location, !location.isEmpty {
                    Text(location)
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }

    private var grouped: [(Date, [Event])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: events) { cal.startOfDay(for: $0.start) }
        return groups.keys.sorted().map { ($0, groups[$0] ?? []) }
    }

    private func timeLabel(for event: Event) -> String {
        if event.isAllDay { return "All day" }
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        return df.string(from: event.start)
    }

    private func load(force: Bool) async {
        do {
            events = try await services.events.upcomingEvents(forceRefresh: force)
            loadError = false
        } catch {
            loadError = true
        }
        didLoad = true
    }

    static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMM d"
        return df
    }()
}
