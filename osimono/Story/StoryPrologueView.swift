import SwiftUI

/// 物語の扉（保存後・最初の場面の生成前）。本の表紙風カード＋あらすじ＋進行イメージ。
struct StoryPrologueContent: View {
    var configuration: StoryConfiguration

    /// 主役（一員モードの主役の推し）を先頭にした出演者
    private var orderedCast: [StoryCharacter] {
        guard let leadID = configuration.leadID,
              let lead = configuration.cast.first(where: { $0.id == leadID }) else { return configuration.cast }
        return [lead] + configuration.cast.filter { $0.id != leadID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover
            synopsis.padding(.top, 20)
            StoryJourneyCard().padding(.top, 16)
        }
    }

    // MARK: 表紙

    private var cover: some View {
        ZStack(alignment: .topLeading) {
            // 背面のページの重なり
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(StoryTheme.border, lineWidth: 1))
                .padding(.leading, 10).padding(.top, 8)
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).strokeBorder(StoryTheme.border, lineWidth: 1))
                .padding(.leading, 6).padding(.top, 4).padding(.trailing, 4).padding(.bottom, 4)
            coverFace
                .padding(.trailing, 8).padding(.bottom, 8)
        }
    }

    private var coverFace: some View {
        HStack(spacing: 0) {
            // 背表紙
            LinearGradient(colors: [StoryTheme.primaryStart, StoryTheme.primaryEnd], startPoint: .top, endPoint: .bottom)
                .frame(width: 14)
                .overlay(alignment: .trailing) { Color.white.opacity(0.35).frame(width: 2) }
                .accessibilityHidden(true)
            VStack(spacing: 0) {
                StorySceneryImage(backdrop: StoryBackdrop.opening(for: configuration.setting))
                    .frame(height: 160)
                coverDetails
            }
            .frame(maxWidth: .infinity)
        }
        .frame(minHeight: 272)
        .background(
            LinearGradient(stops: [.init(color: Color(hex: "FFE7EF"), location: 0),
                                   .init(color: StoryTheme.softPink, location: 0.4),
                                   .init(color: StoryTheme.softPurple, location: 1)],
                           startPoint: UnitPoint(x: 0.25, y: 0), endPoint: UnitPoint(x: 0.75, y: 1))
        )
        .clipShape(RoundedRectangle(cornerRadius: StoryTheme.Radius.card, style: .continuous))
        .storyShadow(.pink(opacity: 0.16, radius: 28, y: 10))
        .accessibilityElement(children: .combine)
    }

    private var coverDetails: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Rectangle().fill(Color(hex: "FFB8C9")).frame(width: 18, height: 1)
                Text(StoryText.text("story_prologue_badge"))
                    .font(.storyCaption.weight(.bold))
                    .kerning(1.4)
                    .foregroundColor(StoryTheme.pinkText)
                Rectangle().fill(Color(hex: "FFB8C9")).frame(width: 18, height: 1)
            }
            AvatarStack(characters: orderedCast, size: 68, borderWidth: 2, overlap: 12, highlightsFirst: true)
                .shadow(color: StoryTheme.primaryStart.opacity(0.18), radius: 6, y: 4)
                .padding(.top, 20)
            Text(configuration.cast.map(\.name).joined(separator: StoryText.text("story_name_separator")))
                .font(.storyHeadline.weight(.bold))
                .kerning(0.3)
                .foregroundColor(StoryTheme.text)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
            Text(StoryText.text("story_prologue_with_you"))
                .font(.storyFootnote)
                .foregroundColor(StoryTheme.body)
                .padding(.top, 2)
            StoryFlowLayout(spacing: 6) {
                chip(icon: configuration.setting.symbol, label: StoryText.text("story_chip_setting"),
                     value: StoryText.text(configuration.setting.titleKey))
                chip(icon: "sparkles", label: StoryText.text("story_chip_mood"),
                     value: StoryText.text("story_mood_" + configuration.mood.rawValue))
                chip(icon: "person.3.fill", label: StoryText.text("story_chip_participation"),
                     value: StoryText.text("story_participation_short_" + configuration.participation.rawValue),
                     isPurple: true)
            }
            .padding(.top, 16)
        }
        .padding(.top, 22).padding(.horizontal, 20).padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(alignment: .topLeading) { coverDecorations }
    }

    private var coverDecorations: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                SparkleShape().fill(Color.white).frame(width: 17, height: 17).offset(x: 26, y: 62)
                SparkleShape().fill(Color(hex: "C9B8EE")).frame(width: 9, height: 9).offset(x: proxy.size.width - 42, y: 53)
                SparkleShape().fill(Color(hex: "FFB8C9")).frame(width: 12, height: 12).offset(x: proxy.size.width - 67, y: 138)
                Circle().fill(Color(hex: "C9B8EE")).frame(width: 4, height: 4).offset(x: 44, y: 128)
            }
        }
        .accessibilityHidden(true)
    }

    private func chip(icon: String, label: String, value: String, isPurple: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isPurple ? Color(hex: "8E77C7") : Color(hex: "E85A7A"))
                .accessibilityHidden(true)
            Text(label).foregroundColor(StoryTheme.secondary)
            Text(value).foregroundColor(StoryTheme.text)
        }
        .font(.storyFootnote)
        .padding(.horizontal, 10)
        .frame(minHeight: 30)
        .background(Capsule().fill(Color.white.opacity(0.85)))
        .overlay(Capsule().strokeBorder(isPurple ? StoryTheme.noticeBorder : Color(hex: "F3E1EA"), lineWidth: 1))
    }

    // MARK: あらすじ

    private var synopsis: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "book.fill").font(.system(size: 13)).foregroundColor(StoryTheme.chevron)
                    .accessibilityHidden(true)
                Text(StoryText.text("story_synopsis_label"))
                    .font(.storyFootnote.weight(.bold))
                    .kerning(0.5)
                    .foregroundColor(StoryTheme.pinkText)
            }
            .accessibilityAddTraits(.isHeader)
            Text(configuration.synopsis)
                .font(.storyBody)
                .foregroundColor(StoryTheme.text)
                .storyLineHeight(1.8, fontSize: 16, relativeTo: .callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 16).padding(.horizontal, 18).padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .storyCardSurface(radius: StoryTheme.Radius.cardSmall)
        .storyShadow(.normal)
    }
}

/// 全3話・9場面の進行イメージ（扉用・まだ何も読んでいない状態）
struct StoryJourneyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(StoryText.text("story_prologue_scenes"))
                    .font(.storySubheadline.weight(.semibold))
                    .foregroundColor(StoryTheme.text)
                Spacer()
                Text(String(format: StoryText.text("story_prologue_count"), 0))
                    .font(.storyCaption)
                    .foregroundColor(StoryTheme.secondary)
            }
            HStack(alignment: .top, spacing: 10) {
                ForEach(1...3, id: \.self) { episode in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(format: StoryText.text("story_episode_label"), episode))
                            .font(.storyCaption.weight(.semibold))
                            .foregroundColor(episode == 1 ? StoryTheme.pinkText : StoryTheme.secondary)
                        rail(episode: episode)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Text(StoryText.text("story_prologue_start_hint"))
                .font(.storyFootnote)
                .foregroundColor(StoryTheme.body)
        }
        .padding(.top, 14).padding(.horizontal, 16).padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .storyCardSurface(radius: StoryTheme.Radius.cardSmall)
        .storyShadow(.normal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StoryText.text("story_prologue_a11y"))
    }

    private func rail(episode: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { scene in
                if scene > 0 {
                    Capsule().fill(StoryTheme.border).frame(height: 2)
                }
                if episode == 1 && scene == 0 {
                    // 開始地点：グラデ16pt＋淡いハロー
                    Circle().fill(StoryTheme.diagonalGradient)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color(hex: "FFE3EC")).padding(-4))
                } else if episode == 3 && scene == 2 {
                    SparkleShape().fill(Color(hex: "C9B8EE")).frame(width: 12, height: 12)
                } else {
                    Circle().fill(StoryTheme.border).frame(width: 10, height: 10)
                }
            }
        }
        .frame(height: 16)
        .padding(.leading, episode == 1 ? 4 : 0)
    }
}

/// 折り返して並べるレイアウト（設定チップ用）
struct StoryFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews: subviews, width: proposal.width ?? .infinity)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * spacing
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews: subviews, width: bounds.width) {
            // 各行を中央寄せ
            var x = bounds.minX + (bounds.width - row.width) / 2
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width && !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

extension StorySetting {
    /// 扉・作成画面で使う舞台のアイコン
    var symbol: String {
        switch self {
        case .school: return "graduationcap"
        case .house: return "house"
        case .fantasy: return "wand.and.stars"
        }
    }
}

#if DEBUG
#Preview("物語の扉") {
    ScrollView {
        StoryPrologueContent(configuration: StoryPreviewData.configuration())
            .padding(.horizontal, StoryTheme.gutter)
            .padding(.top, 12)
    }
    .background(StoryTheme.background)
}
#endif
