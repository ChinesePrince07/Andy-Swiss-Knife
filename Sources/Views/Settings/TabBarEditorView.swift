import SwiftUI

struct TabBarEditorView: View {
    @State private var enabledTabs: [AppTab] = UserSettings.shared.enabledTabs
    @State private var editMode: EditMode = .active
    @Environment(ThemeManager.self) private var themeManager

    private var disabledTabs: [AppTab] {
        AppTab.allCases.filter { !enabledTabs.contains($0) }
    }

    var body: some View {
        _ = themeManager.current
        return List {
            Section {
                if enabledTabs.isEmpty {
                    Text("No tabs visible. Add at least one.")
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.secondary)
                } else {
                    ForEach(enabledTabs) { tab in
                        tabRow(tab, isEnabled: true)
                    }
                    .onMove { from, to in
                        enabledTabs.move(fromOffsets: from, toOffset: to)
                        save()
                    }
                    .onDelete { offsets in
                        // Prevent removing last tab
                        guard enabledTabs.count - offsets.count >= 1 else { return }
                        enabledTabs.remove(atOffsets: offsets)
                        save()
                    }
                }
            } header: {
                Text("VISIBLE TABS")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.0)
            } footer: {
                Text("Drag to reorder. Swipe to hide.")
                    .font(AppType.caption)
            }

            Section {
                if disabledTabs.isEmpty {
                    Text("All tabs visible.")
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.secondary)
                } else {
                    ForEach(disabledTabs) { tab in
                        tabRow(tab, isEnabled: false)
                    }
                }
            } header: {
                Text("HIDDEN TABS")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .kerning(1.0)
            } footer: {
                Text("Tap + to add back.")
                    .font(AppType.caption)
            }

            Section {
                Button("Reset to default", role: .destructive) {
                    enabledTabs = AppTab.allDefault
                    save()
                }
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("TAB BAR")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func tabRow(_ tab: AppTab, isEnabled: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tab.filledIcon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isEnabled ? AppColors.primary : AppColors.tertiary)
                .frame(width: 24)
            Text(tab.label)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .kerning(1.0)
                .foregroundStyle(isEnabled ? AppColors.primary : AppColors.tertiary)
            Spacer()
            if !isEnabled {
                Button {
                    enabledTabs.append(tab)
                    save()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppColors.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    private func save() {
        UserSettings.shared.enabledTabs = enabledTabs
    }
}
