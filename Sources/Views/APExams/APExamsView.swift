import SwiftUI

/// Read-only list of AP exams the user is taking. Picker lives in Settings.
struct APExamsView: View {
    private var subscribed: [APExam] { APExamSubscriptions.subscribedExams }

    private var grouped: [(Date, [APExam])] {
        let cal = Calendar.current
        let map = Dictionary(grouping: subscribed) { cal.startOfDay(for: $0.date) }
        return map.keys.sorted().map { key in
            (key, (map[key] ?? []).sorted { $0.date < $1.date })
        }
    }

    var body: some View {
        ZStack {
            ThemedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if subscribed.isEmpty {
                        emptyState
                    } else {
                        ForEach(grouped, id: \.0) { day, exams in
                            daySection(day: day, exams: exams)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("AP Exams")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func daySection(day: Date, exams: [APExam]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(dayHeaderText(day).uppercased())
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .kerning(1.4)
                    .foregroundStyle(dayHeaderColor(day))
                Spacer()
                Text(countdown(day).uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.1)
                    .foregroundStyle(dayHeaderColor(day))
            }
            Rectangle().fill(dayHeaderColor(day)).frame(height: 2)
            ForEach(exams) { exam in
                examRow(exam)
                HairlineDivider()
            }
        }
    }

    private func dayHeaderText(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInTomorrow(d) { return "Tomorrow" }
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMM d"
        return df.string(from: d)
    }

    private func dayHeaderColor(_ d: Date) -> Color {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: d)).day ?? 0
        if days < 0 { return AppColors.tertiary }
        if days <= 7 { return AppColors.accent }
        return AppColors.primary
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOUR AP EXAMS")
                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                .kerning(1.5)
                .foregroundStyle(AppColors.primary)
            Text("Edit selection in Settings → AP Exams.")
                .font(AppType.caption)
                .foregroundStyle(AppColors.tertiary)
            Rectangle().fill(AppColors.primary).frame(height: 2).padding(.top, 4)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No exams selected.")
                .font(AppType.body)
                .foregroundStyle(AppColors.secondary)
            Text("Pick yours in Settings → AP Exams.")
                .font(AppType.caption)
                .foregroundStyle(AppColors.tertiary)
        }
        .padding(.top, 20)
    }

    private func examRow(_ exam: APExam) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(exam.session.label)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .kerning(1.1)
                .foregroundStyle(AppColors.tertiary)
                .frame(width: 58, alignment: .leading)
            Text(exam.name)
                .font(AppType.bodyMedium)
                .foregroundStyle(AppColors.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }

    private func countdown(_ d: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: d)).day ?? 0
        if days < 0 { return "Past" }
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days)d"
    }
}
