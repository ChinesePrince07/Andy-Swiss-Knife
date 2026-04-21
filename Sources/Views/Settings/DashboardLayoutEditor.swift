import SwiftUI

struct DashboardLayoutEditor: View {
    @Bindable private var layout = DashboardLayout.shared

    var body: some View {
        List {
            Section {
                ForEach(layout.order, id: \.self) { card in
                    HStack(spacing: 12) {
                        Image(systemName: card.iconName)
                            .font(.system(size: 15))
                            .foregroundStyle(AppColors.primary)
                            .frame(width: 22)
                        Text(card.label)
                            .font(AppType.body)
                            .foregroundStyle(AppColors.primary)
                        Spacer()
                    }
                }
                .onMove { from, to in layout.move(from: from, to: to) }
            } header: {
                Text("Drag to reorder")
            } footer: {
                Text("This sets the order of the glance grid on the Today dashboard.")
            }

            Section {
                Button("Reset to default order", role: .destructive) {
                    layout.resetDefault()
                }
            }
        }
        .navigationTitle("Customize dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .environment(\.editMode, .constant(.active))
    }
}
