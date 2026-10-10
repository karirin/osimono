import SwiftUI

struct CommunityPublishView: View {
    @Environment(\.dismiss) private var dismiss
    let oshi: Oshi
    @State private var draft = CommunityPublicationDraft()
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var hasLoaded = false
    @State private var isPublished = false
    @State private var isDisabled = false
    @State private var importedCreator: String?
    @State private var sourceImageURL: String?
    @State private var consent = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var confirmUnpublish = false
    private let service = CommunityOshiService()

    var body: some View {
        NavigationStack {
            Form {
                if isLoading {
                    Section { ProgressView(communityText("保存済みの設定を読み込み中…", "Loading saved settings…")) }
                } else if let importedCreator {
                    Section(communityText("作成者", "Creator")) {
                        Label(importedCreator, systemImage: "person.crop.circle")
                        Text(communityText("みんなの推しから登録したキャラクターです。自分用の設定は自由に編集できます。再公開はできません。", "Added from the community. You can edit your personal copy, but it cannot be republished."))
                            .foregroundStyle(.secondary)
                    }
                } else if hasLoaded {
                    publicationForm
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                        if !hasLoaded { Button(communityText("再試行", "Retry")) { Task { await load() } } }
                    }
                }
                if let successMessage { Section { Label(successMessage, systemImage: "checkmark.circle.fill").foregroundStyle(.green) } }
            }
            .disabled(isWorking)
            .navigationTitle(communityText("公開・作成者情報", "Publishing & creator"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(communityText("閉じる", "Close")) { dismiss() }.disabled(isWorking) } }
            .overlay { if isWorking { ProgressView().padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
            .task { await load() }
            .confirmationDialog(communityText("この推しの公開を停止しますか？", "Unpublish this character?"), isPresented: $confirmUnpublish, titleVisibility: .visible) {
                Button(communityText("公開を停止", "Unpublish"), role: .destructive) { Task { await unpublish() } }
            } message: {
                Text(communityText("検索・新規登録ができなくなります。すでに他の人が登録した推しとその画像は残ります。", "It will no longer appear in discovery or accept new registrations. Existing personal copies and their images will remain."))
            }
        }.tint(.pink).interactiveDismissDisabled(isWorking)
    }

    @ViewBuilder private var publicationForm: some View {
        Section {
            Label(isPublished ? communityText("公開中", "Published") : communityText("非公開", "Private"), systemImage: isPublished ? "globe.asia.australia.fill" : "lock.fill")
                .foregroundStyle(isPublished ? .pink : .secondary)
            Text(communityText("公開するのは、この画面の内容だけです。会話履歴・メモ・呼び名・関係性・二人の思い出は共有しません。", "Only the contents of this screen are published. Chat history, notes, nicknames, relationships and shared memories remain private."))
                .font(.footnote).foregroundStyle(.secondary)
            if isDisabled { Text(communityText("運営により公開が停止されています。", "Publication has been disabled by moderation.")).foregroundStyle(.red) }
        }
        Section(communityText("公開プロフィール", "Public profile")) {
            field(communityText("推しの名前", "Name"), text: $draft.name, limit: 60)
            field(communityText("公開する作成者名", "Public creator name"), text: $draft.creatorName, limit: 40)
            field(communityText("紹介文", "Introduction"), text: $draft.introduction, limit: 240, multiline: true)
            Picker(communityText("カテゴリ", "Category"), selection: $draft.category) {
                ForEach(CommunityCategory.allCases) { Text($0.title).tag($0.rawValue) }
            }
            field(communityText("タグ（カンマ区切り・5個まで）", "Tags (comma-separated, up to 5)"), text: $draft.tagsText, limit: 104)
            if sourceImageURL != nil {
                Toggle(communityText("プロフィール画像も公開する", "Publish profile image"), isOn: $draft.includeImage)
            }
        }
        Section {
            field(communityText("性格", "Personality"), text: $draft.personality, limit: 1500, multiline: true)
            field(communityText("話し方", "Speaking style"), text: $draft.speakingStyle, limit: 1500, multiline: true)
            field(communityText("口癖", "Catchphrase"), text: $draft.signaturePhrase, limit: 200, multiline: true)
            field(communityText("会話サンプル", "Sample dialogue"), text: $draft.sampleLine, limit: 300, multiline: true)
        } header: { Text(communityText("登録する人に引き継ぐ設定", "Settings for personal copies")) }
        footer: { Text(communityText("保存済みの設定を元にしています。個人名や二人だけの情報が文章に入っていないか確認してください。会話サンプルは紹介用です。", "Based on your saved settings. Check that the text contains no personal names or private details. Sample dialogue is only a preview.")) }
        Section(communityText("一覧での表示プレビュー", "Discovery preview")) {
            CommunityProfileCard(profile: CommunityOshi(id: "preview", creatorID: "preview", creatorName: draft.creatorName,
                name: draft.name, introduction: draft.introduction, category: draft.category, tags: draft.tags,
                personality: draft.personality, speakingStyle: draft.speakingStyle, signaturePhrase: draft.signaturePhrase,
                sampleLine: draft.sampleLine, imageUrl: draft.includeImage ? sourceImageURL : nil, publishedAt: 0))
                .listRowInsets(EdgeInsets())
        }
        Section {
            Toggle(isOn: $consent) {
                Text(communityText("この内容と画像を公開・共有してよいことを確認しました。登録済みのコピーは公開停止後も残ります。", "I have permission to publish and share this content and image. Existing copies remain after unpublishing."))
                    .font(.footnote)
            }
            Button { Task { await publish() } } label: {
                Label(isPublished ? communityText("公開内容を更新", "Update publication") : communityText("みんなに公開する", "Publish to community"), systemImage: "globe.asia.australia")
            }.disabled(!consent || !draft.isValid || isDisabled)
                .accessibilityIdentifier("community.publish")
            if isPublished {
                Button(communityText("公開を停止する", "Unpublish"), role: .destructive) { confirmUnpublish = true }
            }
        } footer: {
            Text(communityText("公開内容の更新は、ほかの人が登録済みの設定には反映されません。", "Updates do not change settings in existing personal copies."))
        }
    }

    private func field(_ title: String, text: Binding<String>, limit: Int, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.medium))
            TextField(title, text: text, axis: multiline ? .vertical : .horizontal)
                .lineLimit(multiline ? 3...8 : 1...1)
            Text("\(text.wrappedValue.utf16.count)/\(limit)")
                .font(.caption2).foregroundStyle(text.wrappedValue.utf16.count > limit ? .red : .secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }.padding(.vertical, 4)
    }

    private func load() async {
        isLoading = true; errorMessage = nil
        do {
            let result = try await service.call("mine", ["oshiID": oshi.id])
            let data = result["draft"] as? [String: Any] ?? [:]
            draft.name = data["name"] as? String ?? ""
            draft.creatorName = data["creatorName"] as? String ?? ""
            draft.introduction = data["introduction"] as? String ?? ""
            draft.category = data["category"] as? String ?? CommunityCategory.gentle.rawValue
            draft.tagsText = (data["tags"] as? [String] ?? []).joined(separator: ", ")
            draft.personality = data["personality"] as? String ?? ""
            draft.speakingStyle = data["speakingStyle"] as? String ?? ""
            draft.signaturePhrase = data["signaturePhrase"] as? String ?? ""
            draft.sampleLine = data["sampleLine"] as? String ?? ""
            draft.includeImage = data["imageUrl"] is String
            sourceImageURL = result["imageUrl"] as? String
            isPublished = result["published"] as? Bool ?? false
            isDisabled = result["disabled"] as? Bool ?? false
            importedCreator = result["importedCreator"] as? String
            hasLoaded = true
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
    private func publish() async {
        isWorking = true; errorMessage = nil; successMessage = nil
        do {
            _ = try await service.call("publish", ["oshiID": oshi.id, "draft": draft.payload, "consent": consent])
            isPublished = true; consent = false
            successMessage = communityText("公開しました。「みんなの推し」に表示されます。", "Published. Others can now find your character.")
        } catch { errorMessage = error.localizedDescription }
        isWorking = false
    }
    private func unpublish() async {
        isWorking = true; errorMessage = nil; successMessage = nil
        do {
            _ = try await service.call("unpublish", ["oshiID": oshi.id])
            isPublished = false; consent = false
            successMessage = communityText("公開を停止しました。", "Unpublished.")
        } catch { errorMessage = error.localizedDescription }
        isWorking = false
    }
}
