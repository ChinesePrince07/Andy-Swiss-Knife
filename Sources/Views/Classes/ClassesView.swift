import SwiftUI
import SwiftData

struct ClassesView: View {
    @Query(sort: \ScheduleClass.sortKey) private var scheduleClasses: [ScheduleClass]

    private var todaysClasses: [ClassPeriod] {
        scheduleClasses.asClassPeriods().today()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("\(Self.weekdayName(.now))'s classes")
                    .font(AppType.displayTitle)
                    .padding(.top, 8)

                if todaysClasses.isEmpty {
                    Text("No classes scheduled.")
                        .font(AppType.body)
                        .foregroundStyle(AppColors.secondary)
                        .padding(.top, 20)
                } else {
                    ForEach(todaysClasses) { cls in
                        HairlineDivider()
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
                        .padding(.vertical, 8)
                    }
                    HairlineDivider()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(ThemedBackground())
        .navigationTitle("Classes")
        .navigationBarTitleDisplayMode(.inline)
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
