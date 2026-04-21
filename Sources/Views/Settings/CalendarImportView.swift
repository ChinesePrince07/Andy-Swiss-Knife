import SwiftUI
import SwiftData

struct CalendarImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var calendars: [ImportableCalendar] = []
    @State private var selected: Set<String> = []
    @State private var state: ViewState = .idle
    @State private var lastCount: Int = 0

    enum ViewState: Equatable {
        case idle
        case requesting
        case granted
        case denied
        case importing
        case done
    }

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .idle, .requesting:
                    requestingView
                case .denied:
                    deniedView
                case .granted, .importing, .done:
                    calendarList
                }
            }
            .navigationTitle("Import from Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if state == .granted || state == .done, !selected.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(state == .importing ? "Importing…" : "Import") {
                            runImport()
                        }
                        .disabled(state == .importing)
                    }
                }
            }
        }
        .task { await requestAndLoad() }
    }

    private var requestingView: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("Requesting Calendar access…")
                .font(AppType.caption)
                .foregroundStyle(AppColors.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.accent)
            Text("Calendar access denied")
                .font(AppType.bodyMedium)
            Text("Open Settings → Privacy → Calendars to grant access.")
                .font(AppType.caption)
                .foregroundStyle(AppColors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var calendarList: some View {
        List {
            if state == .done, lastCount > 0 {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Imported \(lastCount) new events")
                            .foregroundStyle(AppColors.primary)
                    }
                }
            }

            Section {
                ForEach(calendars) { cal in
                    Button { toggle(cal.id) } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: cal.colorHex))
                                .frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(cal.title)
                                    .foregroundStyle(AppColors.primary)
                                Text(cal.sourceTitle)
                                    .font(AppType.caption)
                                    .foregroundStyle(AppColors.secondary)
                            }
                            Spacer()
                            Image(systemName: selected.contains(cal.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected.contains(cal.id) ? AppColors.accent : AppColors.tertiary)
                        }
                    }
                }
            } header: {
                Text("Select calendars")
            } footer: {
                Text("Imports events from the next 90 days. Re-run anytime to refresh.")
            }
        }
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func requestAndLoad() async {
        state = .requesting
        let importer = CalendarImporter(context: modelContext)
        do {
            let granted = try await importer.requestAccess()
            if granted {
                calendars = importer.availableCalendars().sorted { $0.title < $1.title }
                state = .granted
            } else {
                state = .denied
            }
        } catch {
            state = .denied
        }
    }

    private func runImport() {
        state = .importing
        let importer = CalendarImporter(context: modelContext)
        let count = importer.importEvents(fromCalendarIDs: Array(selected))
        lastCount = count
        state = .done
    }
}

private extension Color {
    init(hex: String) {
        let clean = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xff) / 255.0
        let g = Double((value >> 8) & 0xff) / 255.0
        let b = Double(value & 0xff) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
