import SwiftUI

/// ストーリーモードのデザイントークン（docs/design/story-mode/SPEC.md）。ライトモード専用。
enum StoryTheme {
    // MARK: - 色
    static let primaryStart = Color(hex: "FF758C")
    static let primaryEnd = Color(hex: "FF7EB3")
    static let background = Color(hex: "F8F9FD")
    static let surface = Color.white
    static let softPink = Color(hex: "FFF0F5")
    static let softPurple = Color(hex: "F5F0FF")
    static let text = Color(hex: "26232B")
    static let secondary = Color(hex: "8C8497")
    static let border = Color(hex: "ECE6EF")

    // 派生色
    static let body = Color(hex: "6E6578")
    static let pinkText = Color(hex: "D6456A")
    static let purpleText = Color(hex: "6E5A9E")
    static let narration = Color(hex: "4A4356")
    static let progressRead = Color(hex: "FF7A95")
    static let progressCurrent = Color(hex: "FFC2D1")
    static let error = Color(hex: "D93A55")
    static let disabledFill = Color(hex: "ECE6EF")
    static let disabledText = Color(hex: "A69DB0")

    // モック内で繰り返し使われる補助色
    static let pinkBorder = Color(hex: "F6DCE8")
    static let selectedBorder = Color(hex: "FF7A95")
    static let selectedFill = Color(hex: "FFF7FA")
    static let chevron = Color(hex: "FF8FA8")
    static let sparklePurple = Color(hex: "9B82D6")
    static let placeholder = Color(hex: "B3AABD")
    static let unsavedBorder = Color(hex: "F3C4CD")
    static let noticeBorder = Color(hex: "E6DDF5")
    static let generatingEnd = Color(hex: "F9F6FF")

    // MARK: - グラデーション
    /// ボタン・バー用（90°）
    static let gradient = LinearGradient(colors: [primaryStart, primaryEnd], startPoint: .leading, endPoint: .trailing)
    /// アイコン・バッジ用（135°）
    static let diagonalGradient = LinearGradient(colors: [primaryStart, primaryEnd], startPoint: .topLeading, endPoint: .bottomTrailing)

    // MARK: - 寸法
    static let gutter: CGFloat = 20
    static let minTapSize: CGFloat = 44
    static let bottomBarClearance: CGFloat = 150

    enum Radius {
        static let cardSmall: CGFloat = 18
        static let card: CGFloat = 22
        static let cardLarge: CGFloat = 24
        static let button: CGFloat = 18
        static let field: CGFloat = 14
    }
}

// MARK: - 影

enum StoryShadow {
    /// 0 2 10 #26232B 4%
    case normal
    /// 0 8 20 #FF758C 30%
    case emphasis
    /// 任意の不透明度のピンク影（カードごとの微調整用）
    case pink(opacity: Double, radius: CGFloat, y: CGFloat)
}

extension View {
    func storyShadow(_ style: StoryShadow) -> some View {
        switch style {
        case .normal:
            return shadow(color: StoryTheme.text.opacity(0.04), radius: 5, y: 2)
        case .emphasis:
            return shadow(color: StoryTheme.primaryStart.opacity(0.3), radius: 10, y: 8)
        case let .pink(opacity, radius, y):
            // CSSのblurはSwiftUIのradiusの約2倍
            return shadow(color: StoryTheme.primaryStart.opacity(opacity), radius: radius / 2, y: y)
        }
    }
}

// MARK: - 文字

extension Font {
    /// 見出し 22 Bold
    static let storyTitle2 = Font.title2.bold()
    /// 見出し 20 Bold
    static let storyTitle3 = Font.title3.bold()
    /// 見出し 17 Semibold
    static let storyHeadline = Font.headline
    /// 本文 16
    static let storyBody = Font.callout
    /// 本文 15
    static let storySubheadline = Font.subheadline
    /// 補足 13
    static let storyFootnote = Font.footnote
    /// 最小 12
    static let storyCaption = Font.caption
}

/// テキストスタイルに無いサイズ（14pt など）を Dynamic Type に追従させる。
private struct StoryScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}

extension View {
    func storyFont(size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> some View {
        modifier(StoryScaledFont(size: size, weight: weight, relativeTo: style))
    }
}

/// CSSの line-height（倍率）を Dynamic Type に追従する行間に変換する。
private struct StoryLineHeight: ViewModifier {
    @ScaledMetric private var spacing: CGFloat

    init(multiple: CGFloat, fontSize: CGFloat, relativeTo style: Font.TextStyle) {
        // システムフォントの既定の行の高さはおよそ 1.2 倍
        _spacing = ScaledMetric(wrappedValue: max(0, fontSize * (multiple - 1.2)), relativeTo: style)
    }

    func body(content: Content) -> some View {
        content.lineSpacing(spacing)
    }
}

extension View {
    func storyLineHeight(_ multiple: CGFloat, fontSize: CGFloat, relativeTo style: Font.TextStyle = .body) -> some View {
        modifier(StoryLineHeight(multiple: multiple, fontSize: fontSize, relativeTo: style))
    }
}

// MARK: - カード面

extension View {
    /// 白カード（角丸・枠1pt）
    func storyCardSurface(radius: CGFloat = StoryTheme.Radius.card, fill: Color = StoryTheme.surface,
                          border: Color = StoryTheme.border) -> some View {
        background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(border, lineWidth: 1))
    }
}

// MARK: - 読み上げ

enum StoryAccessibility {
    static func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
