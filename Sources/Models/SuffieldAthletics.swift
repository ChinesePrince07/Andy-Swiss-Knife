import Foundation

enum AthleticGender: String, Hashable {
    case boys, girls, coed
}

struct SuffieldTeam: Identifiable, Hashable {
    let id: String          // "168"
    let sport: String       // "Soccer"
    let level: String       // "Varsity", "J.V.", "Tiger A", "Tiger B"
    let gender: AthleticGender

    var feedURL: URL {
        URL(string: "https://www.suffieldacademy.org/calendar/team_\(id).ics")!
    }

    var displayName: String {
        var parts: [String] = [level]
        switch gender {
        case .boys:  parts.append("Boys")
        case .girls: parts.append("Girls")
        case .coed:  break
        }
        parts.append(sport)
        return parts.joined(separator: " ")
    }

    var shortName: String {
        var parts: [String] = [level]
        switch gender {
        case .boys:  parts.append("B")
        case .girls: parts.append("G")
        case .coed:  break
        }
        return parts.joined(separator: " ")
    }
}

enum SuffieldAthletics {
    static let teams: [SuffieldTeam] = [
        // Baseball
        SuffieldTeam(id: "168", sport: "Baseball", level: "Varsity", gender: .coed),
        SuffieldTeam(id: "146", sport: "Baseball", level: "J.V.", gender: .coed),
        // Basketball
        SuffieldTeam(id: "169", sport: "Basketball", level: "Varsity", gender: .boys),
        SuffieldTeam(id: "133", sport: "Basketball", level: "J.V.", gender: .boys),
        SuffieldTeam(id: "134", sport: "Basketball", level: "Tiger A", gender: .boys),
        SuffieldTeam(id: "170", sport: "Basketball", level: "Varsity", gender: .girls),
        SuffieldTeam(id: "135", sport: "Basketball", level: "J.V.", gender: .girls),
        // Crew
        SuffieldTeam(id: "171", sport: "Crew", level: "Varsity", gender: .coed),
        SuffieldTeam(id: "172", sport: "Crew", level: "Varsity", gender: .girls),
        // Cross Country
        SuffieldTeam(id: "120", sport: "Cross Country", level: "Varsity", gender: .boys),
        SuffieldTeam(id: "121", sport: "Cross Country", level: "Varsity", gender: .girls),
        // Diving
        SuffieldTeam(id: "136", sport: "Diving", level: "Varsity", gender: .coed),
        // Field Hockey
        SuffieldTeam(id: "122", sport: "Field Hockey", level: "Varsity", gender: .coed),
        SuffieldTeam(id: "123", sport: "Field Hockey", level: "J.V.", gender: .coed),
        // Football
        SuffieldTeam(id: "161", sport: "Football", level: "Varsity", gender: .coed),
        SuffieldTeam(id: "124", sport: "Football", level: "J.V.", gender: .coed),
        // Golf
        SuffieldTeam(id: "147", sport: "Golf", level: "Varsity", gender: .coed),
        SuffieldTeam(id: "165", sport: "Golf", level: "J.V.", gender: .coed),
        // Lacrosse
        SuffieldTeam(id: "148", sport: "Lacrosse", level: "Varsity", gender: .boys),
        SuffieldTeam(id: "149", sport: "Lacrosse", level: "J.V.", gender: .boys),
        SuffieldTeam(id: "150", sport: "Lacrosse", level: "Varsity", gender: .girls),
        SuffieldTeam(id: "151", sport: "Lacrosse", level: "J.V.", gender: .girls),
        // Riflery
        SuffieldTeam(id: "137", sport: "Riflery", level: "Varsity", gender: .coed),
        // Alpine Skiing
        SuffieldTeam(id: "138", sport: "Alpine Skiing", level: "Varsity", gender: .coed),
        // Soccer
        SuffieldTeam(id: "125", sport: "Soccer", level: "Varsity", gender: .boys),
        SuffieldTeam(id: "166", sport: "Soccer", level: "J.V.", gender: .boys),
        SuffieldTeam(id: "126", sport: "Soccer", level: "Tiger A", gender: .boys),
        SuffieldTeam(id: "127", sport: "Soccer", level: "Tiger B", gender: .boys),
        SuffieldTeam(id: "128", sport: "Soccer", level: "Varsity", gender: .girls),
        SuffieldTeam(id: "129", sport: "Soccer", level: "J.V.", gender: .girls),
        // Softball
        SuffieldTeam(id: "152", sport: "Softball", level: "Varsity", gender: .coed),
        // Squash
        SuffieldTeam(id: "139", sport: "Squash", level: "Varsity", gender: .boys),
        SuffieldTeam(id: "140", sport: "Squash", level: "J.V.", gender: .boys),
        SuffieldTeam(id: "167", sport: "Squash", level: "Tiger A", gender: .boys),
        SuffieldTeam(id: "141", sport: "Squash", level: "Varsity", gender: .girls),
        SuffieldTeam(id: "142", sport: "Squash", level: "J.V.", gender: .girls),
        // Swimming
        SuffieldTeam(id: "143", sport: "Swimming", level: "Varsity", gender: .boys),
        SuffieldTeam(id: "144", sport: "Swimming", level: "Varsity", gender: .girls),
        // Tennis
        SuffieldTeam(id: "154", sport: "Tennis", level: "Varsity", gender: .boys),
        SuffieldTeam(id: "155", sport: "Tennis", level: "J.V.", gender: .boys),
        SuffieldTeam(id: "156", sport: "Tennis", level: "Varsity", gender: .girls),
        SuffieldTeam(id: "157", sport: "Tennis", level: "J.V.", gender: .girls),
        // Track
        SuffieldTeam(id: "158", sport: "Track", level: "Varsity", gender: .boys),
        SuffieldTeam(id: "159", sport: "Track", level: "Varsity", gender: .girls),
        // Volleyball
        SuffieldTeam(id: "131", sport: "Volleyball", level: "Varsity", gender: .coed),
        SuffieldTeam(id: "132", sport: "Volleyball", level: "J.V.", gender: .coed),
        // Water Polo
        SuffieldTeam(id: "130", sport: "Water Polo", level: "Varsity", gender: .boys),
        SuffieldTeam(id: "162", sport: "Water Polo", level: "J.V.", gender: .boys),
        // Wrestling
        SuffieldTeam(id: "145", sport: "Wrestling", level: "Varsity", gender: .coed)
    ]

    static var bySport: [(sport: String, teams: [SuffieldTeam])] {
        let grouped = Dictionary(grouping: teams) { $0.sport }
        return grouped.keys.sorted().map { sport in
            (sport: sport, teams: (grouped[sport] ?? []).sorted(by: teamOrder))
        }
    }

    private static func teamOrder(_ a: SuffieldTeam, _ b: SuffieldTeam) -> Bool {
        let levelRank: (String) -> Int = { level in
            switch level {
            case "Varsity": return 0
            case "J.V.":    return 1
            case "Tiger A": return 2
            case "Tiger B": return 3
            default:        return 4
            }
        }
        if levelRank(a.level) != levelRank(b.level) {
            return levelRank(a.level) < levelRank(b.level)
        }
        return a.gender.rawValue < b.gender.rawValue
    }

    static func team(for id: String) -> SuffieldTeam? {
        teams.first { $0.id == id }
    }
}
