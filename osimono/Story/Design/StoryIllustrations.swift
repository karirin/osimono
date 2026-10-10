import SwiftUI

/// 空状態のイラスト（260×220 のモックSVGをコードで再現）。装飾扱い。
struct StoryEmptyIllustration: View {
    enum Kind {
        /// 本・星・3人のアバター
        case noStories
        /// アバターが破線の空席＋「＋」（キャスト募集中）
        case noOshi
    }

    var kind: Kind

    var body: some View {
        Canvas { context, size in
            let s = min(size.width / 260, size.height / 220)
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: (x - r) * s, y: (y - r) * s, width: r * 2 * s, height: r * 2 * s))
            }
            func sparkle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
                SparkleShape().path(in: CGRect(x: (x - r) * s, y: (y - r) * s, width: r * 2 * s, height: r * 2 * s))
            }
            let pink = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [StoryTheme.primaryStart, StoryTheme.primaryEnd]), startPoint: p(64, 0), endPoint: p(196, 0))

            // 背景の円と白の点線円
            context.fill(circle(130, 118, 98), with: .linearGradient(
                Gradient(colors: [StoryTheme.softPink, StoryTheme.softPurple]), startPoint: p(32, 20), endPoint: p(228, 216)))
            context.stroke(circle(130, 118, 78), with: .color(.white),
                           style: StrokeStyle(lineWidth: 1.5 * s, lineCap: .round, dash: [2 * s, 7 * s]))

            // 開いた本：表紙
            var cover = Path()
            cover.move(to: p(64, 166))
            cover.addCurve(to: p(130, 174), control1: p(92, 161), control2: p(112, 163))
            cover.addCurve(to: p(196, 166), control1: p(148, 163), control2: p(168, 161))
            cover.addLine(to: p(196, 173))
            cover.addCurve(to: p(130, 181), control1: p(168, 168), control2: p(148, 170))
            cover.addCurve(to: p(64, 173), control1: p(112, 170), control2: p(92, 168))
            cover.closeSubpath()
            context.fill(cover, with: pink)

            // ページ
            var left = Path()
            left.move(to: p(130, 170))
            left.addCurve(to: p(70, 162), control1: p(112, 160), control2: p(92, 158))
            left.addLine(to: p(70, 112))
            left.addCurve(to: p(130, 120), control1: p(92, 108), control2: p(112, 110))
            left.closeSubpath()
            var right = Path()
            right.move(to: p(130, 170))
            right.addCurve(to: p(190, 162), control1: p(148, 160), control2: p(168, 158))
            right.addLine(to: p(190, 112))
            right.addCurve(to: p(130, 120), control1: p(168, 108), control2: p(148, 110))
            right.closeSubpath()
            for page in [left, right] {
                context.fill(page, with: .color(.white))
                context.stroke(page, with: .color(Color(hex: "FFC6D4")), style: StrokeStyle(lineWidth: 1.5 * s, lineJoin: .round))
            }

            // ページの罫線
            let lineStyle = StrokeStyle(lineWidth: 2 * s, lineCap: .round)
            var leftLines = Path()
            for y: CGFloat in [128, 140] {
                leftLines.move(to: p(82, y))
                leftLines.addCurve(to: p(118, y + 4), control1: p(94, y - 2), control2: p(106, y - 1))
            }
            leftLines.move(to: p(82, 152))
            leftLines.addCurve(to: p(112, 155), control1: p(92, 151), control2: p(102, 152))
            context.stroke(leftLines, with: .color(StoryTheme.pinkBorder), style: lineStyle)
            var rightLines = Path()
            for y: CGFloat in [132, 144] {
                rightLines.move(to: p(142, y))
                rightLines.addCurve(to: p(178, y - 4), control1: p(154, y - 5), control2: p(166, y - 6))
            }
            rightLines.move(to: p(148, 155))
            rightLines.addCurve(to: p(178, 152), control1: p(158, 152), control2: p(168, 151))
            context.stroke(rightLines, with: .color(Color(hex: "EDE5FB")), style: lineStyle)

            // 星と点
            context.fill(sparkle(130, 86, 16), with: pink)
            context.fill(sparkle(104, 95, 7), with: .color(Color(hex: "C9B8EE")))
            context.fill(sparkle(160, 82, 6), with: .color(Color(hex: "FFB8C9")))
            context.fill(circle(170, 58, 2.5), with: .color(Color(hex: "C9B8EE")))
            context.fill(circle(92, 66, 2), with: .color(Color(hex: "FFB8C9")))
            context.fill(circle(214, 146, 2.5), with: .color(Color(hex: "FFB8C9")))
            context.fill(circle(44, 148, 2), with: .color(Color(hex: "C9B8EE")))

            // 人物
            switch kind {
            case .noStories:
                let people: [(x: CGFloat, y: CGFloat, r: CGFloat, bg: String, fg: String)] = [
                    (66, 102, 19, "FFE3EC", "FFB8C9"),
                    (194, 102, 19, "EDE5FB", "C9B8EE"),
                    (130, 42, 17, "E3F0FA", "AFCDE6")
                ]
                for person in people {
                    context.fill(circle(person.x, person.y, person.r + 2), with: .color(.white))
                    let face = circle(person.x, person.y, person.r)
                    context.fill(face, with: .color(Color(hex: person.bg)))
                    context.drawLayer { layer in
                        layer.clip(to: face)
                        let small = person.r < 19
                        let headR: CGFloat = small ? 6 : 7
                        let headY = person.y - (small ? 4 : 5)
                        let halfWidth: CGFloat = small ? 14 : 16
                        let bottom = person.y + (small ? 20 : 22)
                        let shoulder = person.y + 6
                        var body = Path()
                        body.move(to: p(person.x - halfWidth, bottom))
                        body.addCurve(to: p(person.x, shoulder),
                                      control1: p(person.x - halfWidth + 2, bottom - (small ? 10 : 11)),
                                      control2: p(person.x - (small ? 7 : 8), shoulder))
                        body.addCurve(to: p(person.x + halfWidth, bottom),
                                      control1: p(person.x + (small ? 7 : 8), shoulder),
                                      control2: p(person.x + halfWidth - 2, bottom - (small ? 10 : 11)))
                        body.closeSubpath()
                        let color = GraphicsContext.Shading.color(Color(hex: person.fg))
                        layer.fill(circle(person.x, headY, headR), with: color)
                        layer.fill(body, with: color)
                    }
                }
            case .noOshi:
                let seats: [(x: CGFloat, y: CGFloat, r: CGFloat, arm: CGFloat, stroke: String, plus: String)] = [
                    (66, 102, 20, 7, "F4B8C8", "FF8FA8"),
                    (194, 102, 20, 7, "D5C6EE", "A58BD8"),
                    (130, 42, 18, 6, "C3D8EC", "8DB3D6")
                ]
                for seat in seats {
                    let ring = circle(seat.x, seat.y, seat.r)
                    context.fill(ring, with: .color(.white))
                    context.stroke(ring, with: .color(Color(hex: seat.stroke)),
                                   style: StrokeStyle(lineWidth: 2 * s, dash: [4 * s, 4 * s]))
                    var plus = Path()
                    plus.move(to: p(seat.x, seat.y - seat.arm))
                    plus.addLine(to: p(seat.x, seat.y + seat.arm))
                    plus.move(to: p(seat.x - seat.arm, seat.y))
                    plus.addLine(to: p(seat.x + seat.arm, seat.y))
                    context.stroke(plus, with: .color(Color(hex: seat.plus)), style: StrokeStyle(lineWidth: 2.4 * s, lineCap: .round))
                }
            }
        }
        .frame(width: 260, height: 220)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("空状態イラスト") {
    VStack(spacing: 24) {
        StoryEmptyIllustration(kind: .noStories)
        StoryEmptyIllustration(kind: .noOshi)
    }
    .padding()
    .background(StoryTheme.background)
}
#endif
