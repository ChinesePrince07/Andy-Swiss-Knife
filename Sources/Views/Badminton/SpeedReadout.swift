import SwiftUI

/// The LAST / MAX shot-speed panel, formatted in the user's chosen unit.
struct SpeedReadout: View {
    let last: ShotSpeed?
    let max: ShotSpeed?
    let settings: BadmintonSettings

    var body: some View {
        HStack(spacing: 16) {
            field("LAST", last)
            field("MAX", max)
        }
        .padding(10)
        .background(Color.black.opacity(0.6))
    }

    @ViewBuilder private func field(_ label: String, _ speed: ShotSpeed?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(AppType.tiny).foregroundStyle(.white.opacity(0.7))
            Text(speed.map { settings.display($0) } ?? "—")
                .font(AppType.mono).foregroundStyle(AppColors.accent)
        }
    }
}
