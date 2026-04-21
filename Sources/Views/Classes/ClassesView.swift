import SwiftUI

struct ClassesView: View {
    private let todaysClasses = schedule.today()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Today's classes")
                    .font(AppType.displayTitle)
                    .padding(.top, 8)

                if todaysClasses.isEmpty {
                    Text("No classes scheduled today.")
                        .font(AppType.body)
                        .foregroundStyle(AppColors.secondary)
                        .padding(.top, 20)
                } else {
                    ForEach(todaysClasses) { cls in
                        HairlineDivider()
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(timeRange(for: cls))
                                .font(AppType.caption)
                                .foregroundStyle(AppColors.secondary)
                                .frame(width: 82, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(cls.name)
                                    .font(AppType.bodyMedium)
                                    .foregroundStyle(cls.kind == .lunch ? AppColors.secondary : AppColors.primary)
                                if let room = cls.room {
                                    Text(room)
                                        .font(AppType.caption)
                                        .foregroundStyle(AppColors.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
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

    private func timeRange(for cls: ClassPeriod) -> String {
        let df = DateFormatter()
        df.dateFormat = "h:mm"
        let today = Date()
        guard let start = cls.startDate(on: today),
              let end = cls.endDate(on: today) else { return "" }
        return "\(df.string(from: start)) – \(df.string(from: end))"
    }
}
