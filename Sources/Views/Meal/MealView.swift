import SwiftUI

struct MealView: View {
    let services: Services

    @State private var meal: Meal?
    @State private var error = false
    @State private var didLoad = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Today's menu")
                    .font(AppType.displayTitle)
                    .padding(.top, 8)

                if !didLoad {
                    ProgressView().padding()
                } else if let meal, meal.hasContent {
                    mealBlock(label: "Breakfast", text: meal.breakfast)
                    mealBlock(label: "Lunch", text: meal.lunch)
                    mealBlock(label: "Dinner", text: meal.dinner)
                    if let stale = stalenessNote(for: meal) {
                        Text(stale)
                            .font(AppType.caption)
                            .foregroundStyle(AppColors.secondary)
                            .padding(.top, 10)
                    }
                } else {
                    Text(error ? "Menu unavailable." : "No menu found for today.")
                        .font(AppType.body)
                        .foregroundStyle(error ? AppColors.accent : AppColors.secondary)
                }

                Link(destination: Config.diningURL) {
                    Text("Open full menu in Safari →")
                        .font(AppType.body)
                        .foregroundStyle(AppColors.primary)
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(ThemedBackground())
        .navigationTitle("Menu")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func mealBlock(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: label)
            HairlineDivider()
            if text.isEmpty {
                Text("—")
                    .font(AppType.body)
                    .foregroundStyle(AppColors.secondary)
                    .padding(.vertical, 6)
            } else {
                Text(text)
                    .font(AppType.body)
                    .foregroundStyle(AppColors.primary)
                    .padding(.vertical, 6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func stalenessNote(for meal: Meal) -> String? {
        let age = Int(Date.now.timeIntervalSince(meal.fetchedAt) / 3600)
        if age >= 4 { return "Fetched \(age)h ago" }
        return nil
    }

    private func load() async {
        do {
            meal = try await services.dining.todaysMeal()
            error = false
        } catch {
            meal = services.dining.cachedTodaysMeal()
            self.error = meal == nil
        }
        didLoad = true
    }
}
