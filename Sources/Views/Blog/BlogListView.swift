import SwiftUI

struct BlogListView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var posts: [BlogPostSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var search = ""
    @State private var showingNew = false

    private var auth = SiteAuth.shared

    var body: some View {
        _ = themeManager.current
        return Group {
            if !SiteAuth.shared.isAuthed {
                lockedView
            } else {
                authedBody
            }
        }
        .background(AppColors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if SiteAuth.shared.isAuthed, posts.isEmpty {
                await refresh()
            }
        }
        .sheet(isPresented: $showingNew, onDismiss: {
            Task { await refresh() }
        }) {
            NavigationStack {
                BlogNewView { _ in showingNew = false }
            }
        }
    }

    private var authedBody: some View {
        VStack(spacing: 0) {
            header
            searchBar
            content
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Rectangle().fill(AppColors.primary).frame(width: 3, height: 16)
            Text("BLOG")
                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                .kerning(1.4)
                .foregroundStyle(AppColors.primary)
            Spacer()
            Button { showingNew = true } label: {
                Text("+ NEW")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .kerning(1.0)
                    .foregroundStyle(AppColors.surface)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(AppColors.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) { HairlineDivider() }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.tertiary)
            TextField("Search posts...", text: $search)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(AppColors.primary)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(AppColors.surface)
        .overlay(Rectangle().strokeBorder(AppColors.hairline, lineWidth: 1))
        .padding(.horizontal, 16).padding(.vertical, 6)
        .overlay(alignment: .bottom) { HairlineDivider() }
    }

    private var content: some View {
        Group {
            if isLoading && posts.isEmpty {
                ProgressView()
                    .tint(AppColors.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                errorView(errorMessage)
            } else if filtered.isEmpty {
                emptyState
            } else {
                postList
            }
        }
    }

    private var postList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filtered) { post in
                    NavigationLink {
                        BlogEditView(slug: post.slug, onSaved: { Task { await refresh() } }, onDeleted: { Task { await refresh() } })
                    } label: {
                        BlogPostRow(post: post)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .refreshable { await refresh() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("NO POSTS YET")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .kerning(1.2)
                .foregroundStyle(AppColors.tertiary)
            Text("Tap + NEW to write your first one.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColors.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("LOAD FAILED")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .kerning(1.2)
                .foregroundStyle(Color.red)
            Text(message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppColors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button { Task { await refresh() } } label: {
                Text("RETRY")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(AppColors.surface)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(AppColors.primary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var lockedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 28))
                .foregroundStyle(AppColors.primary)
            Text("LINK YOUR SITE")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .kerning(1.4)
                .foregroundStyle(AppColors.primary)
            Text("Add your publish secret in Settings → Publishing to start editing posts.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppColors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            NavigationLink {
                PublishingSettingsView()
            } label: {
                Text("OPEN PUBLISHING SETTINGS →")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .kerning(1.0)
                    .foregroundStyle(AppColors.surface)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(AppColors.primary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filtered: [BlogPostSummary] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return posts }
        return posts.filter { p in
            p.title.lowercased().contains(q) ||
            p.description.lowercased().contains(q) ||
            p.slug.lowercased().contains(q)
        }
    }

    private func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            posts = try await SiteClient.shared.listPosts()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct BlogPostRow: View {
    let post: BlogPostSummary

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if post.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(AppColors.accent)
                    }
                    Text(post.title)
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(AppColors.primary)
                        .lineLimit(1)
                }
                Text(subtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppColors.tertiary)
                    .lineLimit(1)
                if !post.description.isEmpty {
                    Text(post.description)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AppColors.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.tertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .overlay(alignment: .bottom) { HairlineDivider() }
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts: [String] = []
        if !post.date.isEmpty { parts.append(post.date.prefix(10).description) }
        parts.append(post.slug)
        return parts.joined(separator: " · ")
    }
}
