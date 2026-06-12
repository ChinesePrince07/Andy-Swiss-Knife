import SwiftUI
import SwiftData

struct OnboardingView: View {
    let onFinish: () -> Void
    let modelContext: ModelContext

    @Environment(ThemeManager.self) private var themeManager
    @State private var step: Int = 0
    @State private var name: String = ""
    @State private var canvasURL: String = ""
    @State private var eventsURL: String = ""

    private let totalSteps = 5

    var body: some View {
        _ = themeManager.current
        return ZStack {
            ThemedBackground()

            VStack(spacing: 0) {
                header
                HairlineDivider()
                progressBar
                HairlineDivider()

                ScrollView {
                    Group {
                        switch step {
                        case 0: welcomeStep
                        case 1: nameStep
                        case 2: scheduleStep
                        case 3: canvasStep
                        case 4: eventsStep
                        default: doneStep
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 24)
                }

                HairlineDivider()
                footer
            }
        }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack {
            Text("SETUP")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .kerning(1.4)
                .foregroundStyle(AppColors.primary)
            Spacer()
            Button { finish() } label: {
                Text("SKIP ALL")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .kerning(1.0)
                    .foregroundStyle(AppColors.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { idx in
                Rectangle()
                    .fill(idx <= step ? AppColors.primary : AppColors.hairline)
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack(spacing: 0) {
            if step > 0 {
                Button { withAnimation { step -= 1 } } label: {
                    Text("← BACK")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .kerning(1.2)
                        .foregroundStyle(AppColors.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button { advance() } label: {
                Text(rightButtonLabel)
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .kerning(1.2)
                    .foregroundStyle(AppColors.surface)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(AppColors.primary)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
        }
        .padding(.vertical, 6)
    }

    private var rightButtonLabel: String {
        if step >= totalSteps { return "FINISH" }
        let trimmed: String
        switch step {
        case 1: trimmed = name.trimmingCharacters(in: .whitespaces)
        case 3: trimmed = canvasURL.trimmingCharacters(in: .whitespaces)
        case 4: trimmed = eventsURL.trimmingCharacters(in: .whitespaces)
        default: return step == 2 ? "SKIP" : "NEXT"
        }
        return trimmed.isEmpty ? "SKIP" : "NEXT"
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            logoMark
                .padding(.bottom, 4)

            Text("One app for school. Schedule, assignments, athletics, study documents.")
                .font(AppType.body)
                .foregroundStyle(AppColors.secondary)

            Text("This quick setup is optional — you can skip any step and fill it in later from Settings.")
                .font(AppType.caption)
                .foregroundStyle(AppColors.tertiary)
        }
    }

    private var logoMark: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.primary)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text("SWISS")
                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                    .kerning(2.0)
                    .foregroundStyle(AppColors.primary)
                Text("KNIFE")
                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                    .kerning(2.0)
                    .foregroundStyle(AppColors.primary)
                Text("◆ FOR SCHOOL")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .kerning(1.4)
                    .foregroundStyle(AppColors.accent)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(AppColors.surface)
        .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 2))
        .fixedSize()
    }

    private var nameStep: some View {
        stepFrame(title: "WHAT'S YOUR NAME?", subtitle: "Used in the dashboard greeting.") {
            TextField("First name", text: $name)
                .font(AppType.body)
                .foregroundStyle(AppColors.primary)
                .padding(14)
                .background(AppColors.surface)
                .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
        }
    }

    private var scheduleStep: some View {
        stepFrame(title: "CLASS SCHEDULE", subtitle: "Pick a starting point. Edit anytime in Settings → Schedule.") {
            VStack(spacing: 10) {
                bigChoiceButton(label: "USE SUFFIELD DEFAULT", caption: "7 lettered periods, rotating") {
                    Services.seedSuffieldSchedule(context: modelContext)
                    advance()
                }
                bigChoiceButton(label: "IMPORT LATER", caption: "Photo or PDF, from Settings") {
                    advance()
                }
                bigChoiceButton(label: "START BLANK", caption: "Add periods manually later") {
                    advance()
                }
            }
        }
    }

    private var canvasStep: some View {
        stepFrame(title: "CANVAS CALENDAR FEED", subtitle: "Canvas → Calendar → sidebar → Calendar Feed → copy URL.") {
            TextField("https://…/feeds/calendars/...", text: $canvasURL)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(AppColors.primary)
                .padding(14)
                .background(AppColors.surface)
                .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
        }
    }

    private var eventsStep: some View {
        stepFrame(title: "SCHOOL EVENTS FEED", subtitle: "Paste your school's public calendar ICS URL. Optional.") {
            TextField("https://…/calendar.ics", text: $eventsURL)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(AppColors.primary)
                .padding(14)
                .background(AppColors.surface)
                .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
        }
    }

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("ALL SET ◆")
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .kerning(2.0)
                .foregroundStyle(AppColors.primary)

            Text("Pick athletics teams and school countdown events anytime from Settings.")
                .font(AppType.body)
                .foregroundStyle(AppColors.secondary)

            Text("Tap FINISH to start.")
                .font(AppType.caption)
                .foregroundStyle(AppColors.tertiary)
                .padding(.top, 8)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func stepFrame<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                .kerning(1.4)
                .foregroundStyle(AppColors.primary)
            Text(subtitle)
                .font(AppType.caption)
                .foregroundStyle(AppColors.secondary)
            content()
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func bigChoiceButton(label: String, caption: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .kerning(1.0)
                        .foregroundStyle(AppColors.primary)
                    Text(caption)
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.tertiary)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background(AppColors.surface)
            .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func advance() {
        let s = name.trimmingCharacters(in: .whitespaces)
        let c = canvasURL.trimmingCharacters(in: .whitespaces)
        let e = eventsURL.trimmingCharacters(in: .whitespaces)
        switch step {
        case 1: if !s.isEmpty { UserSettings.shared.displayName = s }
        case 3: if !c.isEmpty { UserSettings.shared.canvasFeedURL = c }
        case 4: if !e.isEmpty { UserSettings.shared.eventsICSURL = e }
        default: break
        }

        if step >= totalSteps {
            finish()
        } else {
            withAnimation { step += 1 }
        }
    }

    private func finish() {
        UserSettings.shared.hasCompletedOnboarding = true
        onFinish()
    }
}
