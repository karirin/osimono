//
//  RoleplaySettingsView.swift
//  osimono
//
//  チャット画面から開くロールプレイ設定（シチュエーション / 追加キャラ設定 / 覚えていること）
//

import SwiftUI

private func rpText(_ key: String, _ value: String) -> String {
    Bundle.main.localizedString(forKey: key, value: value, table: nil)
}

struct RoleplaySettingsView: View {
    let oshi: Oshi
    var onSituationSaved: (RoleplaySituation) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    @State private var situation = RoleplaySituation()
    @State private var profile = RoleplayProfile()
    @State private var persona = RoleplayUserPersona()
    @State private var innerThoughtsEnabled = true
    @State private var loadedState: RoleplayState?
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var memories: [RoleplayMemory] = []
    @State private var isLoading = true
    @State private var showDeletionError = false
    @State private var showSubscriptionView = false
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @State private var trialStatus = RoleplayTrial.status

    /// シチュエーション・キャラクター詳細の編集はプレミアム限定（記憶の確認・削除は誰でもできる）。
    /// 無料ユーザーはお試しとして1回だけ設定できる
    private var isPremium: Bool { subscriptionManager.isSubscribed }
    private var canEdit: Bool { isPremium || trialStatus == .available }
    private var canSave: Bool { loadedState != nil && !isLoading && !isSaving }

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                } else if loadedState == nil {
                    VStack(spacing: 16) {
                        Text("roleplay_settings_load_failed").foregroundStyle(.secondary)
                        Button("roleplay_settings_retry", action: load)
                    }.padding()
                } else {
                    form
                        .disabled(isSaving)
                }
            }
            .navigationTitle(rpText("roleplay_settings_title", "ロールプレイ設定"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(rpText("roleplay_settings_title", "ロールプレイ設定"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().accessibilityLabel(Text("roleplay_settings_saving"))
                    } else {
                        Button(L10n.save) { save() }.disabled(!canSave)
                    }
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .alert(rpText("roleplay_settings_save_failed", "保存できませんでした"), isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .alert(rpText("roleplay_memory_delete_failed", "記憶を削除できませんでした。通信状態を確認して、もう一度お試しください。"), isPresented: $showDeletionError) {
            Button("OK", role: .cancel) { }
        }
        .onAppear(perform: load)
        .sheet(isPresented: $showSubscriptionView) {
            SubscriptionPreView(source: .roleplay)
        }
    }

    private var premiumBanner: some View {
        Section {
            Button {
                showSubscriptionView = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bannerTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Text(bannerMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var bannerTitle: String {
        switch trialStatus {
        case .available:
            return rpText("roleplay_trial_available_title", "ロールプレイを1回無料で体験できます")
        case .active(let remaining):
            return String(format: rpText("roleplay_trial_active_title", "お試し中（残り%d回）"), remaining)
        case .used:
            return rpText("roleplay_trial_used_title", "続きはプレミアムで")
        }
    }

    private var bannerMessage: String {
        switch trialStatus {
        case .available:
            return String(format: rpText("roleplay_trial_available_message", "場所や時間を決めて保存すると、%1$@の返信%2$d回までシチュエーションで話せます。続きはプレミアムで楽しめます。"), oshi.name, RoleplayTrial.replyLimit)
        case .active:
            return rpText("roleplay_trial_active_message", "設定の変更や、回数を気にせず続けるにはプレミアムに登録してください。")
        case .used:
            return String(format: rpText("roleplay_trial_used_message", "お試しは終了しました。プレミアムなら今の設定のまま%@とのロールプレイを続けられます。"), oshi.name)
        }
    }

    private func lockedHeader(_ title: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
            if !canEdit {
                Image(systemName: "lock.fill")
            }
        }
    }

    private var form: some View {
        Form {
            Section {
                Toggle("roleplay_inner_thought_enabled", isOn: $innerThoughtsEnabled)
                    .accessibilityIdentifier("innerThoughtsEnabled")
            } footer: {
                Text("roleplay_inner_thought_footer")
            }

            RoleplayPersonaSection(persona: $persona)

            if !isPremium {
                premiumBanner
            }

            Section {
                multiline(rpText("roleplay_background", "過去・生い立ち"), text: $profile.background, placeholder: rpText("roleplay_background_placeholder", "例: 幼い頃は人見知りだったが、あなたと出会って少しずつ変わった"))
            } header: {
                lockedHeader(rpText("roleplay_backstory_section", "推しの過去"))
            } footer: {
                Text("roleplay_backstory_footer")
            }

            Section {
                field(rpText("roleplay_location", "場所"), text: $situation.location, placeholder: rpText("roleplay_location_placeholder", "例: 学校の屋上"))
                field(rpText("roleplay_time", "時間"), text: $situation.time, placeholder: rpText("roleplay_time_placeholder", "例: 放課後"))
                multiline(rpText("roleplay_situation", "状況"), text: $situation.situation, placeholder: rpText("roleplay_situation_placeholder", "例: 二人きりで話している"))
                if !canEdit && !situation.isEmpty {
                    // 解約後も、設定済みのシチュエーションは解除できるようにしておく
                    Button(rpText("roleplay_situation_clear", "シチュエーションを解除"), role: .destructive) {
                        situation = RoleplaySituation()
                    }
                }
            } header: {
                lockedHeader(rpText("roleplay_situation_section", "今のシチュエーション"))
            } footer: {
                Text(String(format: rpText("roleplay_situation_footer", "%@はこの場面にいるつもりで会話します。空欄なら会話の流れに合わせます。"), oshi.name))
            }

            Section {
                multiline(rpText("roleplay_description", "キャラクター説明"), text: $profile.description, placeholder: rpText("roleplay_description_placeholder", "例: クールで少しツンデレな幼なじみ"))
                multiline(rpText("roleplay_world_setting", "世界観"), text: $profile.worldSetting, placeholder: rpText("roleplay_world_setting_placeholder", "例: 現代日本の地方都市"))
                multiline(rpText("roleplay_likes", "好きなもの"), text: $profile.likes, placeholder: rpText("roleplay_likes_placeholder", "例: 甘いもの、夜の散歩"))
                multiline(rpText("roleplay_dislikes", "苦手なもの"), text: $profile.dislikes, placeholder: rpText("roleplay_dislikes_placeholder", "例: 雷、朝早く起きること"))
                multiline(rpText("roleplay_behavior_rules", "行動ルール"), text: $profile.behaviorRules, placeholder: rpText("roleplay_behavior_rules_placeholder", "例: 照れると話題をそらす"))
                multiline(rpText("roleplay_example_dialogues", "会話例"), text: $profile.exampleDialogues, placeholder: rpText("roleplay_example_dialogues_placeholder", "例: 「別に、待ってたわけじゃないし」"))
            } header: {
                lockedHeader(rpText("roleplay_character_section", "キャラクター詳細"))
            } footer: {
                Text(rpText("roleplay_character_footer", "性格・話し方・関係性などは推しの設定画面の内容が使われます。"))
            }

            Section {
                if memories.isEmpty {
                    Text(rpText("roleplay_memories_empty", "まだ覚えていることはありません。会話を続けると大切なことを覚えていきます。"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(memories.reversed()) { memory in
                        Text(memory.content)
                            .font(.subheadline)
                    }
                    .onDelete(perform: deleteMemories)
                }
            } header: {
                Text(String(format: rpText("roleplay_memories_section", "%@が覚えていること"), oshi.name))
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if !memories.isEmpty {
                        Text(rpText("roleplay_memories_footer", "左にスワイプすると忘れさせることができます。"))
                    }
                    Text(isPremium
                         ? String(format: rpText("roleplay_memories_capacity_premium", "プレミアム: 最大%d件まで覚えています。"), PremiumFeatures.maxStoredMemories(isPremium: true))
                         : String(format: rpText("roleplay_memories_capacity_free", "最大%d件まで覚えています（プレミアムなら%d件）。"), PremiumFeatures.maxStoredMemories(isPremium: false), PremiumFeatures.maxStoredMemories(isPremium: true)))
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func field(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            TextField(placeholder, text: text)
        }
        .disabled(!canEdit)
    }

    private func multiline(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(1...6)
        }
        .disabled(!canEdit)
    }

    private func load() {
        isLoading = true
        RoleplayRepository.shared.fetchState(oshiId: oshi.id) { state in
            DispatchQueue.main.async {
                guard !state.userId.isEmpty, state.userId == RoleplayRepository.shared.currentUserId else {
                    loadedState = nil
                    isLoading = false
                    return
                }
                loadedState = state
                situation = state.situation
                profile = state.profile
                persona = state.userPersona
                innerThoughtsEnabled = state.innerThoughtsEnabled
                memories = state.memories
                isLoading = false
            }
        }
    }

    private func deleteMemories(at offsets: IndexSet) {
        let displayed = Array(memories.reversed())
        for index in offsets {
            let memory = displayed[index]
            memories.removeAll { $0.id == memory.id }
            RoleplayRepository.shared.deleteMemory(memory) { error in
                DispatchQueue.main.async {
                    if error != nil { showDeletionError = true }
                    RoleplayRepository.shared.fetchState(oshiId: oshi.id) { state in
                        DispatchQueue.main.async { memories = state.memories }
                    }
                }
            }
        }
    }

    private func save() {
        guard canSave, let expected = loadedState else { return }
        let trimmedSituation = RoleplaySituation(
            location: situation.location.trimmingCharacters(in: .whitespacesAndNewlines),
            time: situation.time.trimmingCharacters(in: .whitespacesAndNewlines),
            situation: situation.situation.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        let changedProfile = canEdit && profile != expected.profile ? profile : nil
        let changedSituation = (canEdit || trimmedSituation.isEmpty) && trimmedSituation != expected.situation ? trimmedSituation : nil
        let startsTrial = !isPremium && trialStatus == .available
            && ((changedProfile != nil && !profile.isEmpty) || (changedSituation != nil && !trimmedSituation.isEmpty))
        isSaving = true
        RoleplayRepository.shared.saveSettings(oshiId: oshi.id, expected: expected, persona: persona,
            innerThoughtsEnabled: innerThoughtsEnabled, profile: changedProfile, situation: changedSituation) { error in
            DispatchQueue.main.async {
                isSaving = false
                if let error {
                    saveError = error.localizedDescription
                    return
                }
                if startsTrial { RoleplayTrial.start() }
                onSituationSaved(trimmedSituation)
                dismiss()
            }
        }
    }
}
