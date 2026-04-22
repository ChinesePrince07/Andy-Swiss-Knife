import SwiftUI

struct DashboardLayoutEditor: View {
    @Bindable private var layout = DashboardLayout.shared
    @State private var editMode: EditMode = .active

    var body: some View {
        List {
            Section {
                if layout.active.isEmpty {
                    Text("No active cards. Drag from below to activate.")
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.secondary)
                } else {
                    ForEach(layout.active, id: \.self) { card in
                        row(card, isActive: true)
                    }
                    .onMove { from, to in layout.move(from: from, to: to) }
                    .onDelete { offsets in
                        for idx in offsets {
                            if layout.active.indices.contains(idx) {
                                layout.deactivate(layout.active[idx])
                            }
                        }
                    }
                }
            } header: {
                Text("Active on dashboard")
            } footer: {
                Text("Drag handle reorders. Swipe or minus button hides the card.")
            }

            Section {
                if layout.inactive.isEmpty {
                    Text("All cards active.")
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.secondary)
                } else {
                    ForEach(layout.inactive, id: \.self) { card in
                        row(card, isActive: false)
                    }
                }
            } header: {
                Text("Hidden")
            } footer: {
                Text("Tap the plus button to add a hidden card back to the dashboard.")
            }

            Section {
                Button("Reset to default", role: .destructive) {
                    layout.resetDefault()
                }
            }
        }
        .navigationTitle("Customize dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
    }

    private func row(_ card: DashboardCard, isActive: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: card.iconName)
                .font(.system(size: 15))
                .foregroundStyle(isActive ? AppColors.primary : AppColors.tertiary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(card.label)
                    .font(AppType.body)
                    .foregroundStyle(isActive ? AppColors.primary : AppColors.secondary)
                if !isActive {
                    Text("Inactive")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .kerning(1.0)
                        .foregroundStyle(AppColors.tertiary)
                }
            }
            Spacer()
            if isActive {
                Button {
                    layout.deactivate(card)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(AppColors.accent)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    layout.activate(card)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppColors.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
