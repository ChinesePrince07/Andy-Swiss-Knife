import SwiftUI

struct ReminderRow: View {
    @Bindable var event: PersonalEvent
    let onOpen: () -> Void
    let onDelete: () -> Void
    let onCommitTitle: (String) -> Void

    @State private var titleDraft: String = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button { onOpen() } label: {
                Text(timeLabel)
                    .font(AppType.caption)
                    .foregroundStyle(AppColors.secondary)
                    .frame(width: 78, alignment: .leading)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                TextField("", text: $titleDraft)
                    .font(AppType.bodyMedium)
                    .foregroundStyle(AppColors.primary)
                    .focused($titleFocused)
                    .submitLabel(.done)
                    .onSubmit { commit() }
                    .onChange(of: titleFocused) { _, focused in
                        if !focused { commit() }
                    }
                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(AppType.caption)
                        .foregroundStyle(AppColors.secondary)
                        .lineLimit(1)
                        .onTapGesture { onOpen() }
                }
            }

            Button { onDelete() } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .onAppear { titleDraft = event.title }
        .onChange(of: event.title) { _, new in
            if !titleFocused { titleDraft = new }
        }
    }

    private var timeLabel: String {
        if event.isAllDay { return "All day" }
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        return df.string(from: event.date)
    }

    private func commit() {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            titleDraft = event.title
            return
        }
        if trimmed != event.title {
            onCommitTitle(trimmed)
        }
    }
}
