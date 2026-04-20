import Foundation

let schedule: [ClassPeriod] = [
    ClassPeriod(
        name: "English",
        room: "Rm 204",
        teacher: nil,
        daysOfWeek: [1, 3, 5],
        startTime: DateComponents(hour: 9, minute: 25),
        endTime: DateComponents(hour: 10, minute: 10)
    ),
    ClassPeriod(
        name: "Calculus",
        room: "Rm 118",
        teacher: nil,
        daysOfWeek: [1, 2, 4, 5],
        startTime: DateComponents(hour: 10, minute: 20),
        endTime: DateComponents(hour: 11, minute: 5)
    ),
    ClassPeriod(
        name: "Biology",
        room: "Science 301",
        teacher: nil,
        daysOfWeek: [2, 4],
        startTime: DateComponents(hour: 11, minute: 15),
        endTime: DateComponents(hour: 12, minute: 0)
    )
]
