import Foundation

/// Hardcoded menu for weeks when Suffield's page is stale or broken.
/// Update `weekStart` and the entries when a new week's menu is known.
enum HardcodedMenu {
    private static let weekStart: DateComponents = .init(year: 2026, month: 4, day: 20)   // Mon
    private static let weekDays = 7

    static func meal(for date: Date, calendar: Calendar = .current) -> Meal? {
        guard let start = calendar.date(from: weekStart),
              let end = calendar.date(byAdding: .day, value: weekDays, to: start)
        else { return nil }
        guard date >= start, date < end else { return nil }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US")
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.dateFormat = "EEEE"
        let weekday = df.string(from: date)

        guard let entry = entries[weekday] else { return nil }

        let keyFormatter = DateFormatter()
        keyFormatter.locale = Locale(identifier: "en_US_POSIX")
        keyFormatter.calendar = calendar
        keyFormatter.timeZone = calendar.timeZone
        keyFormatter.dateFormat = "yyyy-MM-dd"

        return Meal(
            dateKey: keyFormatter.string(from: date),
            breakfast: entry.breakfast,
            lunch: entry.lunch,
            dinner: entry.dinner,
            fetchedAt: .now
        )
    }

    private struct DayEntry {
        let breakfast: String
        let lunch: String
        let dinner: String
    }

    private static let entries: [String: DayEntry] = [
        "Monday": DayEntry(
            breakfast: "Pancakes, Scrambled Eggs, Tater Tots, Sausage Pattie, Fresh Fruit Bar, Cereal Bar, Fresh Baked Muffins",
            lunch: "Grilled Pesto Chicken, Vegetable Fried Rice, Fresh Salad Bar, Deli Bar with Boars Head deli meats including oven roast turkey, honey ham, genoa salami and roast beef, Miso Soup Bar with Toppings",
            dinner: "Korean Style BBQ Popcorn Chicken, Jasmine Rice, Sauteed Green Beans, Salad of the Day- Asian Style Slaw with Crispy Chicken, Fresh Salad Bar, Deli Bar with Boars Head deli meats including oven roast turkey, honey ham, genoa salami and roast beef, Miso Soup Bar with Toppings, Pasta Station with Two Sauces"
        ),
        "Tuesday": DayEntry(
            breakfast: "French Toast Stick, Scrambled Eggs, Bacon, Hash Brown Patties, Fresh Fruit Bar, Cereal Bar, Fresh Baked Muffins, Belgium Waffle Bar",
            lunch: "Spicy Rigatoni, Sweet Sausage and Peppers, Dinner Rolls, Fresh Salad Bar, Deli Bar with Boars Head deli meats including oven roast turkey, honey ham, genoa salami and roast beef, Miso Soup Bar with Toppings",
            dinner: "Beef Birria Tacos, Cilantro Rice, Corn Tortillas, Grilled Mixed Vegetable, Jalapeno Poppers, Fresh Salad Bar, Deli Bar with Boars Head deli meats including oven roast turkey, honey ham, genoa salami and roast beef, Miso Soup Bar with Toppings, Pasta Station with Two Sauces, Homemade Pizza"
        ),
        "Wednesday": DayEntry(
            breakfast: "Waffles, Scrambled Eggs, Sausage Link, Home Fries, Fresh Baked Muffins, Cereal Bar, Fresh Fruit Bar",
            lunch: "Chefs Table- BLT'S, Caribbean Chicken, Fried Plantains, Miso Soup Bar with Toppings, Deli Bar with Boars Head deli meats including oven roast turkey, honey ham, genoa salami and roast beef, Fresh Salad Bar",
            dinner: "Grilled Garlic Parmesan Pork Chops, Roasted Potatoes, Honey Glazed Carrots, Toasted Sandwich- Beef Bahn Mi, Pasta Station with Two Sauces, Miso Soup Bar with Toppings, Deli Bar with Boars Head deli meats including oven roast turkey, honey ham, genoa salami and roast beef, Fresh Salad Bar, Ice Cream Sundae Bar"
        ),
        "Thursday": DayEntry(
            breakfast: "French Toast, Hard Boiled Eggs, Baby Cakes, Corned Beef Hash, Fresh Baked Muffins, Cereal Bar, Fresh Fruit Bar, Make Your Own Omelets",
            lunch: "Chicken Fingers, French Fries, Plant Based Wings(V), Miso Soup Bar with Toppings, Deli Bar with Boars Head deli meats including oven roast turkey, honey ham, genoa salami and roast beef, Fresh Salad Bar",
            dinner: "Curry Chicken Thighs, Basmati Rice, Roasted Cauliflower (V)(GF)(DF), Potato and Pea Samosa, Miso Soup Bar with Toppings, Pasta Station with Two Sauces, Fresh Salad Bar, Deli Bar with Boars Head deli meats including oven roast turkey, honey ham, genoa salami and roast beef"
        ),
        "Friday": DayEntry(
            breakfast: "Chocolate Chip Pancake, Scrambled Eggs, Sausage Patties, Hash Browns, Belgium Waffle Bar, Fresh Baked Muffins, Cereal Bar, Fresh Fruit Bar",
            lunch: "Hoisin Glazed Pork, Vegetable Lo Mein, Miso Soup Bar with Toppings, Deli Bar with Boars Head deli meats including oven roast turkey, honey ham, genoa salami and roast beef, Fresh Salad Bar",
            dinner: "Student Dinner in the Field House, Auction Dinner in the Dining Hall"
        ),
        "Saturday": DayEntry(
            breakfast: "French Toast Stick, Scrambled Eggs, Scrambled Eggs with Bacon & Cheese, Tater Tots, Bacon, Fresh Fruit Bar, Cereal Bar, Fresh Baked Muffins",
            lunch: "Chefs Table- Fish Tacos, Carne Asada, Steamed Rice, Seasoned Black Beans, Fresh Salad Bar, Deli Bar with Boars Head deli meats including oven roast turkey, honey ham, genoa salami and roast beef, Miso Soup Bar with Toppings",
            dinner: "Hamburgers and Hot Dogs, Cajun Fries, Veggie Burgers, Fresh Salad Bar, Deli Bar with Boars Head deli meats including oven roast turkey, honey ham, genoa salami and roast beef, Miso Soup Bar with Toppings, Pasta Station with Two Sauces, Homemade Pizza"
        ),
        "Sunday": DayEntry(
            breakfast: "Egg and Biscuit Sandwich, Baby Cakes, Bacon / Sausage, Cinnamon Rolls, Fresh Fruit Bar, Cereal Bar, Fresh Baked Muffins, Belgium Waffle Bar",
            lunch: "",
            dinner: "Southern Fried Chicken, Onion Rings, Steamed Broccoli(V)(GF)(DF), Fresh Salad Bar, Deli Bar with Boars Head deli meats including oven roast turkey, honey ham, genoa salami and roast beef, Miso Soup Bar with Toppings, Pasta Station with Two Sauces"
        )
    ]
}
