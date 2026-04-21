import SwiftUI
import SwiftData

struct CalendarImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var calendars: [ImportableCalendar] = []
    @State private var enabled: Set<String> = []
    @State private var state: ViewState = .idle
    @State private var isSyncing = false

    enum ViewState: Equatable {
        case idle, requesting, granted, denied
    }

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .idle, .requesting: requestingView
                case .denied: deniedView
                case .granted: calendarList
                }
            }
            .navigationTitle("Apple Calendars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
            Text("Calendar access denied").font(AppType.bodyMedium)
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
            Section {
                ForEach(calendars) { cal in
                    Toggle(isOn: Binding(
                        get: { enabled.contains(cal.id) },
                        set: { newValue in toggle(cal, on: newValue) }
                    )) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: cal.colorHex))
                                .frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(cal.title).foregroundStyle(AppColors.primary)
                                Text(cal.sourceTitle)
                                    .font(AppType.caption)
                                    .foregroundStyle(AppColors.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Show in Events")
            } footer: {
                Text("Toggle a calendar on to pull its events into the Events tab (365 days). Toggle off to remove them.")
            }
        }
        .overlay(alignment: .bottom) {
            if isSyncing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Syncing…").font(AppType.caption)
                }
                .padding(10)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 20)
            }
        }
    }

    private func toggle(_ cal: ImportableCalendar, on: Bool) {
        if on { enabled.insert(cal.id) } else { enabled.remove(cal.id) }
        CalendarToggleStore.set(cal.id, enabled: on)
        Task { await runSync(for: cal, enabled: on) }
    }

    private func runSync(for cal: ImportableCalendar, enabled: Bool) async {
        isSyncing = true
        let importer = CalendarImporter(context: modelContext)
        if enabled {
            _ = importer.syncCalendars(ids: [cal.id])
        } else {
            importer.removeEvents(forCalendarID: cal.id)
        }
        isSyncing = false
    }

    private func requestAndLoad() async {
        state = .requesting
        let importer = CalendarImporter(context: modelContext)
        do {
            let granted = try await importer.requestAccess()
            if granted {
                calendars = importer.availableCalendars().sorted { $0.title < $1.title }
                enabled = CalendarToggleStore.enabledIDs
                state = .granted
            } else {
                state = .denied
            }
        } catch {
            state = .denied
        }
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
