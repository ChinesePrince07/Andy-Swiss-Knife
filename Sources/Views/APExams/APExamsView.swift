import SwiftUI

/// Read-only list of AP exams the user is taking. Picker lives in Settings.
struct APExamsView: View {
    private var subscribed: [APExam] { APExamSubscriptions.subscribedExams }

    var body: some View {
        ZStack {
            ThemedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if subscribed.isEmpty {
                        emptyState
                    } else {
                        ForEach(subscribed) { exam in
                            examRow(exam)
                            HairlineDivider()
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
            VStack(alignment: .leading, spacing: 2) {
                Text(exam.name)
                    .font(AppType.bodyMedium)
                    .foregroundStyle(AppColors.primary)
                HStack(spacing: 6) {
                    Text(dayLabel(exam.date))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AppColors.secondary)
                    Text("·")
                        .foregroundStyle(AppColors.tertiary)
                    Text(exam.session.label)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .kerning(1.1)
                        .foregroundStyle(AppColors.tertiary)
                }
            }
            Spacer()
            Text(countdown(exam.date).uppercased())
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .kerning(1.1)
                .foregroundStyle(countdownColor(exam.date))
        }
        .padding(.vertical, 8)
    }

    private func dayLabel(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEE MMM d"
        return df.string(from: d)
    }

    private func countdown(_ d: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: d)).day ?? 0
        if days < 0 { return "Past" }
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days)d"
    }

    private func countdownColor(_ d: Date) -> Color {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: d)).day ?? 0
        if days < 0 { return AppColors.tertiary }
        if days <= 7 { return AppColors.accent }
        return AppColors.secondary
    }
}
