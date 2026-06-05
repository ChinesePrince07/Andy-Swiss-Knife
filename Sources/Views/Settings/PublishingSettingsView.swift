import SwiftUI

struct PublishingSettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    @State private var baseURL: String = SiteAuth.shared.baseURL
    @State private var secret: String = SiteAuth.shared.secret
    @State private var verifying = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    var body: some View {
        _ = themeManager.current
        return ZStack {
            ThemedBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Publishing")
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .kerning(1.4)
                        .foregroundStyle(AppColors.primary)
                        .padding(.top, 4)

                    explainerBlock

                    fieldBlock(label: "Site URL") {
                        TextField("https://andypandy.org", text: $baseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .keyboardType(.URL)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(AppColors.primary)
                    }

                    fieldBlock(label: "Publish secret") {
                        SecureField("ADMIN_PASSWORD / PUBLISH_SECRET", text: $secret)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(AppColors.primary)
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(statusIsError ? Color.red : AppColors.accent)
                    }

                    saveButton
                    if SiteAuth.shared.isAuthed {
                        clearButton
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var explainerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HOW IT WORKS")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .kerning(1.2)
                .foregroundStyle(AppColors.tertiary)
            HairlineDivider()
            Text("Stored locally in iOS Keychain. Sent only to the URL above as a Bearer token. Use the same value as `ADMIN_PASSWORD` on Vercel.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColors.secondary)
        }
    }

    @ViewBuilder
    private func fieldBlock<C: View>(label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .kerning(1.2)
                .foregroundStyle(AppColors.tertiary)
            HairlineDivider()
            content()
                .padding(.horizontal, 10).padding(.vertical, 10)
                .overlay(Rectangle().strokeBorder(AppColors.primary, lineWidth: 1.5))
        }
    }

    private var saveButton: some View {
        Button {
            Task { await saveAndVerify() }
        } label: {
            HStack {
                Text(verifying ? "VERIFYING..." : "SAVE & VERIFY")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(AppColors.surface)
                if verifying {
                    Spacer()
                    ProgressView().tint(AppColors.surface)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppColors.primary)
        }
        .buttonStyle(.plain)
        .disabled(verifying || trimmedBase.isEmpty || trimmedSecret.isEmpty)
    }

    private var clearButton: some View {
        Button {
            SiteAuth.shared.clear()
            secret = ""
            statusMessage = "Cleared."
            statusIsError = false
        } label: {
            Text("CLEAR SECRET")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .overlay(Rectangle().strokeBorder(Color.red, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var trimmedBase: String { baseURL.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedSecret: String { secret.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func saveAndVerify() async {
        verifying = true
        statusMessage = nil
        SiteAuth.shared.baseURL = trimmedBase
        SiteAuth.shared.secret = trimmedSecret
        do {
            try await SiteClient.shared.verifyCredentials()
            statusIsError = false
            statusMessage = "Verified ◆ logged in."
        } catch {
            statusIsError = true
            statusMessage = error.localizedDescription
        }
        verifying = false
    }
}
