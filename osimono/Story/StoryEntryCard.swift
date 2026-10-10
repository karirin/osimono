import SwiftUI

/// チャット一覧のチャット行のあいだに置くストーリーモードの入口。カード全体が1つのボタン。
struct StoryEntryCard: View {
    /// 登録済みの推し（先頭から最大3人を表示）
    var cast: [StoryCharacter]
    var action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                icon
                VStack(alignment: .leading, spacing: 3) {
                    Text(StoryText.text("story_title"))
                        .font(.storyHeadline.weight(.bold))
                        .foregroundColor(StoryTheme.text)
                    Text(StoryText.text("story_entry_hint"))
                        .font(.storyFootnote)
                        .foregroundColor(StoryTheme.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // 推し0人・AXサイズではアバター群を出さずテキスト幅を広げる
                if !cast.isEmpty && !dynamicTypeSize.isAccessibilitySize {
                    AvatarStack(characters: cast, size: 28, borderWidth: 2, overlap: 9)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(StoryTheme.chevron)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 14)
            .padding(.leading, 16)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(StoryTheme.pinkBorder, lineWidth: 1))
            .storyShadow(.pink(opacity: 0.10, radius: 14, y: 4))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(StoryPressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StoryText.text("story_title") + " " + StoryText.text("story_entry_hint"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("story.entry")
    }

    private var icon: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(StoryTheme.diagonalGradient)
            .frame(width: 48, height: 48)
            .shadow(color: StoryTheme.primaryStart.opacity(0.28), radius: 5, y: 4)
            .overlay {
                Image(systemName: "book.fill").font(.system(size: 22)).foregroundColor(.white)
            }
            .overlay(alignment: .topTrailing) {
                // 白フチ付きの小さな sparkle
                ZStack {
                    SparkleShape().fill(Color.white).frame(width: 14, height: 14)
                    SparkleShape().fill(StoryTheme.sparklePurple).frame(width: 10.5, height: 10.5)
                }
                .offset(x: 10, y: -5)
            }
            .accessibilityHidden(true)
    }

    // 背景 #FFF0F5 → 白 → #F5F0FF（120°）＋淡い大きな sparkle
    private var background: some View {
        LinearGradient(stops: [.init(color: StoryTheme.softPink, location: 0),
                               .init(color: .white, location: 0.55),
                               .init(color: StoryTheme.softPurple, location: 1)],
                       startPoint: UnitPoint(x: 0, y: 0.2), endPoint: UnitPoint(x: 1, y: 0.8))
            .overlay(alignment: .topTrailing) {
                SparkleShape().fill(Color(hex: "E9DEFA"))
                    .frame(width: 43, height: 43)
                    .offset(x: -80, y: -13)
            }
    }
}

extension StoryEntryCard {
    /// チャット一覧の推しから、アバター表示用の最小限の情報だけを作る
    init(oshis: [Oshi], action: @escaping () -> Void) {
        self.init(cast: oshis.prefix(3).map {
            StoryCharacter(id: $0.id, name: $0.name, imageURL: $0.imageUrl, profile: [:], role: "")
        }, action: action)
    }
}

#if DEBUG
#Preview("入口カード") {
    VStack(spacing: 16) {
        StoryEntryCard(cast: StoryPreviewData.cast) {}
        StoryEntryCard(cast: []) {}
        StoryEntryCard(cast: StoryPreviewData.cast) {}
            .environment(\.dynamicTypeSize, .accessibility1)
    }
    .padding(StoryTheme.gutter)
    .background(StoryTheme.background)
}
#endif
