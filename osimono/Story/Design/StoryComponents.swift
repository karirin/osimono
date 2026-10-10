import SwiftUI

// MARK: - Sparkle

/// 4点のきらめき（モックの sparkle パス M12 2l1.8 6.2L20 10…）。
struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2, ry = rect.height / 2
        let kx = rx * 0.225, ky = ry * 0.225
        var path = Path()
        path.move(to: CGPoint(x: c.x, y: c.y - ry))
        path.addLine(to: CGPoint(x: c.x + kx, y: c.y - ky))
        path.addLine(to: CGPoint(x: c.x + rx, y: c.y))
        path.addLine(to: CGPoint(x: c.x + kx, y: c.y + ky))
        path.addLine(to: CGPoint(x: c.x, y: c.y + ry))
        path.addLine(to: CGPoint(x: c.x - kx, y: c.y + ky))
        path.addLine(to: CGPoint(x: c.x - rx, y: c.y))
        path.addLine(to: CGPoint(x: c.x - kx, y: c.y - ky))
        path.closeSubpath()
        return path
    }
}

// MARK: - OshiAvatar

/// 推しの円形アバター。画像が無い・読めないときは person.fill。
struct OshiAvatar: View {
    enum Ring: Equatable {
        case none
        case gradient
        case plain(Color)
    }

    var imageURL: String?
    /// 未設定時の配色を安定させるための値（推しID）
    var seed: String = ""
    var size: CGFloat = 44
    var ring: Ring = .none
    /// 白フチの太さ（リングなしのとき外周、リングありのとき内周）
    var borderWidth: CGFloat = 0
    /// 選択順バッジ（1始まり）
    var order: Int? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ringed
                .frame(width: size, height: size)
            if let order {
                Text("\(order)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(StoryTheme.diagonalGradient))
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                    .offset(x: 4, y: -4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private var ringed: some View {
        switch ring {
        case .none:
            photo.overlay(Circle().strokeBorder(Color.white, lineWidth: borderWidth))
        case .gradient:
            photo
                .overlay(Circle().strokeBorder(Color.white, lineWidth: borderWidth))
                .padding(3)
                .background(Circle().fill(StoryTheme.diagonalGradient))
        case .plain(let color):
            photo
                .overlay(Circle().strokeBorder(Color.white, lineWidth: borderWidth))
                .padding(3)
                .background(Circle().fill(color))
        }
    }

    private var photo: some View {
        let palette = Self.palette(for: seed)
        return GeometryReader { proxy in
            StoryAvatarImage(url: imageURL.flatMap(URL.init(string:))) {
                ZStack(alignment: .bottom) {
                    palette.background
                    Image(systemName: "person.fill")
                        .resizable().scaledToFit()
                        .foregroundColor(palette.foreground)
                        .frame(width: proxy.size.width * 0.62)
                        .offset(y: proxy.size.width * 0.08)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipShape(Circle())
    }

    private static let palettes: [(background: Color, foreground: Color)] = [
        (Color(hex: "FFE3EC"), Color(hex: "FFB8C9")),
        (Color(hex: "EDE5FB"), Color(hex: "C9B8EE")),
        (Color(hex: "E3F0FA"), Color(hex: "AFCDE6"))
    ]

    private static func palette(for seed: String) -> (background: Color, foreground: Color) {
        // hashValue は起動ごとに変わるため、文字コードの和で安定させる
        let sum = seed.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palettes[sum % palettes.count]
    }
}

extension OshiAvatar {
    init(character: StoryCharacter, size: CGFloat = 44, ring: Ring = .none, borderWidth: CGFloat = 0, order: Int? = nil) {
        self.init(imageURL: character.imageURL, seed: character.id, size: size, ring: ring,
                  borderWidth: borderWidth, order: order)
    }
}

// MARK: - AvatarStack

/// 1〜3人のアバターを白フチで重ねて表示する（装飾扱い）。
struct AvatarStack: View {
    var characters: [StoryCharacter]
    var size: CGFloat = 28
    var borderWidth: CGFloat = 2
    var overlap: CGFloat = 9
    /// 先頭（主役）をグラデリングにする
    var highlightsFirst = false

    var body: some View {
        HStack(spacing: -overlap) {
            ForEach(Array(characters.prefix(3).enumerated()), id: \.element.id) { index, character in
                OshiAvatar(character: character, size: size,
                           ring: highlightsFirst ? (index == 0 ? .gradient : .plain(.white)) : .none,
                           borderWidth: borderWidth)
                    .zIndex(Double(3 - index))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Buttons

/// 押下時に少し縮むスタイル（0.98・0.12s）
struct StoryPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 56pt・グラデーションのCTA。無効時は #ECE6EF / #A69DB0・影なし。
struct StoryPrimaryButton: View {
    var title: String
    var systemImage: String? = nil
    /// plus.circle.fill などは円が淡く・記号が白くなる（モックの半透明の円）
    var symbolRendering: SymbolRenderingMode = .hierarchical
    /// 文字の後ろに置くアイコン（「次の話へ →」など）
    var trailingSystemImage: String? = nil
    var isEnabled = true
    var height: CGFloat = 56
    var cornerRadius: CGFloat = StoryTheme.Radius.button
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .symbolRenderingMode(symbolRendering)
                        .font(.body.weight(.semibold))
                        .accessibilityHidden(true)
                }
                Text(title).font(.headline.weight(.bold)).kerning(0.3)
                    .fixedSize(horizontal: false, vertical: true)
                if let trailingSystemImage {
                    Image(systemName: trailingSystemImage)
                        .font(.body.weight(.semibold))
                        .accessibilityHidden(true)
                }
            }
            .foregroundColor(isEnabled ? .white : StoryTheme.disabledText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isEnabled ? AnyShapeStyle(StoryTheme.gradient) : AnyShapeStyle(StoryTheme.disabledFill))
            )
            .shadow(color: StoryTheme.primaryStart.opacity(isEnabled ? 0.32 : 0), radius: 10, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(StoryPressableStyle())
        .disabled(!isEnabled)
    }
}

/// 44pt の背景なしテキストボタン。
struct SecondaryTextButton: View {
    var title: String
    var systemImage: String? = nil
    var color: Color = StoryTheme.secondary
    var font: Font = .headline
    var height: CGFloat = 44
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage).font(.subheadline.weight(.semibold)).accessibilityHidden(true)
                }
                Text(title).font(font)
            }
            .foregroundColor(color)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SceneProgressBar

/// 3話×3場面の9本バー。読了 #FF7A95／現在 #FFC2D1／未読 #ECE6EF。
struct SceneProgressBar: View {
    /// 読了した場面数（0...9）
    var readCount: Int
    /// 現在読んでいる場面（0...8）。完結時は nil
    var currentIndex: Int?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { episode in
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { scene in
                        Capsule().fill(color(for: episode * 3 + scene)).frame(height: 4)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func color(for index: Int) -> Color {
        if index == currentIndex { return StoryTheme.progressCurrent }
        return index < readCount ? StoryTheme.progressRead : StoryTheme.border
    }

    private var accessibilityText: String {
        if let currentIndex {
            return String(format: StoryText.text("story_progress_a11y"), currentIndex + 1)
        }
        return readCount >= 9 ? StoryText.text("story_progress_complete_a11y")
            : String(format: StoryText.text("story_progress_a11y"), readCount)
    }
}

// MARK: - SceneDivider

/// 細線＋「場面 n」。現在の場面はピンク。
struct SceneDivider: View {
    var number: Int
    var isCurrent = false

    var body: some View {
        HStack(spacing: 10) {
            line
            Text(String(format: StoryText.text("story_scene_label"), number))
                .font(.storyCaption.weight(.semibold))
                .kerning(1)
                .foregroundColor(isCurrent ? StoryTheme.pinkText : StoryTheme.secondary)
                .fixedSize()
            line
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var line: some View {
        Rectangle().fill(StoryTheme.border).frame(height: 1).accessibilityHidden(true)
    }
}

// MARK: - 本文ブロック

/// 「未保存」タグ（保存エラー時の場面に付ける）
struct UnsavedTag: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill").font(.system(size: 11)).accessibilityHidden(true)
            Text(StoryText.text("story_unsaved")).font(.storyCaption.weight(.semibold))
        }
        .foregroundColor(StoryTheme.error)
        .padding(.horizontal, 8)
        .frame(minHeight: 22)
        .background(Capsule().fill(Color.white))
        .overlay(Capsule().strokeBorder(StoryTheme.unsavedBorder, lineWidth: 1))
    }
}

/// ナレーション：Soft purple・角丸18・15pt 行間1.8。
struct NarrationCard: View {
    var text: String
    /// 保存エラー時：破線枠＋右上に「未保存」
    var isUnsaved = false

    var body: some View {
        Text(text)
            .font(.storySubheadline)
            .foregroundColor(StoryTheme.narration)
            .storyLineHeight(1.8, fontSize: 15, relativeTo: .subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14).padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(StoryTheme.softPurple))
            .overlay {
                if isUnsaved {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(StoryTheme.unsavedBorder, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
            }
            .overlay(alignment: .topTrailing) {
                if isUnsaved { UnsavedTag().offset(x: -10, y: -11) }
            }
    }
}

/// 推しの台詞：アバター40＋名前13＋白カード（角丸 4/18/18/18・最大幅300）。
struct DialogueCard: View {
    var character: StoryCharacter
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            OshiAvatar(character: character, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(character.name)
                    .font(.storyFootnote.weight(.semibold))
                    .foregroundColor(StoryTheme.body)
                Text(text)
                    .font(.storyBody)
                    .foregroundColor(StoryTheme.text)
                    .storyLineHeight(1.7, fontSize: 16, relativeTo: .callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 12).padding(.horizontal, 14)
                    .background(bubble.fill(Color.white))
                    .overlay(bubble.strokeBorder(StoryTheme.border, lineWidth: 1))
                    .storyShadow(.normal)
            }
            .frame(maxWidth: 300, alignment: .leading)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var bubble: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 18, bottomTrailingRadius: 18,
                               topTrailingRadius: 18, style: .continuous)
    }
}

/// あなたの行動：右寄せ・Soft pink・角丸 18/4/18/18・上に「あなたの行動」ラベル。
struct UserActionCard: View {
    var text: String

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 11))
                        .foregroundColor(StoryTheme.chevron)
                        .accessibilityHidden(true)
                    Text(StoryText.text("story_user_action"))
                        .font(.storyCaption.weight(.semibold))
                        .foregroundColor(StoryTheme.pinkText)
                }
                Text(text)
                    .font(.storyBody)
                    .foregroundColor(StoryTheme.text)
                    .storyLineHeight(1.7, fontSize: 16, relativeTo: .callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 12).padding(.horizontal, 14)
                    .background(bubble.fill(StoryTheme.softPink))
                    .overlay(bubble.strokeBorder(StoryTheme.pinkBorder, lineWidth: 1))
            }
            .frame(maxWidth: 280, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private var bubble: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 18,
                               topTrailingRadius: 4, style: .continuous)
    }
}

// MARK: - StatusCard

/// 非同期処理の状態表示。本文の末尾に差し込む。
struct StatusCard: View {
    enum Kind: Equatable {
        case generating
        case saving
        /// keepsAction: 選んだ行動があり、再試行で同じ行動から作り直す
        case generationError(keepsAction: Bool)
        /// 保存できなかった場面番号（1...3）
        case saveError(sceneNumber: Int)
        case limit
        /// 再試行しても成功しない失敗（競合など）。理由を示して一覧へ戻す
        case needsReopen(message: String)
    }

    var kind: Kind
    var detail: String? = nil
    var onRetry: () -> Void = {}
    var onBackToLibrary: () -> Void = {}

    var canResolveLimit = true
    var isAdLoading = false
    var adRewardCount = 5
    var onUpgrade: () -> Void = {}
    var onWatchAd: () -> Void = {}

    @AccessibilityFocusState private var headingFocused: Bool

    var body: some View {
        Group {
            switch kind {
            case .generating: generating
            case .saving: saving
            case .generationError(let keepsAction):
                errorCard(title: StoryText.text("story_generation_error_title"),
                          message: (detail.map { $0 + "\n" } ?? "") + StoryText.text("story_generation_error_body")
                            + (keepsAction ? StoryText.text("story_generation_error_action_note") : ""),
                          note: nil)
            case .saveError(let number):
                errorCard(title: String(format: StoryText.text("story_save_error_title"), number),
                          message: StoryText.text("story_save_error_body"),
                          note: StoryText.text("story_save_error_note"))
            case .limit: limit
            case .needsReopen(let message):
                errorCard(title: StoryText.text("story_reopen_title"), message: message, note: nil,
                          buttonTitle: StoryText.text("story_back_to_library"), buttonIcon: nil,
                          action: onBackToLibrary)
            }
        }
        .onAppear(perform: announce)
        .onChange(of: kind) { _ in announce() }
    }

    private var announcement: String {
        switch kind {
        case .generating: return StoryText.text("story_generating")
        case .saving: return StoryText.text("story_saving")
        case .generationError: return StoryText.text("story_generation_error_title")
        case .saveError(let number): return String(format: StoryText.text("story_save_error_title"), number)
        case .limit: return StoryText.text("story_limit_title")
        case .needsReopen: return StoryText.text("story_reopen_title")
        }
    }

    private func announce() {
        switch kind {
        case .generationError, .saveError, .needsReopen:
            // エラーは見出しへフォーカスを移す（移動時に読み上げられる）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { headingFocused = true }
        default:
            StoryAccessibility.announce(announcement)
        }
    }

    private var generating: some View {
        VStack(spacing: 10) {
            StoryGeneratingIllustration().frame(width: 96, height: 64)
            StoryLoadingDots()
            Text(StoryText.text("story_generating"))
                .font(.storyBody.weight(.semibold))
                .foregroundColor(StoryTheme.text)
            Text(StoryText.text("story_generating_detail"))
                .font(.storyFootnote)
                .foregroundColor(StoryTheme.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 22).padding(.horizontal, 16).padding(.bottom, 20)
        .background(
            RoundedRectangle(cornerRadius: StoryTheme.Radius.card, style: .continuous)
                .fill(LinearGradient(colors: [.white, StoryTheme.generatingEnd], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: StoryTheme.Radius.card, style: .continuous).strokeBorder(StoryTheme.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var saving: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small).tint(StoryTheme.body)
            Text(StoryText.text("story_saving"))
                .font(.storyFootnote.weight(.semibold))
                .foregroundColor(StoryTheme.body)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 36)
        .background(Capsule().fill(Color.white))
        .overlay(Capsule().strokeBorder(StoryTheme.border, lineWidth: 1))
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func errorCard(title: String, message: String, note: String?,
                           buttonTitle: String = StoryText.text("story_retry"), buttonIcon: String? = "arrow.clockwise",
                           action: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(StoryTheme.error)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.storyBody.weight(.bold))
                    .foregroundColor(StoryTheme.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($headingFocused)
            Text(message)
                .storyFont(size: 14, relativeTo: .subheadline)
                .foregroundColor(StoryTheme.body)
                .storyLineHeight(1.65, fontSize: 14, relativeTo: .subheadline)
                .fixedSize(horizontal: false, vertical: true)
            StoryPrimaryButton(title: buttonTitle, systemImage: buttonIcon,
                               height: 52, cornerRadius: 16, action: action ?? onRetry)
                .padding(.top, 8)
            if let note {
                Text(note)
                    .font(.storyCaption)
                    .foregroundColor(StoryTheme.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 18).padding(.horizontal, 16).padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .storyCardSurface()
        .storyShadow(.normal)
    }

    private var limit: some View {
        VStack(spacing: 8) {
            Image(systemName: "hourglass")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(StoryTheme.purpleText)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.white))
                .accessibilityHidden(true)
            Text(StoryText.text("story_limit_title"))
                .font(.storyBody.weight(.bold))
                .foregroundColor(StoryTheme.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(StoryText.text("story_limit_body"))
                .storyFont(size: 14, relativeTo: .subheadline)
                .foregroundColor(StoryTheme.purpleText)
                .storyLineHeight(1.65, fontSize: 14, relativeTo: .subheadline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if canResolveLimit {
                Text(StoryText.text("story_limit_premium_body"))
                    .font(.storyFootnote.weight(.semibold))
                    .foregroundColor(StoryTheme.purpleText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                StoryPrimaryButton(title: StoryText.text("story_limit_upgrade"), systemImage: "crown.fill",
                                   isEnabled: !isAdLoading, action: onUpgrade)
                    .accessibilityIdentifier("story.limit.upgrade")
                    .padding(.top, 4)
                Button(action: onWatchAd) {
                    HStack(spacing: 8) {
                        if isAdLoading {
                            ProgressView().tint(StoryTheme.purpleText)
                        } else {
                            Image(systemName: "play.rectangle.fill").accessibilityHidden(true)
                        }
                        Text(isAdLoading ? StoryText.text("story_limit_ad_loading")
                             : String(format: StoryText.text("story_limit_watch_ad"), adRewardCount))
                            .font(.storyFootnote.weight(.semibold))
                    }
                    .foregroundColor(StoryTheme.purpleText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(StoryPressableStyle())
                .disabled(isAdLoading)
                .accessibilityIdentifier("story.limit.watchAd")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20).padding(.horizontal, 16)
        .storyCardSurface(fill: StoryTheme.softPurple, border: StoryTheme.noticeBorder)
        .accessibilityElement(children: .contain)
    }
}

/// 3つのドットが順に明滅する（1.2s周期・0.3sずらし）。Reduce Motion 時は静止。
struct StoryLoadingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content.accessibilityHidden(true)
    }

    @ViewBuilder private var content: some View {
        if reduceMotion {
            dots(Self.staticOpacities)
        } else {
            SwiftUI.TimelineView(.animation) { context in
                dots(Self.opacities(at: context.date.timeIntervalSinceReferenceDate))
            }
        }
    }

    private func dots(_ opacities: [Double]) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle().fill(StoryTheme.progressRead).frame(width: 7, height: 7).opacity(opacities[index])
            }
        }
    }

    private static let staticOpacities: [Double] = [1, 0.55, 0.25]

    /// 各ドットが 1 → 0.25 → 1 を 1.2 秒で往復し、0.3 秒ずつずれる
    private static func opacities(at time: Double) -> [Double] {
        (0..<3).map { index in
            let phase = (time - Double(index) * 0.3).truncatingRemainder(dividingBy: 1.2) / 1.2
            return 0.25 + 0.75 * (cos(phase * 2 * .pi) + 1) / 2
        }
    }
}

/// 開いた本＋めくれるページ＋sparkle（96×64 のモックSVGを再現）
struct StoryGeneratingIllustration: View {
    var body: some View {
        Canvas { context, size in
            let s = min(size.width / 96, size.height / 64)
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            let gradient = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [StoryTheme.primaryStart, StoryTheme.primaryEnd]),
                startPoint: p(18, 0), endPoint: p(78, 0))
            let pageStroke = GraphicsContext.Shading.color(Color(hex: "FFC6D4"))

            var cover = Path()
            cover.move(to: p(18, 52))
            cover.addCurve(to: p(48, 56), control1: p(28, 49), control2: p(38, 50))
            cover.addCurve(to: p(78, 52), control1: p(58, 50), control2: p(68, 49))
            cover.addLine(to: p(78, 56))
            cover.addCurve(to: p(48, 60), control1: p(68, 53), control2: p(58, 54))
            cover.addCurve(to: p(18, 56), control1: p(38, 54), control2: p(28, 53))
            cover.closeSubpath()
            context.fill(cover, with: gradient)

            var left = Path()
            left.move(to: p(48, 54))
            left.addCurve(to: p(20, 50), control1: p(39, 49), control2: p(29, 48))
            left.addLine(to: p(20, 22))
            left.addCurve(to: p(48, 26), control1: p(29, 20), control2: p(39, 21))
            left.closeSubpath()
            var right = Path()
            right.move(to: p(48, 54))
            right.addCurve(to: p(76, 50), control1: p(57, 49), control2: p(67, 48))
            right.addLine(to: p(76, 22))
            right.addCurve(to: p(48, 26), control1: p(67, 20), control2: p(57, 21))
            right.closeSubpath()
            for page in [left, right] {
                context.fill(page, with: .color(.white))
                context.stroke(page, with: pageStroke, style: StrokeStyle(lineWidth: 1.5 * s, lineJoin: .round))
            }

            var turning = Path()
            turning.move(to: p(48, 26))
            turning.addCurve(to: p(70, 18), control1: p(54, 20), control2: p(62, 17))
            turning.addCurve(to: p(48, 48), control1: p(70, 18), control2: p(64, 28))
            turning.closeSubpath()
            context.fill(turning, with: .color(StoryTheme.softPink))
            context.stroke(turning, with: pageStroke, style: StrokeStyle(lineWidth: 1.5 * s, lineJoin: .round))

            var lines = Path()
            for y: CGFloat in [32, 39] {
                lines.move(to: p(26, y))
                lines.addCurve(to: p(43, y + 2), control1: p(32, y - 1), control2: p(38, y))
            }
            context.stroke(lines, with: .color(StoryTheme.pinkBorder), style: StrokeStyle(lineWidth: 2 * s, lineCap: .round))

            context.fill(SparkleShape().path(in: CGRect(x: 39.5 * s, y: 4 * s, width: 17 * s, height: 17 * s)), with: gradient)
            context.fill(SparkleShape().path(in: CGRect(x: 68 * s, y: 8 * s, width: 8 * s, height: 8 * s)), with: .color(Color(hex: "C9B8EE")))
            context.fill(SparkleShape().path(in: CGRect(x: 20 * s, y: 12 * s, width: 8 * s, height: 8 * s)), with: .color(Color(hex: "FFB8C9")))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - 固定ボトムバー

/// 白86%＋.ultraThinMaterial・上0.5ptの線。`.safeAreaInset(edge: .bottom)` に置く。
struct StoryBottomBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 8) { content }
            .padding(.horizontal, StoryTheme.gutter)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Color.white.opacity(0.86)
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .overlay(alignment: .top) {
                Rectangle().fill(StoryTheme.border).frame(height: 0.5)
            }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("アバター・ボタン・進捗") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                OshiAvatar(character: StoryPreviewData.sakura, size: 68)
                OshiAvatar(character: StoryPreviewData.ren, size: 68, ring: .gradient, borderWidth: 2, order: 1)
                OshiAvatar(character: StoryPreviewData.mio, size: 68, ring: .plain(Color(hex: "F2EDF4")), order: 2)
            }
            HStack(spacing: 24) {
                AvatarStack(characters: StoryPreviewData.cast)
                AvatarStack(characters: StoryPreviewData.cast, size: 44, borderWidth: 3, overlap: 10)
                AvatarStack(characters: StoryPreviewData.cast, size: 52, borderWidth: 2, overlap: 12, highlightsFirst: true)
            }
            StoryPrimaryButton(title: "最初の場面へ", systemImage: "book.fill") {}
            StoryPrimaryButton(title: "この行動で進む", isEnabled: false) {}
            SecondaryTextButton(title: "行動を選び直す", systemImage: "arrow.uturn.backward") {}
            SceneProgressBar(readCount: 1, currentIndex: 1)
            SceneProgressBar(readCount: 5, currentIndex: 5)
            SceneProgressBar(readCount: 9, currentIndex: nil)
        }
        .padding(StoryTheme.gutter)
    }
    .background(StoryTheme.background)
}

#Preview("本文ブロック") {
    ScrollView {
        VStack(spacing: 14) {
            SceneDivider(number: 1)
            NarrationCard(text: StoryPreviewData.scene(0).narration)
            DialogueCard(character: StoryPreviewData.sakura, text: "ねえ、今年のクラス展示、このままでいいのかな。わたし、もっと思い出に残ることがしたい。")
            DialogueCard(character: StoryPreviewData.mio, text: "それなら、わたしも手伝う！")
            UserActionCard(text: "空き教室の鍵を借りて、放課後に集まろうと提案する")
            SceneDivider(number: 2, isCurrent: true)
            NarrationCard(text: StoryPreviewData.scene(1).narration, isUnsaved: true)
        }
        .padding(StoryTheme.gutter)
    }
    .background(StoryTheme.background)
}

#Preview("StatusCard") {
    ScrollView {
        VStack(spacing: 20) {
            StatusCard(kind: .generating)
            StatusCard(kind: .saving)
            StatusCard(kind: .generationError(keepsAction: true))
            StatusCard(kind: .saveError(sceneNumber: 3))
            StatusCard(kind: .limit)
        }
        .padding(StoryTheme.gutter)
    }
    .background(StoryTheme.background)
    .safeAreaInset(edge: .bottom) {
        StoryBottomBar {
            Label("生成が終わるまで操作できません", systemImage: "lock.fill")
                .font(.storyFootnote).foregroundColor(StoryTheme.secondary)
            StoryPrimaryButton(title: "この行動で進む", isEnabled: false) {}
        }
    }
}
#endif
