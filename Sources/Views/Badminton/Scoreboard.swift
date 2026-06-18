import SwiftUI

/// Two-counter scoreboard for the experimental auto-scorer. Auto detection drives
/// the counts; the `+/−` buttons are first-class because auto is unreliable.
struct Scoreboard: View {
    let p1: Int
    let p2: Int
    let onAdjust: (PlayerSide, Int) -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            side("P1", score: p1, color: .green, which: .p1)
            Text("—")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            side("P2", score: p2, color: .cyan, which: .p2)
            Spacer(minLength: 8)
            Button("RESET", action: onReset)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
    }

    private func side(_ label: String, score: Int, color: Color, which: PlayerSide) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(color)
            stepper("minus.circle") { onAdjust(which, -1) }
            Text("\(score)")
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
                .frame(minWidth: 22)
                .monospacedDigit()
            stepper("plus.circle") { onAdjust(which, +1) }
        }
    }

    private func stepper(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.85))
        }
        .buttonStyle(.plain)
    }
}
