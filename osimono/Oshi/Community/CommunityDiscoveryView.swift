import SwiftUI

struct CommunityDiscoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = CommunityDiscoveryModel()
    @State private var search = ""
    @State private var category = ""
    @State private var selected: CommunityOshi?
    @State private var didRegister = false
    var onRegistered: () -> Void

    private var queryID: String { category + "|" + search }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(communityText("気になる推しと、\n新しい会話を。", "Meet someone new."))
                            .font(.largeTitle.bold())
                        Text(communityText("みんなが公開した推しを、あなたの一覧に。", "Add a community character to your own collection."))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.top, 8)
                    categoryPicker
                    HStack {
                        Text(search.isEmpty ? communityText("新しく公開された推し", "New characters") : communityText("検索結果", "Search results"))
                            .font(.headline)
                        Spacer()
                        if model.isLoading && !model.profiles.isEmpty { ProgressView() }
                    }
                    if model.isLoading && model.profiles.isEmpty {
                        ProgressView(communityText("推しを探しています…", "Finding characters…"))
                            .frame(maxWidth: .infinity).padding(40)
                    } else if model.profiles.isEmpty && model.errorMessage == nil {
                        emptyState
                    }
                    LazyVStack(spacing: 14) {
                        ForEach(model.profiles) { profile in
                            Button { selected = profile } label: { CommunityProfileCard(profile: profile) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("community.profile.\(profile.id)")
                        }
                    }
                    if let error = model.errorMessage {
                        VStack(spacing: 12) {
                            Text(error).font(.subheadline).foregroundStyle(.secondary)
                            Button(communityText("もう一度読み込む", "Try again")) {
                                Task { await reload(reset: model.profiles.isEmpty) }
                            }.buttonStyle(.bordered)
                        }.frame(maxWidth: .infinity).padding()
                    } else if model.hasMore {
                        Button(communityText("もっと見る", "Load more")) { Task { await reload(reset: false) } }
                            .buttonStyle(.bordered).frame(maxWidth: .infinity).disabled(model.isLoading)
                    }
                }.padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(communityText("みんなの推し", "Discover characters"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: communityText("推しの名前（先頭から検索）", "Search by name prefix"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(communityText("閉じる", "Close")) { dismiss() } } }
            .task(id: queryID) {
                do { try await Task.sleep(nanoseconds: 300_000_000) } catch { return }
                await reload(reset: true)
            }
            .refreshable { await reload(reset: true) }
            .sheet(item: $selected, onDismiss: {
                if didRegister { onRegistered(); dismiss() }
            }) { profile in
                CommunityDetailView(profile: profile, onRegistered: { didRegister = true }, onHidden: { model.remove(profile.id) })
            }
        }.tint(.pink)
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryButton("", communityText("すべて", "All"))
                ForEach(CommunityCategory.allCases) { categoryButton($0.rawValue, $0.title) }
            }
        }
    }
    private func categoryButton(_ value: String, _ title: String) -> some View {
        Button { category = value } label: {
            Text(title).font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(category == value ? Color.pink : Color(.secondarySystemGroupedBackground), in: Capsule())
                .foregroundStyle(category == value ? .white : .primary)
        }.buttonStyle(.plain).accessibilityAddTraits(category == value ? .isSelected : [])
    }
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkle.magnifyingglass").font(.system(size: 40)).foregroundStyle(.pink)
            Text(communityText("推しが見つかりませんでした", "No characters found")).font(.headline)
            Text(communityText("名前やカテゴリを変えて探してみてください。自分の推しは編集画面から公開できます。", "Try another name or category. You can publish your own character from its edit screen."))
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 30)
    }
    private func reload(reset: Bool) async {
        await model.load(search: String(search.prefix(60)), category: category, reset: reset)
    }
}

struct CommunityAvatar: View {
    let name: String
    let imageUrl: String?
    var size: CGFloat = 76
    var body: some View {
        ZStack {
            LinearGradient(colors: [.pink.opacity(0.18), .purple.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(String(name.prefix(1))).font(.system(size: size * 0.36, weight: .semibold)).foregroundStyle(.pink)
            if let imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
            }
        }.frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.26)).accessibilityHidden(true)
    }
}

struct CommunityProfileCard: View {
    let profile: CommunityOshi
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            CommunityAvatar(name: profile.name, imageUrl: profile.imageUrl)
            VStack(alignment: .leading, spacing: 7) {
                Text(profile.name).font(.title3.bold()).foregroundStyle(.primary)
                Text(communityText("作成：", "By ") + profile.creatorName).font(.caption).foregroundStyle(.secondary)
                Text(profile.introduction).font(.subheadline).foregroundStyle(.primary).lineLimit(3)
                Text(([CommunityCategory(rawValue: profile.category)?.title].compactMap { $0 } + profile.tags).map { "#" + $0 }.joined(separator: "  "))
                    .font(.caption).foregroundStyle(.pink).lineLimit(2)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary).padding(.top, 5)
        }.padding(16).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}

struct CommunityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let profile: CommunityOshi
    let onRegistered: () -> Void
    let onHidden: () -> Void
    @State private var fresh: CommunityOshi?
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var isExisting = false
    @State private var isRegistered = false
    @State private var errorMessage: String?
    @State private var showReport = false
    @ObservedObject private var subscription = SubscriptionManager.shared
    private let service = CommunityOshiService()
    private var displayed: CommunityOshi { fresh ?? profile }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(spacing: 12) {
                        CommunityAvatar(name: displayed.name, imageUrl: displayed.imageUrl, size: 112)
                        Text(displayed.name).font(.title.bold())
                        Text(communityText("作成：", "By ") + displayed.creatorName).foregroundStyle(.secondary)
                        Text(displayed.introduction).font(.body).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity)
                    if !displayed.sampleLine.isEmpty {
                        info(communityText("こんなふうに話します", "A little preview"), displayed.sampleLine, icon: "quote.bubble")
                    }
                    info(communityText("性格", "Personality"), displayed.personality, icon: "sparkles")
                    info(communityText("話し方", "Speaking style"), displayed.speakingStyle, icon: "text.bubble")
                    info(communityText("口癖", "Catchphrase"), displayed.signaturePhrase, icon: "quote.opening")
                    Text(communityText("登録すると、あなた専用の推しになります。性格や話し方はあとから編集でき、会話はあなたと推しだけのものです。", "Adding creates your own character. You can edit its personality and speaking style. Your conversations stay separate."))
                        .font(.footnote).foregroundStyle(.secondary)
                    if let errorMessage {
                        Text(errorMessage).font(.subheadline).foregroundStyle(.red)
                        if fresh == nil { Button(communityText("再試行", "Retry")) { Task { await load() } } }
                    }
                }.padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) { registrationButton.padding().background(.regularMaterial) }
            .navigationTitle(communityText("推しのプロフィール", "Character profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(communityText("閉じる", "Close")) { dismiss() }.disabled(isWorking) }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { Task { await hide() } } label: { Label(communityText("この推しを非表示", "Hide character"), systemImage: "eye.slash") }
                        Button(role: .destructive) { showReport = true } label: { Label(communityText("通報して非表示", "Report and hide"), systemImage: "flag") }
                    } label: { Image(systemName: "ellipsis.circle").accessibilityLabel(communityText("その他の操作", "More actions")) }
                    .disabled(isLoading || isWorking || isRegistered)
                }
            }
            .confirmationDialog(communityText("通報する理由を選択", "Choose a report reason"), isPresented: $showReport, titleVisibility: .visible) {
                reportButton("不適切な内容", "Inappropriate content", "inappropriate")
                reportButton("権利の侵害・なりすまし", "Rights violation or impersonation", "rights")
                reportButton("個人情報が含まれる", "Personal information", "privacy")
                reportButton("その他", "Other", "other")
            } message: { Text(communityText("運営に送信し、この推しをあなたの検索結果から非表示にします。", "The report goes to the moderation team and hides this character from your results.")) }
            .task { await load() }
        }.tint(.pink).interactiveDismissDisabled(isWorking)
    }

    private var registrationButton: some View {
        Button {
            if isRegistered { dismiss() } else { Task { await register() } }
        } label: {
            HStack {
                if isLoading || isWorking { ProgressView().tint(.white) }
                Image(systemName: isRegistered || isExisting ? "checkmark.circle.fill" : "heart.badge.plus")
                Text(isRegistered ? communityText("登録完了 · チャット一覧へ", "Added · Back to chats") : isExisting ? communityText("登録済みの推しを選択", "Select your added character") : communityText("自分の推しに登録", "Add to my characters"))
                    .fontWeight(.semibold)
            }.frame(maxWidth: .infinity).padding(.vertical, 12)
        }.buttonStyle(.borderedProminent).disabled(isLoading || isWorking || fresh == nil)
            .accessibilityIdentifier("community.register")
    }
    @ViewBuilder private func info(_ title: String, _ value: String, icon: String) -> some View {
        if !value.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: icon).font(.headline).foregroundStyle(.pink)
                Text(value).font(.body).textSelection(.enabled)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        }
    }
    private func reportButton(_ ja: String, _ en: String, _ reason: String) -> some View {
        Button(communityText(ja, en), role: .destructive) { Task { await hide(reason: reason) } }
    }
    private func load() async {
        isLoading = true; errorMessage = nil
        do {
            async let latest = service.detail(profile.id)
            async let records = service.registrations()
            let (result, saved) = try await (latest, records)
            fresh = result
            isExisting = CommunityRegistration.existingID(records: saved, profile: result) != nil
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
    private func register() async {
        guard !isWorking else { return }
        isWorking = true; errorMessage = nil
        do {
            _ = try await service.register(displayed, limit: OshiLimitManager.shared.getOshiLimit(isSubscribed: subscription.isSubscribed))
            TutorialManager.shared.oshiDidBecomeAvailable()
            isRegistered = true; onRegistered()
        } catch { errorMessage = error.localizedDescription }
        isWorking = false
    }
    private func hide(reason: String? = nil) async {
        isWorking = true; errorMessage = nil
        do {
            var data: [String: Any] = ["id": profile.id]
            if let reason { data["reason"] = reason }
            _ = try await service.call(reason == nil ? "hide" : "report", data)
            onHidden(); dismiss()
        } catch { errorMessage = error.localizedDescription }
        isWorking = false
    }
}

struct CommunityDiscoveryEntry: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "sparkle.magnifyingglass").font(.title).foregroundStyle(.pink)
                VStack(alignment: .leading, spacing: 4) {
                    Text(communityText("みんなの推しから選ぶ", "Discover community characters")).font(.headline)
                    Text(communityText("プロフィールを見て、自分の推しに登録", "Find a character and add it to your collection"))
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.pink)
            }.padding(18).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.pink.opacity(0.2)))
        }.buttonStyle(.plain).accessibilityIdentifier("community.discover")
    }
}
