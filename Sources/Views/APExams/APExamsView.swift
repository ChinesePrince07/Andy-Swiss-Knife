import SwiftUI

struct APExamsView: View {
    @State private var subscribed: Set<String> = APExamSubscriptions.enabledIDs

    private var grouped: [(Date, [APExam])] {
        let cal = Calendar.current
        let map = Dictionary(grouping: APExamCatalog.exams) { cal.startOfDay(for: $0.date) }
        return map.keys.sorted().map { key in
            (key, (map[key] ?? []).sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return lhs.name < rhs.name
            })
        }
    }

    var body: some View {
        ZStack {
            ThemedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    ForEach(grouped, id: \.0) { day, exams in
                        daySection(day: day, exams: exams)
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
            Text("AP EXAMS · 2026")
                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                .kerning(1.5)
                .foregroundStyle(AppColors.primary)
            Text("Tick the exams you're taking.")
                .font(AppType.caption)
                .foregroundStyle(AppColors.tertiary)
            if !subscribed.isEmpty {
                Rectangle().fill(AppColors.primary).frame(height: 2).padding(.top, 4)
                subscribedSummary
            }
        }
    }

    private var subscribedSummary: some View {
        HStack {
            Text("\(subscribed.count) SELECTED")
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

    private func daySection(day: Date, exams: [APExam]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dayHeader(day).uppercased())
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .kerning(1.3)
                .foregroundStyle(AppColors.primary)
            Rectangle().fill(AppColors.primary).frame(height: 1)
            ForEach(exams) { exam in
                examRow(exam)
                HairlineDivider()
            }
        }
    }

    private func examRow(_ exam: APExam) -> some View {
        let on = subscribed.contains(exam.id)
        return Button {
            toggle(exam, on: !on)
        } label: {
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
                    Text(exam.name)
                        .font(AppType.body)
                        .foregroundStyle(AppColors.primary)
                        .multilineTextAlignment(.leading)
                    Text(exam.session.label)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .kerning(1.1)
                        .foregroundStyle(AppColors.tertiary)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dayHeader(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEE MMM d"
        return df.string(from: d)
    }

    private func toggle(_ exam: APExam, on: Bool) {
        if on { subscribed.insert(exam.id) } else { subscribed.remove(exam.id) }
        APExamSubscriptions.set(exam.id, enabled: on)
    }

    private func clearAll() {
        for id in subscribed { APExamSubscriptions.set(id, enabled: false) }
        subscribed.removeAll()
    }
}
