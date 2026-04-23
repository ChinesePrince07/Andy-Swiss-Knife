import Foundation

struct APExam: Identifiable, Hashable {
    let id: String
    let name: String
    let date: Date
    let session: Session

    enum Session: String, Hashable {
        case morning, afternoon
        var label: String { self == .morning ? "8 AM" : "12 PM" }
    }
}

enum APExamCatalog {
    static let exams: [APExam] = build()

    static func exam(for id: String) -> APExam? {
        exams.first { $0.id == id }
    }

    private static func makeDate(month: Int, day: Int, hour: Int) -> Date {
        var c = DateComponents()
        c.year = 2026
        c.month = month
        c.day = day
        c.hour = hour
        c.minute = 0
        return Calendar.current.date(from: c) ?? .distantFuture
    }

    private static func e(_ id: String, _ name: String, month: Int, day: Int, session: APExam.Session) -> APExam {
        let hour = session == .morning ? 8 : 12
        return APExam(id: id, name: name, date: makeDate(month: month, day: day, hour: hour), session: session)
    }

    // 2026 AP Exam schedule. Source:
    // https://apcentral.collegeboard.org/exam-administration-ordering-scores/exam-dates
    private static func build() -> [APExam] {
        [
            // Week 1 — May 4–8, 2026
            e("bio", "Biology", month: 5, day: 4, session: .morning),
            e("latin", "Latin", month: 5, day: 4, session: .afternoon),
            e("euro", "European History", month: 5, day: 4, session: .afternoon),
            e("micro", "Microeconomics", month: 5, day: 4, session: .afternoon),

            e("chem", "Chemistry", month: 5, day: 5, session: .morning),
            e("humgeo", "Human Geography", month: 5, day: 5, session: .afternoon),
            e("usgov", "US Government and Politics", month: 5, day: 5, session: .afternoon),

            e("englit", "English Literature and Composition", month: 5, day: 6, session: .morning),
            e("compgov", "Comparative Government and Politics", month: 5, day: 6, session: .afternoon),
            e("phys1", "Physics 1: Algebra-Based", month: 5, day: 6, session: .afternoon),

            e("phys2", "Physics 2: Algebra-Based", month: 5, day: 7, session: .morning),
            e("worldhist", "World History: Modern", month: 5, day: 7, session: .afternoon),
            e("afam", "African American Studies", month: 5, day: 7, session: .afternoon),
            e("stats", "Statistics", month: 5, day: 7, session: .afternoon),

            e("italian", "Italian Language and Culture", month: 5, day: 8, session: .morning),
            e("ushist", "United States History", month: 5, day: 8, session: .morning),
            e("chinese", "Chinese Language and Culture", month: 5, day: 8, session: .afternoon),
            e("macro", "Macroeconomics", month: 5, day: 8, session: .afternoon),

            // Week 2 — May 11–15, 2026
            e("calcab", "Calculus AB", month: 5, day: 11, session: .morning),
            e("calcbc", "Calculus BC", month: 5, day: 11, session: .morning),
            e("music", "Music Theory", month: 5, day: 11, session: .afternoon),
            e("seminar", "Seminar", month: 5, day: 11, session: .afternoon),

            e("french", "French Language and Culture", month: 5, day: 12, session: .morning),
            e("precalc", "Precalculus", month: 5, day: 12, session: .morning),
            e("japanese", "Japanese Language and Culture", month: 5, day: 12, session: .afternoon),
            e("psych", "Psychology", month: 5, day: 12, session: .afternoon),

            e("englang", "English Language and Composition", month: 5, day: 13, session: .morning),
            e("german", "German Language and Culture", month: 5, day: 13, session: .morning),
            e("physcmech", "Physics C: Mechanics", month: 5, day: 13, session: .afternoon),
            e("spanlit", "Spanish Literature and Culture", month: 5, day: 13, session: .afternoon),

            e("arthist", "Art History", month: 5, day: 14, session: .morning),
            e("spanlang", "Spanish Language and Culture", month: 5, day: 14, session: .morning),
            e("csp", "Computer Science Principles", month: 5, day: 14, session: .afternoon),
            e("physcem", "Physics C: Electricity and Magnetism", month: 5, day: 14, session: .afternoon),

            e("envsci", "Environmental Science", month: 5, day: 15, session: .morning),
            e("csa", "Computer Science A", month: 5, day: 15, session: .morning),
        ]
    }
}

@MainActor
enum APExamSubscriptions {
    private static let key = "apExams.subscribedIDs.v1"

    static var enabledIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: key) }
    }

    static func isEnabled(_ id: String) -> Bool { enabledIDs.contains(id) }

    static func set(_ id: String, enabled: Bool) {
        var ids = enabledIDs
        if enabled { ids.insert(id) } else { ids.remove(id) }
        enabledIDs = ids
    }

    static var subscribedExams: [APExam] {
        let ids = enabledIDs
        return APExamCatalog.exams
            .filter { ids.contains($0.id) }
            .sorted { $0.date < $1.date }
    }

    static func nextUpcoming(now: Date = .now) -> APExam? {
        subscribedExams.first { $0.date >= now }
    }
}
