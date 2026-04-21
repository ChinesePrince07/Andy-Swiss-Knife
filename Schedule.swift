 	import Foundation

/// Seed schedule copied into SwiftData on first launch. Users can edit /
/// delete / replace entirely from Settings → Classes.
let defaultSchedule: [ClassPeriod] = [
    ClassPeriod(
        name: "AP Computer Science", room: "TECHCL", teacher: "Healy",
        daysOfWeek: [1, 4],
        startTime: DateComponents(hour: 8, minute: 20),
        endTime: DateComponents(hour: 9, minute: 5)
    ),
    ClassPeriod(
        name: "AP Computer Science", room: "TECHCL", teacher: "Healy",
        daysOfWeek: [2, 5],
        startTime: DateComponents(hour: 9, minute: 10),
        endTime: DateComponents(hour: 10, minute: 15)
    ),

    ClassPeriod(
        name: "English IV", room: "MEM205", teacher: "Rawlings",
        daysOfWeek: [1, 4],
        startTime: DateComponents(hour: 9, minute: 10),
        endTime: DateComponents(hour: 10, minute: 15)
    ),
    ClassPeriod(
        name: "English IV", room: "MEM205", teacher: "Rawlings",
        daysOfWeek: [2, 5],
        startTime: DateComponents(hour: 8, minute: 20),
        endTime: DateComponents(hour: 9, minute: 5)
    ),

    ClassPeriod(
        name: "Chamber Ensemble", room: "GUTTMS", teacher: "Papadopoulos",
        daysOfWeek: [1, 4],
        startTime: DateComponents(hour: 10, minute: 20),
        endTime: DateComponents(hour: 11, minute: 5)
    ),
    ClassPeriod(
        name: "Chamber Ensemble", room: "GUTTMS", teacher: "Papadopoulos",
        daysOfWeek: [2, 5],
        startTime: DateComponents(hour: 11, minute: 10),
        endTime: DateComponents(hour: 12, minute: 15)
    ),

    ClassPeriod(
        name: "Spanish III", room: nil, teacher: "Nigro",
        daysOfWeek: [1],
        startTime: DateComponents(hour: 11, minute: 10),
        endTime: DateComponents(hour: 12, minute: 15)
    ),
    ClassPeriod(
        name: "Spanish III", room: nil, teacher: "Nigro",
        daysOfWeek: [3, 6],
        startTime: DateComponents(hour: 9, minute: 30),
        endTime: DateComponents(hour: 10, minute: 15)
    ),
    ClassPeriod(
        name: "Spanish III", room: nil, teacher: "Nigro",
        daysOfWeek: [4],
        startTime: DateComponents(hour: 13, minute: 5),
        endTime: DateComponents(hour: 14, minute: 10)
    ),

    ClassPeriod(
        name: "Multivariable Calc Honors", room: nil, teacher: "Vasilenko",
        daysOfWeek: [1],
        startTime: DateComponents(hour: 14, minute: 0),
        endTime: DateComponents(hour: 15, minute: 5)
    ),
    ClassPeriod(
        name: "Multivariable Calc Honors", room: nil, teacher: "Vasilenko",
        daysOfWeek: [2],
        startTime: DateComponents(hour: 10, minute: 20),
        endTime: DateComponents(hour: 11, minute: 5)
    ),
    ClassPeriod(
        name: "Multivariable Calc Honors", room: nil, teacher: "Vasilenko",
        daysOfWeek: [4],
        startTime: DateComponents(hour: 11, minute: 10),
        endTime: DateComponents(hour: 12, minute: 15)
    ),
    ClassPeriod(
        name: "Multivariable Calc Honors", room: nil, teacher: "Vasilenko",
        daysOfWeek: [5],
        startTime: DateComponents(hour: 13, minute: 5),
        endTime: DateComponents(hour: 13, minute: 50)
    ),

    ClassPeriod(
        name: "AP Physics C (E&M)", room: nil, teacher: "Sullivan",
        daysOfWeek: [2],
        startTime: DateComponents(hour: 13, minute: 5),
        endTime: DateComponents(hour: 13, minute: 50)
    ),
    ClassPeriod(
        name: "AP Physics C (E&M)", room: nil, teacher: "Sullivan",
        daysOfWeek: [3],
        startTime: DateComponents(hour: 8, minute: 20),
        endTime: DateComponents(hour: 9, minute: 25)
    ),
    ClassPeriod(
        name: "AP Physics C (E&M)", room: nil, teacher: "Sullivan",
        daysOfWeek: [5],
        startTime: DateComponents(hour: 13, minute: 55),
        endTime: DateComponents(hour: 14, minute: 40)
    ),
    ClassPeriod(
        name: "AP Physics C (E&M)", room: nil, teacher: "Sullivan",
        daysOfWeek: [6],
        startTime: DateComponents(hour: 10, minute: 20),
        endTime: DateComponents(hour: 11, minute: 25)
    ),

    ClassPeriod(
        name: "Economics (AP)", room: "CEN208", teacher: "Pentz",
        daysOfWeek: [2],
        startTime: DateComponents(hour: 13, minute: 55),
        endTime: DateComponents(hour: 14, minute: 40)
    ),
    ClassPeriod(
        name: "Economics (AP)", room: "CEN208", teacher: "Pentz",
        daysOfWeek: [3],
        startTime: DateComponents(hour: 10, minute: 20),
        endTime: DateComponents(hour: 11, minute: 25)
    ),
    ClassPeriod(
        name: "Economics (AP)", room: "CEN208", teacher: "Pentz",
        daysOfWeek: [5],
        startTime: DateComponents(hour: 10, minute: 20),
        endTime: DateComponents(hour: 11, minute: 5)
    ),
    ClassPeriod(
        name: "Economics (AP)", room: "CEN208", teacher: "Pentz",
        daysOfWeek: [6],
        startTime: DateComponents(hour: 8, minute: 20),
        endTime: DateComponents(hour: 9, minute: 25)
    ),

    ClassPeriod(
        name: "Lunch", room: nil, teacher: nil,
        daysOfWeek: [1, 2, 4, 5],
        startTime: DateComponents(hour: 12, minute: 20),
        endTime: DateComponents(hour: 13, minute: 0),
        kind: .lunch
    ),
    ClassPeriod(
        name: "Lunch", room: nil, teacher: nil,
        daysOfWeek: [3, 6],
        startTime: DateComponents(hour: 11, minute: 30),
        endTime: DateComponents(hour: 12, minute: 30),
        kind: .lunch
    ),
]
