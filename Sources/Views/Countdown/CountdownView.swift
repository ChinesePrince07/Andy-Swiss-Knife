import SwiftUI
import SwiftData

struct CountdownView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var events: [CachedEvent] = []

    var body: some View {
        ZStack {
            ThemedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if events.isEmpty {
                        emptyState
                    } else {
                        ForEach(events) { event in
                            countdownRow(event)
                            HairlineDivider()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Countdown")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("COUNTDOWNS")
                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                .kerning(1.5)
                .foregroundStyle(AppColors.primary)
            Text("Pick events in Settings → Countdown.")
                .font(AppType.caption)
                .foregroundStyle(AppColors.tertiary)
            Rectangle().fill(AppColors.primary).frame(height: 2).padding(.top, 4)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No countdowns selected.")
                .font(AppType.body)
                .foregroundStyle(AppColors.secondary)
            Text("Pick events in Settings → Countdown.")
                .font(AppType.caption)
                .foregroundStyle(AppColors.tertiary)
        }
        .padding(.top, 20)
    }

    private func countdownRow(_ event: CachedEvent) -> some View {
        let days = daysUntil(event.start)
        let past = days < 0
        return HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(past ? "PAST" : "\(days)")
                .font(.system(size: past ? 14 : 28, weight: .heavy, design: .monospaced))
                .foregroundStyle(past ? AppColors.tertiary : (days <= 7 ? AppColors.accent : AppColors.primary))
                .frame(width: 60, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                if !past {
                    Text(days == 0 ? "TODAY" : (days == 1 ? "DAY" : "DAYS"))
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .kerning(1.1)
                        .foregroundStyle(AppColors.tertiary)
                }
                CountdownNameField(event: event, past: past)
                Text(dateLabel(event.start))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppColors.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func daysUntil(_ date: Date) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: date)).day ?? 0
    }

    private func dateLabel(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEE MMM d"
        return df.string(from: d)
    }

    private func reload() {
        events = CountdownSubscriptions.allSelected(from: modelContext)
    }
}

private struct CountdownNameField: View {
    let event: CachedEvent
    let past: Bool

    @State private var draft: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $draft)
            .font(AppType.bodyMedium)
            .foregroundStyle(past ? AppColors.tertiary : AppColors.primary)
            .focused($focused)
            .submitLabel(.done)
            .onSubmit { commit() }
            .onChange(of: focused) { _, f in if !f { commit() } }
            .onAppear { draft = CountdownSubscriptions.displayName(for: event) }
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { draft = event.title; return }
        if trimmed == event.title {
            CountdownSubscriptions.setCustomName(nil, for: event.id)
        } else {
            CountdownSubscriptions.setCustomName(trimmed, for: event.id)
        }
    }
}
