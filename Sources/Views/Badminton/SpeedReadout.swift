import SwiftUI

/// The LAST / MAX shot-speed panel, formatted in the user's chosen unit.
struct SpeedReadout: View {
    let last: ShotSpeed?
    let max: ShotSpeed?
    let settings: BadmintonSettings

    var body: some View {
        HStack(spacing: 14) {
            field("LAST", last)
            field("MAX", max)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
    }

    @ViewBuilder private func field(_ label: String, _ speed: ShotSpeed?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            Text(speed.map { settings.display($0) } ?? "—")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppColors.accent)
        }
    }
}
