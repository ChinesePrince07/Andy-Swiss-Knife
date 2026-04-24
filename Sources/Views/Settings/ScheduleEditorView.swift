import SwiftUI
import SwiftData
import PhotosUI

struct ScheduleEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScheduleClass.sortKey) private var allClasses: [ScheduleClass]
    @State private var confirmReseed = false
    @State private var photoItem: PhotosPickerItem?
    @State private var importResult: String?
    @State private var isImporting = false
    @State private var refreshKey = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Suffield schedule")
                    .font(AppType.displayTitle)
                    .padding(.top, 8)

                Text("Time slots are fixed to Suffield's A–G rotation. Fill in each period with your course, room, and teacher.")
                    .font(AppType.caption)
                    .foregroundStyle(AppColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 13))
                            Text(isImporting ? "SCANNING…" : "IMPORT PHOTO")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .kerning(1.1)
                        }
                        .foregroundStyle(AppColors.primary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .disabled(isImporting)

                    if let result = importResult {
                        Text(result)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(result.contains("Error") ? AppColors.accent : AppColors.secondary)
                    }
                }
                .onChange(of: photoItem) { _, item in
                    guard let item else { return }
                    Task { await handlePhotoImport(item) }
                }

                ForEach(SuffieldTemplate.periods) { period in
                    PeriodCard(
                        period: period,
                        existing: classes(for: period.letter),
                        onCommit: { name, room, teacher in
                            upsert(period: period, name: name, room: room, teacher: teacher)
                        }
                    )
                    .id("\(period.letter)-\(refreshKey)")
                }

                Button {
                    confirmReseed = true
                } label: {
                    Text("Reset template")
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.accent)
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(ThemedBackground())
        .navigationTitle("My classes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { ensureTemplateSeeded() }
        .alert("Reset to empty template?", isPresented: $confirmReseed) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { reseedTemplate(clearing: true) }
        } message: {
            Text("This clears every course name and restores the blank A–G period grid.")
        }
    }

    private func handlePhotoImport(_ item: PhotosPickerItem) async {
        isImporting = true
        importResult = nil
        defer { isImporting = false; photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            importResult = "Error: couldn't load image"
            return
        }
        let courses = await SchedulePDFParser.parseFromImage(image)
        guard !courses.isEmpty else {
            importResult = "Error: no courses found"
            return
        }
        for course in courses {
            guard let period = SuffieldTemplate.periods.first(where: { $0.letter == course.periodLetter }) else { continue }
            upsert(period: period, name: course.name, room: course.room, teacher: course.teacher)
        }
        importResult = "\(courses.count) courses imported"
        refreshKey += 1
    }

    private func classes(for periodKey: String) -> [ScheduleClass] {
        allClasses.filter { $0.periodKey == periodKey }
    }

    private func ensureTemplateSeeded() {
        let keys = Set(allClasses.compactMap { $0.periodKey })
        let allPeriodKeys = Set(SuffieldTemplate.periods.map(\.letter))
        if keys.isSuperset(of: allPeriodKeys) { return }
        reseedTemplate(clearing: false)
    }

    private func reseedTemplate(clearing: Bool) {
        if clearing {
            for c in allClasses { modelContext.delete(c) }
        } else {
            for key in SuffieldTemplate.periods.map(\.letter) {
                for c in allClasses where c.periodKey == key {
                    modelContext.delete(c)
                }
            }
        }
        for period in SuffieldTemplate.periods {
            let seedName = clearing ? "" : nameForSeed(period: period)
            for slot in period.slots {
                let entry = ScheduleClass(
                    name: seedName,
                    room: nil,
                    teacher: nil,
                    daysOfWeek: [slot.day],
                    startHour: slot.startHour,
                    startMinute: slot.startMinute,
                    endHour: slot.endHour,
                    endMinute: slot.endMinute,
                    kindRaw: period.kind == .lunch ? "lunch" : "academic",
                    periodKey: period.letter
                )
                modelContext.insert(entry)
            }
        }
        try? modelContext.save()
        refreshKey += 1
    }

    /// For non-reset seed, reuse any existing name/room/teacher from defaultSchedule
    /// so the user's initial build isn't blank.
    private func nameForSeed(period: SuffieldPeriod) -> String {
        if period.kind == .lunch { return "Lunch" }
        let defaults = defaultSchedule.first { cls in
            cls.daysOfWeek.contains { d in
                period.slots.contains(where: { $0.day == d && $0.startHour == cls.startTime.hour && $0.startMinute == cls.startTime.minute })
            }
        }
        return defaults?.name ?? ""
    }

    private func upsert(period: SuffieldPeriod, name: String, room: String?, teacher: String?) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedRoom = room?.trimmingCharacters(in: .whitespaces)
        let trimmedTeacher = teacher?.trimmingCharacters(in: .whitespaces)

        let existing = classes(for: period.letter)
        let existingBySlot: [String: ScheduleClass] = Dictionary(
            uniqueKeysWithValues: existing.map { cls in
                let key = "\(cls.daysOfWeek.first ?? 0)-\(cls.startHour):\(cls.startMinute)"
                return (key, cls)
            }
        )

        for slot in period.slots {
            let key = "\(slot.day)-\(slot.startHour):\(slot.startMinute)"
            if let row = existingBySlot[key] {
                row.name = trimmedName
                row.room = (trimmedRoom?.isEmpty ?? true) ? nil : trimmedRoom
                row.teacher = (trimmedTeacher?.isEmpty ?? true) ? nil : trimmedTeacher
            } else {
                let entry = ScheduleClass(
                    name: trimmedName,
                    room: (trimmedRoom?.isEmpty ?? true) ? nil : trimmedRoom,
                    teacher: (trimmedTeacher?.isEmpty ?? true) ? nil : trimmedTeacher,
                    daysOfWeek: [slot.day],
                    startHour: slot.startHour,
                    startMinute: slot.startMinute,
                    endHour: slot.endHour,
                    endMinute: slot.endMinute,
                    kindRaw: period.kind == .lunch ? "lunch" : "academic",
                    periodKey: period.letter
                )
                modelContext.insert(entry)
            }
        }
        try? modelContext.save()
    }
}

private struct PeriodCard: View {
    let period: SuffieldPeriod
    let existing: [ScheduleClass]
    let onCommit: (String, String?, String?) -> Void

    @State private var name: String = ""
    @State private var room: String = ""
    @State private var teacher: String = ""
    @FocusState private var focusField: Field?

    enum Field: Hashable { case name, room, teacher }

    private static let dayAbbrev = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(period.letter == "Lunch" ? "LUNCH" : "\(period.letter) PERIOD")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .kerning(1.4)
                    .foregroundStyle(AppColors.primary)
                Spacer()
                Text(slotsSummary)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppColors.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if period.kind == .academic {
                editableField(placeholder: "Course name", text: $name, focus: .name, weight: .medium)
                    .onSubmit { commit() }

                HStack(spacing: 10) {
                    editableField(placeholder: "Room", text: $room, focus: .room, weight: .regular)
                        .onSubmit { commit() }
                    editableField(placeholder: "Teacher", text: $teacher, focus: .teacher, weight: .regular)
                        .onSubmit { commit() }
                }
            } else {
                Text("Lunch block (fixed)")
                    .font(AppType.caption)
                    .foregroundStyle(AppColors.secondary)
            }
        }
        .padding(12)
        .overlay(
            Rectangle()
                .strokeBorder(AppColors.primary, lineWidth: 2)
        )
        .onAppear { hydrate() }
        .onChange(of: focusField) { _, newValue in
            if newValue == nil { commit() }
        }
    }

    private func editableField(placeholder: String, text: Binding<String>, focus: Field, weight: Font.Weight) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 14, weight: weight, design: .monospaced))
            .foregroundStyle(AppColors.primary)
            .focused($focusField, equals: focus)
            .submitLabel(.done)
    }

    private var slotsSummary: String {
        period.slots
            .map { "\(Self.dayAbbrev[$0.day - 1]) \(Self.hhmm($0.startHour, $0.startMinute))" }
            .joined(separator: " · ")
    }

    private static func hhmm(_ h: Int, _ m: Int) -> String {
        String(format: "%02d:%02d", h, m)
    }

    private func hydrate() {
        if let first = existing.first {
            name = first.name
            room = first.room ?? ""
            teacher = first.teacher ?? ""
        }
    }

    private func commit() {
        onCommit(
            name,
            room.isEmpty ? nil : room,
            teacher.isEmpty ? nil : teacher
        )
    }
}
