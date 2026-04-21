import Foundation
import SwiftData

enum DiningServiceError: Error, Equatable {
    case notFoundForToday
    case parseFailed
}

@MainActor
final class DiningService {
    private let http: HTTPClient
    private let context: ModelContext
    private let calendar: Calendar
    private let cacheTTL: TimeInterval = 3 * 60 * 60

    init(http: HTTPClient, context: ModelContext, calendar: Calendar = .current) {
        self.http = http
        self.context = context
        self.calendar = calendar
    }

    func todaysMeal(now: Date = .now) async throws -> Meal {
        let key = Self.dateKey(for: now, calendar: calendar)

        if let cached = try fetchCached(dateKey: key),
           now.timeIntervalSince(cached.fetchedAt) < cacheTTL {
            return cached.toMeal()
        }

        let data = try await http.data(for: Config.diningURL)
        let html = String(data: data, encoding: .utf8) ?? ""

        let parsed = try DiningParser.parseToday(html: html, weekday: weekdayName(for: now))

        let menu: CachedMenu
        if let existing = try fetchCached(dateKey: key) {
            existing.fetchedAt = now
            existing.breakfast = parsed.breakfast
            existing.lunch = parsed.lunch
            existing.dinner = parsed.dinner
            menu = existing
        } else {
            menu = CachedMenu(
                dateKey: key,
                fetchedAt: now,
                breakfast: parsed.breakfast,
                lunch: parsed.lunch,
                dinner: parsed.dinner
            )
            context.insert(menu)
        }
        try? context.save()
        UserDefaults.standard.set(now, forKey: "lastSync.menu")
        return menu.toMeal()
    }

    func cachedTodaysMeal(now: Date = .now) -> Meal? {
        let key = Self.dateKey(for: now, calendar: calendar)
        return (try? fetchCached(dateKey: key))?.toMeal()
    }

    private func fetchCached(dateKey: String) throws -> CachedMenu? {
        let predicate = #Predicate<CachedMenu> { $0.dateKey == dateKey }
        var desc = FetchDescriptor<CachedMenu>(predicate: predicate)
        desc.fetchLimit = 1
        return try context.fetch(desc).first
    }

    static func dateKey(for date: Date, calendar: Calendar = .current) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }

    private func weekdayName(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US")
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateFormat = "EEEE"
        return df.string(from: date)
    }
}

private extension CachedMenu {
    func toMeal() -> Meal {
        Meal(
            dateKey: dateKey,
            breakfast: breakfast,
            lunch: lunch,
            dinner: dinner,
            fetchedAt: fetchedAt
        )
    }
}
