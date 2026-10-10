import SwiftUI

// MARK: - 入力内容

/// 新しい物語の入力内容。保存時に `StoryConfiguration` へ変換する。
struct StoryDraft: Equatable {
    static let titleLimit = 30
    static let synopsisLimit = 200
    static let userNameLimit = 12
    static let roleLimit = 20

    /// 選択順。役柄はこの物語だけの設定
    var selected: [StoryCharacter] = []
    var setting: StorySetting = .school
    var title = ""
    var synopsis = ""
    var mood: StoryMood = .gentle
    var romance = false
    var participation: StoryParticipation = .protagonist
    var leadID: String?
    var userName = ""
    var userRole = ""
    var pairs: [StoryPair] = []
    var isCastingOpen = false

    static func initial(cast: [StoryCharacter]) -> StoryDraft {
        #if DEBUG
        var draft = StoryDraft()
        for character in cast.prefix(3) { draft.toggle(character) }
        draft.title = StoryText.text("story_debug_title")
        draft.synopsis = StoryText.text(draft.setting.synopsisKey)
        draft.mood = .youth
        draft.participation = .member
        draft.userName = StoryText.text("story_user_default")
        draft.userRole = StoryText.text("story_role_support")
        return draft
        #else
        return StoryDraft()
        #endif
    }

    enum Blocker { case noCast, noTitle }

    /// CTA を無効にする理由（推し0人を優先）
    var blocker: Blocker? {
        if selected.isEmpty { return .noCast }
        if title.storyTrimmed.isEmpty { return .noTitle }
        return nil
    }

    func order(of character: StoryCharacter) -> Int? {
        selected.firstIndex { $0.id == character.id }.map { $0 + 1 }
    }

    static func defaultRole(setting: StorySetting, index: Int) -> String {
        StoryText.text("story_role_" + setting.roles[min(index, setting.roles.count - 1)])
    }

    /// 選択・解除。外すと後ろの番号が繰り上がる
    mutating func toggle(_ character: StoryCharacter) {
        if let index = selected.firstIndex(where: { $0.id == character.id }) {
            selected.remove(at: index)
        } else if selected.count < 3 {
            var copy = character
            copy.role = Self.defaultRole(setting: setting, index: selected.count)
            selected.append(copy)
        }
        if !selected.contains(where: { $0.id == leadID }) { leadID = selected.first?.id }
        var newPairs: [StoryPair] = []
        for first in selected.indices {
            for second in selected.indices where second > first {
                let pair = StoryPair(firstID: selected[first].id, secondID: selected[second].id)
                newPairs.append(pairs.first(where: { $0.id == pair.id }) ?? pair)
            }
        }
        pairs = newPairs
    }

    /// 舞台を変えたら、初期値のままの役柄だけ新しい舞台の初期値に置き換える
    mutating func changeSetting(_ newSetting: StorySetting) {
        for index in selected.indices where selected[index].role == Self.defaultRole(setting: setting, index: index) {
            selected[index].role = Self.defaultRole(setting: newSetting, index: index)
        }
        setting = newSetting
    }

    func configuration(language: String) -> StoryConfiguration {
        // 空欄は従来どおりの初期値で補う（モデルの検証は空を許さない）
        func filled(_ text: String, _ fallback: String) -> String {
            text.storyTrimmed.isEmpty ? fallback : text.storyTrimmed
        }
        var cast = selected
        for index in cast.indices {
            cast[index].role = filled(cast[index].role, Self.defaultRole(setting: setting, index: index))
        }
        return StoryConfiguration(
            title: title.storyTrimmed, setting: setting,
            synopsis: filled(synopsis, StoryText.text(setting.synopsisKey)),
            mood: mood, romance: romance, participation: participation,
            leadID: participation == .member ? leadID : nil,
            userName: filled(userName, StoryText.text("story_user_default")),
            userRole: filled(userRole, StoryText.text(participation == .protagonist ? "story_role_protagonist" : "story_role_support")),
            language: language, cast: cast, relationships: pairs)
    }
}

// MARK: - 新しい物語

struct StoryCreationView: View {
    let cast: [StoryCharacter]
    let ownerID: String
    let onSaved: (StoryRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var draft: StoryDraft
    @State private var session: StorySession?
    @State private var validationError: String?
    /// プレビュー専用：保存中・保存エラーの表示
    private let previewCommit: StoryCreationBottomBar.Phase?

    init(cast: [StoryCharacter], ownerID: String, draft: StoryDraft = StoryDraft(),
         previewCommit: StoryCreationBottomBar.Phase? = nil, onSaved: @escaping (StoryRecord) -> Void) {
        self.cast = cast
        self.ownerID = ownerID
        self.onSaved = onSaved
        self.previewCommit = previewCommit
        _draft = State(initialValue: draft)
    }

    private var isCommitting: Bool { session != nil || previewCommit != nil }
    private var isAX: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    hero
                    castSection
                    setupSection
                    participationSection
                    castingSection
                }
                .padding(.horizontal, StoryTheme.gutter)
                .padding(.top, 8)
                .padding(.bottom, StoryTheme.bottomBarClearance)
                .disabled(isCommitting)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(StoryTheme.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { bottomBar }
            .storyNavigationTitle(StoryText.text("story_new"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Text(StoryText.text("story_close"))
                            .foregroundColor(StoryTheme.pinkText)
                            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                    }
                    .disabled(isCommitting)
                }
            }
        }
        .preferredColorScheme(.light)
        .interactiveDismissDisabled(isCommitting)
    }

    // MARK: ヒーロー

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 14)).accessibilityHidden(true)
                Text(StoryText.text("story_title")).font(.storyFootnote.weight(.semibold))
            }
            Text(StoryText.text("story_entry_hint"))
                .storyFont(size: 24, weight: .bold, relativeTo: .title2)
                .storyLineHeight(1.35, fontSize: 24, relativeTo: .title2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(StoryText.text("story_hero_body"))
                .font(.storySubheadline.weight(.medium))
                .storyLineHeight(1.6, fontSize: 15, relativeTo: .subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 22)
        .padding(.horizontal, 20)
        .background(
            LinearGradient(colors: [StoryTheme.primaryStart, StoryTheme.primaryEnd],
                           startPoint: UnitPoint(x: 0, y: 0.1), endPoint: UnitPoint(x: 1, y: 0.9))
        )
        .overlay(alignment: .topTrailing) {
            ZStack(alignment: .topTrailing) {
                SparkleShape().fill(Color.white.opacity(0.16)).frame(width: 80, height: 80).offset(x: -2, y: -12)
                SparkleShape().fill(Color.white.opacity(0.5)).frame(width: 15, height: 15).offset(x: -100, y: 75)
            }
            .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: StoryTheme.Radius.card, style: .continuous))
        .storyShadow(.pink(opacity: 0.26, radius: 24, y: 10))
    }

    // MARK: ① 出演する推し

    private var castSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(step: 1, title: StoryText.text("story_cast")) {
                counter
            }
            VStack(alignment: .leading, spacing: 12) {
                Text(StoryText.text("story_cast_hint"))
                    .font(.storyFootnote)
                    .foregroundColor(StoryTheme.body)
                    .fixedSize(horizontal: false, vertical: true)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: isAX ? 2 : 3),
                          spacing: 10) {
                    ForEach(cast) { character in castCell(character) }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .storyCardSurface()
            .storyShadow(.normal)
        }
    }

    private var counter: some View {
        let isEmpty = draft.selected.isEmpty
        return HStack(spacing: 2) {
            Text(String(format: StoryText.text("story_cast_count_value"), draft.selected.count))
                .font(.storyFootnote.weight(.semibold))
                .foregroundColor(isEmpty ? StoryTheme.secondary : StoryTheme.pinkText)
            Text(StoryText.text("story_cast_count_range"))
                .font(.storyCaption.weight(.medium))
                .foregroundColor(StoryTheme.secondary)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 28)
        .background(Capsule().fill(isEmpty ? Color(hex: "F2EDF4") : StoryTheme.softPink))
        .accessibilityElement(children: .combine)
    }

    private func castCell(_ character: StoryCharacter) -> some View {
        let order = draft.order(of: character)
        let isSelected = order != nil
        let isLocked = draft.selected.count >= 3 && !isSelected
        let role = order.map { draft.selected[$0 - 1].role } ?? ""
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { draft.toggle(character) }
        } label: {
            VStack(spacing: 6) {
                OshiAvatar(character: character, size: isAX ? 56 : 68,
                           ring: isSelected ? .gradient : .plain(Color(hex: "F2EDF4")),
                           borderWidth: 2, order: order)
                Text(character.name)
                    .font(.storySubheadline.weight(.semibold))
                    .foregroundColor(StoryTheme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
                Text(role.isEmpty ? " " : role)
                    .font(.storyCaption)
                    .foregroundColor(StoryTheme.secondary)
                    .lineLimit(1)
            }
            .padding(.top, 14).padding(.horizontal, 6).padding(.bottom, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(isSelected ? StoryTheme.selectedFill : .white))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isSelected ? Color(hex: "FFB8C9") : StoryTheme.border, lineWidth: isSelected ? 1.5 : 1))
            .opacity(isLocked ? 0.45 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(order.map { String(format: StoryText.text("story_cast_a11y_selected"), character.name, $0) } ?? character.name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: ② 物語の設定

    private var titleError: Bool { draft.blocker == .noTitle }

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(step: 2, title: StoryText.text("story_setup"))
            VStack(alignment: .leading, spacing: 24) {
                titleField
                settingPicker
                synopsisField
                moodPicker
                Rectangle().fill(Color(hex: "F2EDF4")).frame(height: 1).padding(.vertical, -4)
                Toggle(isOn: $draft.romance) {
                    Text(StoryText.text("story_romance"))
                        .font(.storyBody.weight(.semibold))
                        .foregroundColor(StoryTheme.text)
                }
                .toggleStyle(StorySwitchStyle())
                .padding(.top, -8)
            }
            .padding(.vertical, 18).padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .storyCardSurface()
            .storyShadow(.normal)
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                fieldLabel(StoryText.text("story_title_label"))
                Text(StoryText.text("story_required"))
                    .font(.storyCaption.weight(.semibold))
                    .foregroundColor(StoryTheme.pinkText)
            }
            .accessibilityElement(children: .combine)
            StoryTextField(placeholder: StoryText.text("story_title_placeholder"), text: $draft.title,
                           limit: StoryDraft.titleLimit, isError: titleError)
                .accessibilityLabel(StoryText.text("story_title_label"))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if titleError {
                    Label {
                        Text(StoryText.text("story_title_error"))
                    } icon: {
                        Image(systemName: "exclamationmark.circle.fill").font(.system(size: 13))
                    }
                    .font(.storyFootnote)
                    .foregroundColor(StoryTheme.error)
                }
                Spacer(minLength: 0)
                counterText(draft.title.count, StoryDraft.titleLimit)
            }
        }
    }

    private var settingPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            fieldLabel(StoryText.text("story_setting"))
            adaptiveStack(spacing: 10) {
                ForEach(StorySetting.allCases, id: \.self) { option in
                    settingTile(option)
                }
            }
        }
    }

    private func settingTile(_ option: StorySetting) -> some View {
        let isSelected = draft.setting == option
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { draft.changeSetting(option) }
        } label: {
            VStack(spacing: 0) {
                StorySceneryImage(backdrop: StoryBackdrop.opening(for: option))
                    .frame(height: 74)
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(StoryTheme.pinkText, .white)
                                .padding(7)
                                .accessibilityHidden(true)
                        }
                    }
                Text(StoryText.text(option.titleKey))
                    .font(.storySubheadline.weight(.semibold))
                    .foregroundColor(StoryTheme.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 12)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(isSelected ? StoryTheme.softPink : .white))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? StoryTheme.selectedBorder : StoryTheme.border, lineWidth: isSelected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var synopsisField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(StoryText.text("story_synopsis_label"))
            StoryTextEditor(placeholder: String(format: StoryText.text("story_synopsis_placeholder"), StoryText.text(draft.setting.synopsisKey)),
                            text: $draft.synopsis, limit: StoryDraft.synopsisLimit)
                .accessibilityLabel(StoryText.text("story_synopsis_label"))
            HStack {
                Spacer()
                counterText(draft.synopsis.count, StoryDraft.synopsisLimit)
            }
        }
    }

    private var moodPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            fieldLabel(StoryText.text("story_mood"))
            adaptiveStack(spacing: 8, fillsWidth: false) {
                ForEach(StoryMood.allCases, id: \.self) { option in
                    moodChip(option)
                }
            }
        }
    }

    private func moodChip(_ option: StoryMood) -> some View {
        let isSelected = draft.mood == option
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { draft.mood = option }
        } label: {
            Text(StoryText.text("story_mood_" + option.rawValue))
                .font(.storySubheadline.weight(.semibold))
                .foregroundColor(isSelected ? StoryTheme.pinkText : StoryTheme.text)
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .background(Capsule().fill(isSelected ? StoryTheme.softPink : .white))
                .overlay(Capsule().strokeBorder(isSelected ? StoryTheme.selectedBorder : StoryTheme.border, lineWidth: isSelected ? 1.5 : 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: ③ 参加方法

    private var participationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(step: 3, title: StoryText.text("story_participation"))
            ForEach(StoryParticipation.allCases, id: \.self) { option in
                participationCard(option)
            }
            VStack(alignment: .leading, spacing: 24) {
                if draft.participation == .member { leadPicker }
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel(StoryText.text("story_user_name_label"))
                    StoryTextField(placeholder: StoryText.text("story_user_name_placeholder"), text: $draft.userName,
                                   limit: StoryDraft.userNameLimit)
                        .accessibilityLabel(StoryText.text("story_user_name_label"))
                }
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel(StoryText.text("story_user_role_label"))
                    StoryTextField(placeholder: StoryText.text("story_user_role_placeholder"), text: $draft.userRole,
                                   limit: StoryDraft.roleLimit)
                        .accessibilityLabel(StoryText.text("story_user_role_label"))
                }
            }
            .padding(.vertical, 18).padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .storyCardSurface()
            .storyShadow(.normal)
        }
    }

    private func participationCard(_ option: StoryParticipation) -> some View {
        let isSelected = draft.participation == option
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                draft.participation = option
                if draft.leadID == nil { draft.leadID = draft.selected.first?.id }
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                participationIcon(option)
                VStack(alignment: .leading, spacing: 4) {
                    Text(StoryText.text("story_mode_" + option.rawValue))
                        .font(.storyHeadline.weight(.bold))
                        .foregroundColor(StoryTheme.text)
                    Text(StoryText.text(option == .protagonist ? "story_protagonist_hint" : "story_member_hint"))
                        .font(.storyFootnote)
                        .foregroundColor(StoryTheme.body)
                        .storyLineHeight(1.55, fontSize: 13, relativeTo: .footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                radio(isSelected)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(isSelected ? StoryTheme.selectedFill : .white))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isSelected ? StoryTheme.selectedBorder : StoryTheme.border, lineWidth: isSelected ? 2 : 1))
            .modifier(SelectableShadow(isSelected: isSelected))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func participationIcon(_ option: StoryParticipation) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(option == .protagonist ? StoryTheme.softPink : StoryTheme.softPurple)
            .frame(width: 48, height: 48)
            .overlay {
                if option == .protagonist {
                    Image(systemName: "person.fill").font(.system(size: 22)).foregroundColor(StoryTheme.progressRead)
                        .overlay(alignment: .topTrailing) {
                            SparkleShape().fill(StoryTheme.sparklePurple).frame(width: 7, height: 7).offset(x: 6, y: -4)
                        }
                } else {
                    Image(systemName: "person.3.fill").font(.system(size: 18)).foregroundColor(Color(hex: "A58BD8"))
                }
            }
            .accessibilityHidden(true)
    }

    private func radio(_ isOn: Bool) -> some View {
        ZStack {
            if isOn {
                Circle().fill(StoryTheme.diagonalGradient)
                Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundColor(.white)
            } else {
                Circle().fill(Color.white)
                Circle().strokeBorder(Color(hex: "DCD3E3"), lineWidth: 2)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }

    private var leadPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                fieldLabel(StoryText.text("story_lead"))
                Spacer(minLength: 8)
                Text(StoryText.text("story_lead_hint")).font(.storyCaption).foregroundColor(StoryTheme.secondary)
            }
            if draft.selected.isEmpty {
                Text(StoryText.text("story_lead_empty"))
                    .font(.storyFootnote)
                    .foregroundColor(StoryTheme.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(hex: "DCD3E3"), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { leadChips }
                    VStack(alignment: .leading, spacing: 8) { leadChips }
                }
            }
        }
    }

    @ViewBuilder private var leadChips: some View {
        ForEach(draft.selected) { character in
            let isLead = draft.leadID == character.id
            Button { draft.leadID = character.id } label: {
                HStack(spacing: 8) {
                    OshiAvatar(character: character, size: 36)
                    Text(character.name)
                        .font(.storySubheadline.weight(.semibold))
                        .foregroundColor(isLead ? StoryTheme.pinkText : StoryTheme.text)
                        .lineLimit(1)
                }
                .padding(.leading, 6).padding(.trailing, 14)
                .frame(minHeight: 48)
                .background(Capsule().fill(isLead ? StoryTheme.softPink : .white))
                .overlay(Capsule().strokeBorder(isLead ? StoryTheme.selectedBorder : StoryTheme.border, lineWidth: isLead ? 2 : 1))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(character.name)
            .accessibilityAddTraits(isLead ? [.isSelected] : [])
        }
    }

    // MARK: ④ 配役・関係（Disclosure）

    private var castingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { draft.isCastingOpen.toggle() }
            } label: {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(StoryTheme.softPurple)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "slider.horizontal.3").font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color(hex: "8E77C7"))
                        }
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(StoryText.text("story_casting"))
                            .font(.storyBody.weight(.semibold))
                            .foregroundColor(StoryTheme.text)
                        Text(StoryText.text("story_casting_hint"))
                            .font(.storyFootnote)
                            .foregroundColor(StoryTheme.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(StoryTheme.placeholder)
                        .rotationEffect(.degrees(draft.isCastingOpen ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 14).padding(.horizontal, 16)
                .frame(minHeight: 72)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityValue(StoryText.text(draft.isCastingOpen ? "story_expanded" : "story_collapsed"))
            .accessibilityAddTraits(.isButton)

            if draft.isCastingOpen {
                VStack(alignment: .leading, spacing: 22) {
                    if draft.selected.isEmpty {
                        Text(StoryText.text("story_casting_empty"))
                            .font(.storyFootnote)
                            .foregroundColor(StoryTheme.secondary)
                    } else {
                        roleEditors
                    }
                    if !draft.pairs.isEmpty { relationEditors }
                }
                .padding(.top, 18).padding(.horizontal, 16).padding(.bottom, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { Rectangle().fill(Color(hex: "F2EDF4")).frame(height: 1) }
                .transition(.opacity)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: StoryTheme.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: StoryTheme.Radius.card, style: .continuous).strokeBorder(StoryTheme.border, lineWidth: 1))
        .storyShadow(.normal)
    }

    private var roleEditors: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldLabel(StoryText.text("story_cast_roles"))
            ForEach($draft.selected) { $character in
                HStack(spacing: 12) {
                    OshiAvatar(character: character, size: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        let label = String(format: StoryText.text("story_cast_role_label"), character.name)
                        Text(label).font(.storyFootnote).foregroundColor(StoryTheme.body)
                        StoryTextField(placeholder: "", text: $character.role, limit: StoryDraft.roleLimit,
                                       height: 44, cornerRadius: 12)
                            .accessibilityLabel(label)
                    }
                }
            }
        }
    }

    private var relationEditors: some View {
        VStack(alignment: .leading, spacing: 14) {
            fieldLabel(StoryText.text("story_relations"))
            ForEach($draft.pairs) { $pair in
                let first = draft.selected.first { $0.id == pair.firstID }
                let second = draft.selected.first { $0.id == pair.secondID }
                let label = String(format: StoryText.text("story_pair_label"), first?.name ?? "", second?.name ?? "")
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        AvatarStack(characters: [first, second].compactMap { $0 }, size: 28, borderWidth: 2, overlap: 8)
                        Text(label).storyFont(size: 14, weight: .semibold, relativeTo: .subheadline).foregroundColor(StoryTheme.text)
                    }
                    StoryRelationshipPicker(selection: $pair.relationship)
                        .accessibilityLabel(label)
                }
            }
        }
    }

    // MARK: 固定ボトムバー

    @ViewBuilder private var bottomBar: some View {
        if let session {
            StoryCreationCommitBar(session: session, onSaved: onSaved)
        } else {
            StoryCreationBottomBar(blocker: draft.blocker, phase: previewCommit ?? .idle,
                                   message: validationError, onCreate: create, onRetry: {})
        }
    }

    private func create() {
        let language = Locale.current.language.languageCode?.identifier == "ja" ? "ja" : "en"
        let configuration = draft.configuration(language: language)
        do {
            try configuration.validate()
            validationError = nil
            session = StorySession.live(record: StoryRecord(ownerID: ownerID, configuration: configuration))
        } catch {
            validationError = error.localizedDescription
            StoryAccessibility.announce(error.localizedDescription)
        }
    }

    // MARK: 部品

    private func sectionHeader(step: Int, title: String) -> some View {
        sectionHeader(step: step, title: title) { EmptyView() }
    }

    private func sectionHeader<Trailing: View>(step: Int, title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 10) {
            Text("\(step)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(StoryTheme.diagonalGradient))
                .accessibilityHidden(true)
            Text(title)
                .font(.storyTitle3)
                .foregroundColor(StoryTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            trailing()
        }
        .padding(.horizontal, 2)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.storySubheadline.weight(.semibold)).foregroundColor(StoryTheme.text)
    }

    private func counterText(_ count: Int, _ limit: Int) -> some View {
        Text(String(format: StoryText.text("story_count_format"), count, limit))
            .font(.storyCaption)
            .foregroundColor(StoryTheme.secondary)
    }

    /// 通常は横並び、AXサイズでは縦積み
    @ViewBuilder private func adaptiveStack<Content: View>(spacing: CGFloat, fillsWidth: Bool = true,
                                                          @ViewBuilder content: () -> Content) -> some View {
        if isAX {
            VStack(alignment: .leading, spacing: spacing) { content() }
        } else {
            HStack(spacing: spacing) { content() }
        }
    }
}

private struct SelectableShadow: ViewModifier {
    var isSelected: Bool
    func body(content: Content) -> some View {
        if isSelected {
            content.storyShadow(.pink(opacity: 0.14, radius: 18, y: 6))
        } else {
            content.storyShadow(.normal)
        }
    }
}

// MARK: - 入力欄

/// 高さ52・角丸14・16pt の1行入力。文字数を上限で切り詰める。
struct StoryTextField: View {
    var placeholder: String
    @Binding var text: String
    var limit: Int
    var isError = false
    var height: CGFloat = 52
    var cornerRadius: CGFloat = StoryTheme.Radius.field
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(StoryTheme.placeholder))
            .font(.storyBody)
            .foregroundColor(StoryTheme.text)
            .focused($focused)
            .padding(.horizontal, 14)
            .frame(minHeight: height)
            .background(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isError ? Color(hex: "FFF7F8") : (focused ? .white : StoryTheme.background)))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(isError ? StoryTheme.error : (focused ? Color(hex: "FF9BB3") : StoryTheme.border),
                              lineWidth: isError || focused ? 1.5 : 1))
            .onChange(of: text) { newValue in
                if newValue.count > limit { text = String(newValue.prefix(limit)) }
            }
    }
}

/// あらすじなどの複数行入力（高さ112・16pt 行間1.55）
struct StoryTextEditor: View {
    var placeholder: String
    @Binding var text: String
    var limit: Int
    var height: CGFloat = 112
    /// フォーカスがなくても枠を強調する（自由入力に文字がある間など）
    var isHighlighted = false
    /// 右上に消去ボタンを重ねるための余白
    var trailingInset: CGFloat = 0
    @FocusState private var focused: Bool

    private var emphasized: Bool { focused || isHighlighted }

    var body: some View {
        TextEditor(text: $text)
            .font(.storyBody)
            .foregroundColor(StoryTheme.text)
            .storyLineHeight(1.55, fontSize: 16, relativeTo: .callout)
            .scrollContentBackground(.hidden)
            .focused($focused)
            .padding(.leading, 9).padding(.trailing, 9 + trailingInset).padding(.vertical, 4)
            .frame(minHeight: height)
            .background(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.storyBody)
                        .foregroundColor(StoryTheme.placeholder)
                        .storyLineHeight(1.55, fontSize: 16, relativeTo: .callout)
                        .padding(.leading, 14).padding(.trailing, 14 + trailingInset).padding(.vertical, 12)
                        .accessibilityHidden(true)
                }
            }
            .background(RoundedRectangle(cornerRadius: StoryTheme.Radius.field, style: .continuous)
                .fill(focused ? .white : StoryTheme.background))
            .overlay(RoundedRectangle(cornerRadius: StoryTheme.Radius.field, style: .continuous)
                .strokeBorder(emphasized ? Color(hex: "FF9BB3") : StoryTheme.border, lineWidth: emphasized ? 1.5 : 1))
            .onChange(of: text) { newValue in
                if newValue.count > limit { text = String(newValue.prefix(limit)) }
            }
    }
}

/// グラデーションのトラックを持つスイッチ（51×31）
struct StorySwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { configuration.isOn.toggle() }
        } label: {
            HStack(spacing: 12) {
                configuration.label
                Spacer(minLength: 0)
                Capsule()
                    .fill(configuration.isOn ? AnyShapeStyle(StoryTheme.diagonalGradient) : AnyShapeStyle(Color(hex: "E4DFE8")))
                    .frame(width: 51, height: 31)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle().fill(Color.white)
                            .frame(width: 27, height: 27)
                            .shadow(color: StoryTheme.text.opacity(0.18), radius: 2.5, y: 2)
                            .padding(2)
                    }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

/// 推し同士の関係（初対面／友人／ライバル）
struct StoryRelationshipPicker: View {
    @Binding var selection: StoryRelationship
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 3)) : AnyLayout(HStackLayout(spacing: 3))
        layout {
            ForEach(StoryRelationship.allCases, id: \.self) { option in
                let isSelected = selection == option
                Button { withAnimation(.easeInOut(duration: 0.15)) { selection = option } } label: {
                    Text(StoryText.text("story_relation_" + option.rawValue))
                        .storyFont(size: 14, weight: .semibold, relativeTo: .subheadline)
                        .foregroundColor(isSelected ? StoryTheme.pinkText : StoryTheme.body)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(isSelected ? Color.white : Color.clear)
                            .shadow(color: StoryTheme.text.opacity(isSelected ? 0.10 : 0), radius: 2, y: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: "F2EDF4")))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - 固定ボトムバー

/// 「物語を保存して始める」。無効理由をCTAの上に1行表示する。
struct StoryCreationBottomBar: View {
    enum Phase: Equatable {
        case idle
        case saving
        case failed(String)
    }

    var blocker: StoryDraft.Blocker?
    var phase: Phase
    /// 保存前の検証で見つかった問題
    var message: String? = nil
    var onCreate: () -> Void
    var onRetry: () -> Void

    var body: some View {
        StoryBottomBar {
            switch phase {
            case .idle:
                if let blocker {
                    hint(StoryText.text(blocker == .noCast ? "story_hint_no_cast" : "story_title_error"),
                         color: blocker == .noCast ? StoryTheme.body : StoryTheme.error)
                } else if let message {
                    hint(message, color: StoryTheme.error)
                }
                StoryPrimaryButton(title: StoryText.text("story_create"), isEnabled: blocker == nil, action: onCreate)
                    .accessibilityIdentifier("story.create")
            case .saving:
                StatusCard(kind: .saving)
                StoryPrimaryButton(title: StoryText.text("story_create"), isEnabled: false) {}
            case .failed(let message):
                hint(message, color: StoryTheme.error)
                StoryPrimaryButton(title: StoryText.text("story_retry"), systemImage: "arrow.clockwise", action: onRetry)
            }
        }
    }

    private func hint(_ text: String, color: Color) -> some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill").font(.system(size: 13))
        }
        .font(.storyFootnote)
        .foregroundColor(color)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

/// 保存処理中のボトムバー。設定の保存に成功したら `onSaved` を呼ぶ。
private struct StoryCreationCommitBar: View {
    @ObservedObject var session: StorySession
    let onSaved: (StoryRecord) -> Void
    @State private var started = false

    private var phase: StoryCreationBottomBar.Phase {
        if let error = session.error, !session.isBusy { return .failed(error) }
        return .saving
    }

    var body: some View {
        StoryCreationBottomBar(blocker: nil, phase: phase, onCreate: {}, onRetry: {
            Task {
                await session.retry()
                finish()
            }
        })
        .task {
            guard !started else { return }
            started = true
            await session.create()
            finish()
        }
        .onDisappear { session.deactivate() }
    }

    private func finish() {
        if !session.isBusy && !session.hasPendingSave && session.error == nil && session.savedOperationID == session.record.operationID {
            onSaved(session.record)
        }
    }
}

// MARK: - Previews

#if DEBUG
private enum StoryCreationPreview {
    static let cast = StoryPreviewData.cast + [
        StoryCharacter(id: "rei", name: "レイ", imageURL: nil, profile: [:], role: ""),
        StoryCharacter(id: "yuna", name: "ユナ", imageURL: nil, profile: [:], role: ""),
        StoryCharacter(id: "haru", name: "ハル", imageURL: nil, profile: [:], role: "")
    ]

    static func draft(selecting count: Int, title: String = "放課後、秘密の作戦会議",
                      participation: StoryParticipation = .protagonist, open: Bool = false) -> StoryDraft {
        var draft = StoryDraft()
        for character in cast.prefix(count) { draft.toggle(character) }
        draft.title = title
        draft.participation = participation
        draft.isCastingOpen = open
        return draft
    }
}

#Preview("初期（推し未選択）") {
    StoryCreationView(cast: StoryCreationPreview.cast, ownerID: "preview") { _ in }
}

#Preview("タイトル未入力") {
    StoryCreationView(cast: StoryCreationPreview.cast, ownerID: "preview",
                      draft: StoryCreationPreview.draft(selecting: 2, title: "")) { _ in }
}

#Preview("3人選択・一員・詳細設定") {
    StoryCreationView(cast: StoryCreationPreview.cast, ownerID: "preview",
                      draft: StoryCreationPreview.draft(selecting: 3, participation: .member, open: true)) { _ in }
}

#Preview("保存中") {
    StoryCreationView(cast: StoryCreationPreview.cast, ownerID: "preview",
                      draft: StoryCreationPreview.draft(selecting: 2), previewCommit: .saving) { _ in }
}

#Preview("保存エラー") {
    StoryCreationView(cast: StoryCreationPreview.cast, ownerID: "preview",
                      draft: StoryCreationPreview.draft(selecting: 2),
                      previewCommit: .failed(StoryError.saveTimeout.localizedDescription)) { _ in }
}

#Preview("AXサイズ") {
    StoryCreationView(cast: StoryCreationPreview.cast, ownerID: "preview",
                      draft: StoryCreationPreview.draft(selecting: 2, participation: .member, open: true)) { _ in }
        .environment(\.dynamicTypeSize, .accessibility2)
}
#endif
