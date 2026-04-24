import SwiftUI
import SwiftData

struct ClassesView: View {
    @Query(sort: \ScheduleClass.sortKey) private var scheduleClasses: [ScheduleClass]

    private var allPeriods: [ClassPeriod] {
        scheduleClasses.asClassPeriods()
    }

    private var todaysClasses: [ClassPeriod] {
        allPeriods.today()
    }

    private var todayDone: Bool {
        guard !todaysClasses.isEmpty else { return true }
        let last = todaysClasses.last!
        guard let end = last.endDate(on: .now) else { return false }
        return Date.now > end
    }

    private var nextDayDate: Date? {
        for offset in 1...7 {
            guard let day = Calendar.current.date(byAdding: .day, value: offset, to: .now) else { continue }
            let iso = isoWeekday(from: day)
            if allPeriods.contains(where: { $0.occursOn(weekday: iso) }) { return day }
        }
        return nil
    }

    private func classesFor(_ date: Date) -> [ClassPeriod] {
        let iso = isoWeekday(from: date)
        return allPeriods
            .filter { $0.occursOn(weekday: iso) }
            .sorted { ($0.startTime.hour ?? 0, $0.startTime.minute ?? 0) < ($1.startTime.hour ?? 0, $1.startTime.minute ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                dayBlock(date: .now, classes: todaysClasses, isToday: true)

                if todayDone, let next = nextDayDate {
                    dayBlock(date: next, classes: classesFor(next), isToday: false)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(ThemedBackground())
        .navigationTitle("Classes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dayBlock(date: Date, classes: [ClassPeriod], isToday: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Self.weekdayName(date))'s classes")
                    .font(AppType.displayTitle)
                if !isToday {
                    Text("UP NEXT")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .kerning(1.1)
                        .foregroundStyle(AppColors.accent)
                }
            }
            .padding(.top, isToday ? 8 : 16)

            if classes.isEmpty {
                Text("No classes scheduled.")
                    .font(AppType.body)
                    .foregroundStyle(AppColors.secondary)
                    .padding(.top, 10)
            } else {
                ForEach(classes) { cls in
                    HairlineDivider()
                    classRow(cls)
                }
                HairlineDivider()
            }
        }
    }

    private func classRow(_ cls: ClassPeriod) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(startTime(for: cls))
                    .font(AppType.bodyMedium)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.primary)
                Text(endTime(for: cls))
                    .font(AppType.caption)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.tertiary)
            }
            .frame(width: 70, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(cls.name)
                    .font(AppType.bodyMedium)
                    .foregroundStyle(cls.kind == .lunch ? AppColors.secondary : AppColors.primary)
                if let detail = classDetail(cls), !detail.isEmpty {
                    Text(detail)
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func startTime(for cls: ClassPeriod) -> String {
        String(format: "%02d:%02d", cls.startTime.hour ?? 0, cls.startTime.minute ?? 0)
    }

    private func endTime(for cls: ClassPeriod) -> String {
        "–\(String(format: "%02d:%02d", cls.endTime.hour ?? 0, cls.endTime.minute ?? 0))"
    }

    private func classDetail(_ cls: ClassPeriod) -> String? {
        var parts: [String] = []
        if let room = cls.room, !room.isEmpty { parts.append(room) }
        if let t = cls.teacher, !t.isEmpty { parts.append(t) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func weekdayName(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US")
        df.dateFormat = "EEEE"
        return df.string(from: date)
    }
}
