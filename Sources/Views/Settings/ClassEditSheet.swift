import SwiftUI
import SwiftData

struct ClassEditSheet: View {
    let existing: ScheduleClass?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var room = ""
    @State private var teacher = ""
    @State private var days: Set<Int> = []       // ISO weekday 1...7
    @State private var start: Date = Self.defaultTime(hour: 8, minute: 20)
    @State private var end: Date = Self.defaultTime(hour: 9, minute: 5)
    @State private var isLunch = false

    private static let weekdayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Class") {
                    TextField("Name (e.g. AP Calc)", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Room (optional)", text: $room)
                    TextField("Teacher (optional)", text: $teacher)
                }

                Section("Days") {
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { idx in
                            let iso = idx + 1
                            let active = days.contains(iso)
                            Button {
                                if active { days.remove(iso) } else { days.insert(iso) }
                            } label: {
                                Text(Self.weekdayLabels[idx])
                                    .font(.system(size: 11, weight: active ? .semibold : .regular))
                                    .foregroundStyle(active ? AppColors.background : AppColors.primary)
                                    .frame(width: 40, height: 32)
                                    .background(
                                        active ? AppColors.primary : AppColors.hairline,
                                        in: RoundedRectangle(cornerRadius: 6)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Section("Time") {
                    DatePicker("Start", selection: $start, displayedComponents: [.hourAndMinute])
                    DatePicker("End", selection: $end, displayedComponents: [.hourAndMinute])
                }

                Section {
                    Toggle("Lunch block (hides from Next Class card)", isOn: $isLunch)
                }
            }
            .navigationTitle(existing == nil ? "New class" : "Edit class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
        }
        .onAppear {
            if let e = existing {
                name = e.name
                room = e.room ?? ""
                teacher = e.teacher ?? ""
                days = Set(e.daysOfWeek)
                start = Self.defaultTime(hour: e.startHour, minute: e.startMinute)
                end = Self.defaultTime(hour: e.endHour, minute: e.endMinute)
                isLunch = e.kindRaw == "lunch"
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !days.isEmpty
    }

    private func save() {
        let cal = Calendar.current
        let sComps = cal.dateComponents([.hour, .minute], from: start)
        let eComps = cal.dateComponents([.hour, .minute], from: end)
        let trimmedRoom = room.trimmingCharacters(in: .whitespaces)
        let trimmedTeacher = teacher.trimmingCharacters(in: .whitespaces)

        if let e = existing {
            e.name = name.trimmingCharacters(in: .whitespaces)
            e.room = trimmedRoom.isEmpty ? nil : trimmedRoom
            e.teacher = trimmedTeacher.isEmpty ? nil : trimmedTeacher
            e.daysOfWeek = days.sorted()
            e.startHour = sComps.hour ?? 0
            e.startMinute = sComps.minute ?? 0
            e.endHour = eComps.hour ?? 0
            e.endMinute = eComps.minute ?? 0
            e.kindRaw = isLunch ? "lunch" : "academic"
            let first = e.daysOfWeek.min() ?? 8
            e.sortKey = first * 10000 + e.startHour * 100 + e.startMinute
        } else {
            let new = ScheduleClass(
                name: name.trimmingCharacters(in: .whitespaces),
                room: trimmedRoom.isEmpty ? nil : trimmedRoom,
                teacher: trimmedTeacher.isEmpty ? nil : trimmedTeacher,
                daysOfWeek: days.sorted(),
                startHour: sComps.hour ?? 0,
                startMinute: sComps.minute ?? 0,
                endHour: eComps.hour ?? 0,
                endMinute: eComps.minute ?? 0,
                kindRaw: isLunch ? "lunch" : "academic"
            )
            modelContext.insert(new)
        }
        try? modelContext.save()
        dismiss()
    }

    private static func defaultTime(hour: Int, minute: Int) -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c) ?? .now
    }
}
