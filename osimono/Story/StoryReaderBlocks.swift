import SwiftUI

// MARK: - 行動の下書き

/// 「あなたはどうする？」で選んでいる行動。進むのはボトムバーのCTAを押したとき。
struct StoryActionDraft: Equatable {
    static let freeInputLimit = 300

    var choice: Int?
    var text = ""
    /// 章末で「この行動で次の話へ進みます」を表示中
    var isConfirmingChapter = false

    var hasText: Bool { !text.storyTrimmed.isEmpty }
    /// 自由入力に文字がある間は自由入力を優先し、選択肢は使わない
    var effectiveChoice: Int? { hasText ? nil : choice }
    var canProceed: Bool { hasText || choice != nil }

    func intent(in scene: StoryScene) -> String? {
        if hasText { return text.storyTrimmed }
        guard let choice, scene.choices.indices.contains(choice) else { return nil }
        return scene.choices[choice]
    }

    static func choiceKey(_ index: Int) -> String {
        ["A", "B", "C"][min(max(index, 0), 2)]
    }
}

// MARK: - あなたはどうする？

struct StoryChoicePanel: View {
    var choices: [String]
    @Binding var draft: StoryActionDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    SparkleShape().fill(StoryTheme.chevron).frame(width: 12, height: 12).accessibilityHidden(true)
                    Text(StoryText.text("story_choose_action"))
                        .font(.storyTitle3)
                        .foregroundColor(StoryTheme.text)
                }
                .accessibilityAddTraits(.isHeader)
                Label {
                    Text(StoryText.text("story_ai_choices"))
                } icon: {
                    Image(systemName: "sparkles").font(.system(size: 11))
                }
                .font(.storyCaption)
                .foregroundColor(StoryTheme.purpleText)
            }

            VStack(spacing: 10) {
                ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                    choiceCard(index: index, text: choice)
                }
            }

            HStack(spacing: 10) {
                Rectangle().fill(StoryTheme.border).frame(height: 1)
                Text(StoryText.text("story_or")).font(.storyFootnote).foregroundColor(StoryTheme.secondary).fixedSize()
                Rectangle().fill(StoryTheme.border).frame(height: 1)
            }
            .padding(.vertical, 4)
            .accessibilityHidden(true)

            freeInput
        }
        .padding(.top, 20).padding(.horizontal, 16).padding(.bottom, 18)
        .background(RoundedRectangle(cornerRadius: StoryTheme.Radius.cardLarge, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: StoryTheme.Radius.cardLarge, style: .continuous).strokeBorder(StoryTheme.border, lineWidth: 1))
        .shadow(color: StoryTheme.primaryStart.opacity(0.08), radius: 10, y: -2)
    }

    private func choiceCard(index: Int, text: String) -> some View {
        let isSelected = draft.effectiveChoice == index
        let isDisabled = draft.hasText
        let key = StoryActionDraft.choiceKey(index)
        return Button {
            // もう一度タップで解除。選ぶだけで進まない
            draft.choice = draft.choice == index ? nil : index
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(key)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isSelected ? .white : StoryTheme.purpleText)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(isSelected ? AnyShapeStyle(StoryTheme.diagonalGradient) : AnyShapeStyle(StoryTheme.softPurple)))
                Text(text)
                    .font(isSelected ? .storyBody.weight(.semibold) : .storyBody)
                    .foregroundColor(StoryTheme.text)
                    .storyLineHeight(1.6, fontSize: 16, relativeTo: .callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                ZStack {
                    if isSelected {
                        Circle().fill(StoryTheme.diagonalGradient)
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundColor(.white)
                    } else {
                        Circle().fill(Color.white)
                        Circle().strokeBorder(Color(hex: "DCD3E3"), lineWidth: 2)
                    }
                }
                .frame(width: 22, height: 22)
                .padding(.top, 3)
            }
            .padding(.top, 14).padding(.bottom, 14).padding(.leading, 12).padding(.trailing, 14)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(isSelected ? StoryTheme.selectedFill : .white))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isSelected ? StoryTheme.selectedBorder : StoryTheme.border, lineWidth: isSelected ? 2 : 1))
            .opacity(isDisabled ? 0.45 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: StoryText.text("story_choice_a11y"), key) + " " + text)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var freeInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(StoryText.text("story_free_input"))
                .font(.storySubheadline.weight(.semibold))
                .foregroundColor(StoryTheme.text)
            StoryTextEditor(placeholder: StoryText.text("story_free_placeholder"), text: $draft.text,
                            limit: StoryActionDraft.freeInputLimit, height: 104,
                            isHighlighted: draft.hasText, trailingInset: 26)
                .accessibilityLabel(StoryText.text("story_free_input"))
                .overlay(alignment: .topTrailing) {
                    if !draft.text.isEmpty {
                        Button { draft.text = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(Color(hex: "C9C1D1"))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(2)
                        .accessibilityLabel(StoryText.text("story_clear_input"))
                    }
                }
            HStack(alignment: .top, spacing: 8) {
                Text(StoryText.text(draft.hasText ? "story_free_rule_active" : "story_free_rule_idle"))
                    .font(.storyCaption)
                    .foregroundColor(draft.hasText ? StoryTheme.pinkText : StoryTheme.secondary)
                    .storyLineHeight(1.5, fontSize: 12, relativeTo: .caption)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(String(format: StoryText.text("story_input_count"), draft.text.count))
                    .font(.storyCaption)
                    .foregroundColor(StoryTheme.secondary)
                    .fixedSize()
            }
        }
    }
}

// MARK: - 話の区切り

/// グラデの細線＋sparkle 3つ＋「第n話 完了」ピル
struct StoryEpisodeMarker: View {
    var episode: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                fadingLine(leading: true)
                SparkleShape().fill(Color(hex: "C9B8EE")).frame(width: 7, height: 7)
                SparkleShape().fill(StoryTheme.chevron).frame(width: 12, height: 12)
                SparkleShape().fill(Color(hex: "C9B8EE")).frame(width: 7, height: 7)
                fadingLine(leading: false)
            }
            .accessibilityHidden(true)
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(StoryTheme.diagonalGradient))
                    .accessibilityHidden(true)
                Text(String(format: StoryText.text("story_episode_done"), episode))
                    .font(.storyFootnote.weight(.bold))
                    .kerning(0.5)
                    .foregroundColor(StoryTheme.pinkText)
            }
            .padding(.leading, 6).padding(.trailing, 12)
            .frame(minHeight: 30)
            .background(Capsule().fill(Color.white))
            .overlay(Capsule().strokeBorder(Color(hex: "FFD3DF"), lineWidth: 1))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
        .padding(.top, 14)
    }
}

/// 端に向かって消えていくピンクの細線
func fadingLine(leading: Bool) -> some View {
    LinearGradient(colors: leading ? [Color(hex: "FFB8C9").opacity(0), Color(hex: "FFB8C9")]
                                   : [Color(hex: "FFB8C9"), Color(hex: "FFB8C9").opacity(0)],
                   startPoint: .leading, endPoint: .trailing)
        .frame(height: 1)
}

// MARK: - 章間トランジション

/// 各話の場面3のあと、本文の下に続けて表示する確認カード
struct StoryChapterTransition: View {
    var episode: Int
    var intent: String
    var isEnabled = true
    var onNext: () -> Void
    var onChange: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 14) {
            StoryEpisodeMarker(episode: episode)
            VStack(spacing: 0) {
                Text(StoryText.text("story_transition_title"))
                    .storyFont(size: 19, weight: .bold, relativeTo: .title3)
                    .foregroundColor(StoryTheme.text)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 6) {
                    Label {
                        Text(StoryText.text("story_user_action"))
                    } icon: {
                        Image(systemName: "person.fill").font(.system(size: 11)).foregroundColor(StoryTheme.chevron)
                    }
                    .font(.storyCaption.weight(.semibold))
                    .foregroundColor(StoryTheme.pinkText)
                    Text(intent)
                        .font(.storyBody.weight(.semibold))
                        .foregroundColor(StoryTheme.text)
                        .storyLineHeight(1.65, fontSize: 16, relativeTo: .callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 14).padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .storyCardSurface(radius: 16, border: StoryTheme.pinkBorder)
                .accessibilityElement(children: .combine)
                .padding(.top, 14)
                Label {
                    Text(StoryText.text("story_transition_wait"))
                } icon: {
                    Image(systemName: "hourglass").font(.system(size: 12)).foregroundColor(StoryTheme.placeholder)
                }
                .font(.storyFootnote)
                .foregroundColor(StoryTheme.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                StoryPrimaryButton(title: StoryText.text("story_next_episode"), trailingSystemImage: "arrow.right",
                                   isEnabled: isEnabled, action: onNext)
                    .padding(.top, 14)
                SecondaryTextButton(title: StoryText.text("story_change_action"), systemImage: "arrow.uturn.backward",
                                    color: StoryTheme.body, font: .storySubheadline.weight(.semibold), action: onChange)
                    .disabled(!isEnabled)
                    .padding(.top, 4)
            }
            .padding(.top, 20).padding(.horizontal, 18).padding(.bottom, 10)
            .background(
                RoundedRectangle(cornerRadius: StoryTheme.Radius.card, style: .continuous)
                    .fill(LinearGradient(stops: [.init(color: StoryTheme.softPink, location: 0), .init(color: .white, location: 0.58)],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: StoryTheme.Radius.card, style: .continuous).strokeBorder(StoryTheme.pinkBorder, lineWidth: 1))
            .storyShadow(.pink(opacity: 0.14, radius: 28, y: 10))
        }
        .opacity(appeared || reduceMotion ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
            StoryAccessibility.announce(StoryText.text("story_transition_title"))
        }
    }
}

// MARK: - 完結

/// グラデの細線＋「おわり」
struct StoryEndingDivider: View {
    var body: some View {
        HStack(spacing: 10) {
            fadingLine(leading: true)
            Text(StoryText.text("story_the_end_divider"))
                .font(.storyCaption.weight(.semibold))
                .kerning(3.6)
                .foregroundColor(StoryTheme.pinkText)
                .fixedSize()
            fadingLine(leading: false)
        }
        .padding(.top, 6)
    }
}

struct StoryCompletionCard: View {
    var cast: [StoryCharacter]
    var onReread: () -> Void
    var onBackToLibrary: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confettiLanded = false

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(StoryTheme.diagonalGradient)
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            Text(StoryText.text("story_the_end"))
                .storyFont(size: 21, weight: .bold, relativeTo: .title3)
                .foregroundColor(StoryTheme.text)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 14)
            Text(StoryText.text("story_complete_count"))
                .font(.storyFootnote.weight(.semibold))
                .kerning(0.5)
                .foregroundColor(StoryTheme.secondary)
                .padding(.top, 4)
            AvatarStack(characters: cast, size: 44, borderWidth: 3, overlap: 10)
                .shadow(color: StoryTheme.text.opacity(0.08), radius: 3, y: 2)
                .padding(.top, 18)
            Text(String(format: StoryText.text("story_complete_cast"),
                        cast.map(\.name).joined(separator: StoryText.text("story_name_separator"))))
                .storyFont(size: 14, relativeTo: .subheadline)
                .foregroundColor(StoryTheme.body)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            StoryPrimaryButton(title: StoryText.text("story_reread_from_start"), systemImage: "book.fill", action: onReread)
                .padding(.top, 20)
            SecondaryTextButton(title: StoryText.text("story_back_to_library"), color: StoryTheme.body,
                                font: .storySubheadline.weight(.semibold), action: onBackToLibrary)
                .padding(.top, 4)
        }
        .padding(.top, 26).padding(.horizontal, 18).padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) { confetti }
        .background(
            RoundedRectangle(cornerRadius: StoryTheme.Radius.cardLarge, style: .continuous)
                .fill(LinearGradient(stops: [.init(color: StoryTheme.softPink, location: 0),
                                             .init(color: .white, location: 0.46),
                                             .init(color: .white, location: 0.78),
                                             .init(color: StoryTheme.generatingEnd, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
        )
        .clipShape(RoundedRectangle(cornerRadius: StoryTheme.Radius.cardLarge, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: StoryTheme.Radius.cardLarge, style: .continuous).strokeBorder(StoryTheme.pinkBorder, lineWidth: 1))
        .storyShadow(.pink(opacity: 0.16, radius: 28, y: 10))
        .onAppear {
            // 表示時だけ 0.6 秒で舞い落ちて止まる（Reduce Motion のときは静止）
            if reduceMotion { confettiLanded = true } else {
                withAnimation(.easeOut(duration: 0.6)) { confettiLanded = true }
            }
        }
    }

    /// 控えめな紙吹雪（角丸片と点を5つ＋sparkle 2つ）
    private var confetti: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack(alignment: .topLeading) {
                piece(Color(hex: "FFB8C9"), width: 8, height: 4, angle: -28, x: 70, y: 26)
                piece(Color(hex: "C9B8EE"), width: 6, height: 6, angle: 0, x: 96, y: 62, circle: true)
                piece(Color(hex: "AFCDE6"), width: 9, height: 4, angle: 32, x: w - 78 - 9, y: 22)
                piece(Color(hex: "F5CFA0"), width: 7, height: 4, angle: -12, x: w - 64 - 7, y: 70)
                piece(Color(hex: "FFD3DF"), width: 5, height: 5, angle: 0, x: 48, y: 88, circle: true)
                SparkleShape().fill(StoryTheme.chevron).frame(width: 11, height: 11)
                    .offset(x: w - 104 - 13, y: confettiLanded ? 46 : 20)
                SparkleShape().fill(Color(hex: "C9B8EE")).frame(width: 8, height: 8)
                    .offset(x: 120, y: confettiLanded ? 22 : 0)
            }
            .opacity(confettiLanded ? 1 : 0)
        }
        .accessibilityHidden(true)
    }

    private func piece(_ color: Color, width: CGFloat, height: CGFloat, angle: Double, x: CGFloat, y: CGFloat,
                       circle: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: circle ? width / 2 : 2, style: .continuous)
            .fill(color)
            .frame(width: width, height: height)
            .rotationEffect(.degrees(confettiLanded ? angle : angle - 40))
            .offset(x: x, y: confettiLanded ? y : y - 24)
    }
}

/// 完結カードの下の案内
struct StoryRereadHint: View {
    var body: some View {
        Label {
            Text(StoryText.text("story_scroll_hint"))
        } icon: {
            Image(systemName: "arrow.up").font(.system(size: 11, weight: .semibold)).foregroundColor(StoryTheme.placeholder)
        }
        .font(.storyCaption)
        .foregroundColor(StoryTheme.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

#if DEBUG
private struct StoryChoicePanelPreview: View {
    @State var draft: StoryActionDraft
    var body: some View {
        ScrollView {
            StoryChoicePanel(choices: StoryPreviewData.scene(1).choices, draft: $draft).padding(20)
        }
        .background(StoryTheme.background)
    }
}

#Preview("選択肢｜選択中") { StoryChoicePanelPreview(draft: StoryActionDraft(choice: 1)) }
#Preview("選択肢｜自由入力優先") { StoryChoicePanelPreview(draft: StoryActionDraft(choice: 1, text: "その前に、みんなで屋上に行ってみない？と誘う")) }

#Preview("章間・完結") {
    ScrollView {
        VStack(spacing: 14) {
            StoryChapterTransition(episode: 1, intent: "みんなの意見を一度整理して、もう一度話し合う", onNext: {}, onChange: {})
            StoryEndingDivider()
            StoryCompletionCard(cast: StoryPreviewData.cast, onReread: {}, onBackToLibrary: {})
            StoryRereadHint()
        }
        .padding(20)
    }
    .background(StoryTheme.background)
}
#endif
