import SwiftUI
import PhotosUI

struct ChatAppearanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var store: ChatAppearanceStore = .shared
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var showPhotoError = false
    @State private var showResetConfirmation = false
    @ScaledMetric(relativeTo: .body) private var fontSampleSize: CGFloat = 17

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    preview
                        .listRowInsets(EdgeInsets())
                } header: {
                    Text("chat_appearance_preview")
                } footer: {
                    Text("chat_appearance_scope")
                }
                backgroundSection
                fontSection
                Section {
                    Button("chat_appearance_reset", role: .destructive) { showResetConfirmation = true }
                        .disabled(isLoadingPhoto)
                }
            }
            .tint(.pink)
            .navigationTitle("chat_appearance_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { dismiss() }
                }
            }
            .confirmationDialog("chat_appearance_reset_confirm", isPresented: $showResetConfirmation, titleVisibility: .visible) {
                Button("chat_appearance_reset", role: .destructive) {
                    do { try store.reset() } catch { showPhotoError = true }
                }
                Button(L10n.cancel, role: .cancel) { }
            }
            .alert("chat_appearance_photo_error", isPresented: $showPhotoError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("chat_appearance_photo_error_message")
            }
            .task(id: selectedPhoto) {
                guard let item = selectedPhoto else { return }
                isLoadingPhoto = true
                defer { isLoadingPhoto = false; selectedPhoto = nil }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    let prepared = try await Task.detached(priority: .userInitiated) {
                        try ChatBackgroundPhoto.prepare(data)
                    }.value
                    try Task.checkCancellation()
                    try store.savePhoto(prepared)
                } catch is CancellationError {
                    // Dismissing the sheet cancels an in-flight import.
                } catch {
                    if !Task.isCancelled { showPhotoError = true }
                }
            }
        }
    }

    private var backgroundSection: some View {
        Section("chat_appearance_background") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 85), spacing: 12)], spacing: 12) {
                ForEach(ChatBackgroundTheme.allCases.filter { $0 != .photo }) { theme in
                    Button { store.setBackground(theme) } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: theme.colors(for: colorScheme), startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(height: 54)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(store.settings.background == theme ? Color.pink : Color.secondary.opacity(0.25), lineWidth: store.settings.background == theme ? 2 : 1)
                                }
                                .overlay {
                                    if store.settings.background == theme {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.white, .pink)
                                    }
                                }
                            Text(theme.title).font(.caption).foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(theme.title)
                    .accessibilityAddTraits(store.settings.background == theme ? .isSelected : [])
                    .accessibilityIdentifier("chat.background.\(theme.rawValue)")
                }
            }
            .padding(.vertical, 4)
            .disabled(isLoadingPhoto)

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                HStack {
                    Label(LocalizedStringKey(store.photo == nil ? "chat_appearance_choose_photo" : "chat_appearance_change_photo"), systemImage: "photo")
                    Spacer()
                    if isLoadingPhoto { ProgressView() }
                }
            }
            .disabled(isLoadingPhoto)
            .accessibilityIdentifier("chat.background.choosePhoto")

            if store.photo != nil {
                Button { store.setBackground(.photo) } label: {
                    HStack {
                        Text("chat_background_photo")
                        Spacer()
                        if store.settings.background == .photo { Image(systemName: "checkmark") }
                    }
                }
                .disabled(isLoadingPhoto)
                Button("chat_appearance_remove_photo", role: .destructive) {
                    do { try store.removePhoto() } catch { showPhotoError = true }
                }
                .disabled(isLoadingPhoto)
            }
        }
    }

    private var fontSection: some View {
        Section("chat_appearance_font") {
            ForEach(ChatFontStyle.allCases) { style in
                Button { store.setFont(style) } label: {
                    HStack {
                        Text(style.title)
                            .font(style.font(size: fontSampleSize))
                            .foregroundStyle(.primary)
                        Spacer()
                        if store.settings.fontStyle == style {
                            Image(systemName: "checkmark").foregroundStyle(.pink)
                        }
                    }
                }
                .accessibilityAddTraits(store.settings.fontStyle == style ? .isSelected : [])
                .accessibilityIdentifier("chat.font.\(style.rawValue)")
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("chat_appearance_font_size")
                    Spacer()
                    Text("\(Int(store.settings.fontSize)) pt").foregroundStyle(.secondary).monospacedDigit()
                }
                Slider(value: Binding(get: { store.settings.fontSize }, set: { store.setFontSize($0) }), in: 13...23, step: 1)
                    .accessibilityLabel(Text("chat_appearance_font_size"))
                    .accessibilityIdentifier("chat.font.size")
            }
            .padding(.vertical, 4)
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom, spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 30)).foregroundStyle(.pink)
                Text("chat_appearance_preview_reply")
                    .chatMessageFont()
                    .foregroundStyle(.primary)
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(ChatBubbleShape(isUser: false))
                Spacer(minLength: 20)
            }
            HStack {
                Spacer(minLength: 40)
                Text("chat_appearance_preview_user")
                    .chatMessageFont()
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(ChatBubbleShape(isUser: true))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ChatAppearanceBackground(theme: store.settings.background, photo: store.photo))
        .environment(\.chatAppearance, store.settings)
    }
}
