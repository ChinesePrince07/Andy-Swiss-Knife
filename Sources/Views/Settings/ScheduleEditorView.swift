import SwiftUI
import SwiftData

struct ScheduleEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScheduleClass.sortKey) private var classes: [ScheduleClass]
    @State private var editing: ScheduleClass?
    @State private var showingAdd = false
    @State private var confirmReset = false

    private static let weekdayLabel = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        List {
            Section {
                if classes.isEmpty {
                    Text("No classes yet.")
                        .foregroundStyle(AppColors.secondary)
                } else {
                    ForEach(classes) { cls in
                        Button { editing = cls } label: {
                            classRow(cls)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteIndices)
                }

                Button {
                    showingAdd = true
                } label: {
                    Label("Add class", systemImage: "plus")
                }
            }

            Section {
                Button("Reset to Suffield defaults") {
                    confirmReset = true
                }
                Button("Delete all classes", role: .destructive) {
                    for c in classes {
                        modelContext.delete(c)
                    }
                    try? modelContext.save()
                }
            } footer: {
                Text("Defaults include Andy's fall 2025 period layout. Edit or replace with your own.")
            }
        }
        .navigationTitle("My classes")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAdd) {
            ClassEditSheet(existing: nil)
        }
        .sheet(item: $editing) { cls in
            ClassEditSheet(existing: cls)
        }
        .alert("Reset to defaults?", isPresented: $confirmReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetDefaults() }
        } message: {
            Text("This deletes your current classes and loads the built-in Suffield schedule.")
        }
    }

    private func classRow(_ cls: ScheduleClass) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(cls.name)
                    .font(AppType.bodyMedium)
                    .foregroundStyle(cls.kindRaw == "lunch" ? AppColors.secondary : AppColors.primary)
                Spacer()
                Text(timeRange(cls))
                    .font(AppType.caption)
                    .foregroundStyle(AppColors.secondary)
                    .monospacedDigit()
            }
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { idx in
                    let iso = idx + 1
                    let active = cls.daysOfWeek.contains(iso)
                    Text(Self.weekdayLabel[idx])
                        .font(.system(size: 9, weight: active ? .semibold : .regular))
                        .foregroundStyle(active ? AppColors.primary : AppColors.tertiary)
                        .frame(width: 16, height: 16)
                        .background(
                            active ? AppColors.hairline : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                }
                Spacer()
                if let room = cls.room {
                    Text(room)
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func timeRange(_ cls: ScheduleClass) -> String {
        String(format: "%02d:%02d–%02d:%02d", cls.startHour, cls.startMinute, cls.endHour, cls.endMinute)
    }

    private func deleteIndices(_ offsets: IndexSet) {
        for i in offsets {
            modelContext.delete(classes[i])
        }
        try? modelContext.save()
    }

    private func resetDefaults() {
        for c in classes {
            modelContext.delete(c)
        }
        for p in defaultSchedule {
            modelContext.insert(ScheduleClass(
                name: p.name,
                room: p.room,
                teacher: p.teacher,
                daysOfWeek: p.daysOfWeek,
                startHour: p.startTime.hour ?? 0,
                startMinute: p.startTime.minute ?? 0,
                endHour: p.endTime.hour ?? 0,
                endMinute: p.endTime.minute ?? 0,
                kindRaw: p.kind == .lunch ? "lunch" : "academic"
            ))
        }
        try? modelContext.save()
    }
}
