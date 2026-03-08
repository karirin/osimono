//
//  DesignSystem.swift
//  osimono
//
//  Modern Design System - 2025 Update
//

import SwiftUI

// MARK: - Design Tokens

struct DesignSystem {
    
    // MARK: - Colors
    
    struct Colors {
        // Primary Gradient
        static let primaryGradient = LinearGradient(
            colors: [
                Color(hex: "FF6B9D"),
                Color(hex: "C44AFF"),
                Color(hex: "7B68EE")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let primaryGradientReversed = LinearGradient(
            colors: [
                Color(hex: "7B68EE"),
                Color(hex: "C44AFF"),
                Color(hex: "FF6B9D")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        // Accent Colors
        static let primary = Color(hex: "FF6B9D")
        static let secondary = Color(hex: "C44AFF")
        static let tertiary = Color(hex: "7B68EE")
        
        // Semantic Colors
        static let success = Color(hex: "4ECDC4")
        static let warning = Color(hex: "FFE66D")
        static let error = Color(hex: "FF6B6B")
        
        // Neutral Colors
        static let background = Color(hex: "FAFAFA")
        static let surface = Color.white
        static let surfaceSecondary = Color(hex: "F5F5F7")
        static let textPrimary = Color(hex: "1A1A2E")
        static let textSecondary = Color(hex: "6B7280")
        static let textTertiary = Color(hex: "9CA3AF")
        static let border = Color(hex: "E5E7EB")
        
        // Dark Mode Variants
        static let darkBackground = Color(hex: "0F0F23")
        static let darkSurface = Color(hex: "1A1A2E")
        static let darkSurfaceSecondary = Color(hex: "252542")
        
        // Glass Effect
        static let glassBackground = Color.white.opacity(0.15)
        static let glassBorder = Color.white.opacity(0.2)
        
        // Category Colors
        static let goods = Color(hex: "FF6B9D")
        static let pilgrimage = Color(hex: "4ECDC4")
        static let liveRecord = Color(hex: "FFB347")
        static let snsPost = Color(hex: "9B59B6")
        static let other = Color(hex: "6B7280")
    }
    
    // MARK: - Typography
    
    struct Typography {
        // Display
        static func displayLarge() -> Font {
            .system(size: 34, weight: .bold, design: .rounded)
        }
        
        static func displayMedium() -> Font {
            .system(size: 28, weight: .bold, design: .rounded)
        }
        
        static func displaySmall() -> Font {
            .system(size: 24, weight: .semibold, design: .rounded)
        }
        
        // Headlines
        static func headlineLarge() -> Font {
            .system(size: 20, weight: .semibold, design: .rounded)
        }
        
        static func headlineMedium() -> Font {
            .system(size: 18, weight: .semibold, design: .rounded)
        }
        
        static func headlineSmall() -> Font {
            .system(size: 16, weight: .semibold, design: .rounded)
        }
        
        // Body
        static func bodyLarge() -> Font {
            .system(size: 16, weight: .regular, design: .rounded)
        }
        
        static func bodyMedium() -> Font {
            .system(size: 14, weight: .regular, design: .rounded)
        }
        
        static func bodySmall() -> Font {
            .system(size: 12, weight: .regular, design: .rounded)
        }
        
        // Labels
        static func labelLarge() -> Font {
            .system(size: 14, weight: .medium, design: .rounded)
        }
        
        static func labelMedium() -> Font {
            .system(size: 12, weight: .medium, design: .rounded)
        }
        
        static func labelSmall() -> Font {
            .system(size: 10, weight: .medium, design: .rounded)
        }
    }
    
    // MARK: - Spacing
    
    struct Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }
    
    // MARK: - Radius
    
    struct Radius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let full: CGFloat = 9999
    }
    
    // MARK: - Shadows
    
    struct Shadows {
        static let small = Shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        static let medium = Shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        static let large = Shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 8)
        static let glow = Shadow(color: Colors.primary.opacity(0.3), radius: 20, x: 0, y: 4)
    }
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    
    // MARK: - Animation
    
    struct Animation {
        static let quick = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let smooth = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
        static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
        static let gentle = SwiftUI.Animation.easeInOut(duration: 0.3)
    }
}

// MARK: - Custom View Modifiers

struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = DesignSystem.Radius.lg
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
                }
            )
    }
}

struct ModernCard: ViewModifier {
    var padding: CGFloat = DesignSystem.Spacing.md
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                    .fill(DesignSystem.Colors.surface)
                    .shadow(
                        color: Color.black.opacity(0.05),
                        radius: 12,
                        x: 0,
                        y: 4
                    )
            )
    }
}

struct PrimaryButton: ViewModifier {
    var isDisabled: Bool = false
    
    func body(content: Content) -> some View {
        content
            .font(DesignSystem.Typography.labelLarge())
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                Capsule()
                    .fill(
                        isDisabled
                        ? AnyShapeStyle(Color.gray)
                        : AnyShapeStyle(DesignSystem.Colors.primaryGradient)
                    )
            )
            .shadow(
                color: DesignSystem.Colors.primary.opacity(isDisabled ? 0 : 0.3),
                radius: 12,
                x: 0,
                y: 6
            )
    }
}

struct FloatingActionButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 24, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 60, height: 60)
            .background(
                Circle()
                    .fill(DesignSystem.Colors.primaryGradient)
            )
            .shadow(
                color: DesignSystem.Colors.primary.opacity(0.4),
                radius: 16,
                x: 0,
                y: 8
            )
    }
}

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.5),
                            Color.white.opacity(0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + phase * geometry.size.width * 2)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    SwiftUI.Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    func glassBackground(cornerRadius: CGFloat = DesignSystem.Radius.lg) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }
    
    func modernCard(padding: CGFloat = DesignSystem.Spacing.md) -> some View {
        modifier(ModernCard(padding: padding))
    }
    
    func primaryButton(isDisabled: Bool = false) -> some View {
        modifier(PrimaryButton(isDisabled: isDisabled))
    }
    
    func floatingActionButton() -> some View {
        modifier(FloatingActionButton())
    }
    
    func shimmerLoading() -> some View {
        modifier(ShimmerEffect())
    }
    
    func applyShadow(_ shadow: DesignSystem.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - Reusable Components

struct ModernSearchBar: View {
    @Binding var text: String
    var placeholder: String = "検索..."
    var onClear: (() -> Void)?
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textTertiary)
            
            TextField(placeholder, text: $text)
                .font(DesignSystem.Typography.bodyMedium())
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    onClear?()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.surfaceSecondary)
        )
    }
}

struct ModernChip: View {
    let text: String
    let icon: String?
    let color: Color
    let isSelected: Bool
    var action: (() -> Void)?
    
    init(
        text: String,
        icon: String? = nil,
        color: Color = DesignSystem.Colors.primary,
        isSelected: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.text = text
        self.icon = icon
        self.color = color
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                
                Text(text)
                    .font(DesignSystem.Typography.labelMedium())
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}

struct ModernBadge: View {
    let count: Int
    var maxCount: Int = 99
    
    var displayText: String {
        count > maxCount ? "\(maxCount)+" : "\(count)"
    }
    
    var body: some View {
        if count > 0 {
            Text(displayText)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, count > 9 ? 6 : 0)
                .frame(minWidth: 18, minHeight: 18)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.error)
                )
        }
    }
}

struct ModernEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String?
    var action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(DesignSystem.Colors.primaryGradient)
            }
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.headlineMedium())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(message)
                    .font(DesignSystem.Typography.bodyMedium())
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if let buttonTitle = buttonTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "plus")
                        Text(buttonTitle)
                    }
                }
                .primaryButton()
                .padding(.top, DesignSystem.Spacing.xs)
            }
        }
        .padding(DesignSystem.Spacing.xl)
    }
}

struct ModernLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.primary.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        DesignSystem.Colors.primaryGradient,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
            }
            
            Text("読み込み中...")
                .font(DesignSystem.Typography.bodyMedium())
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .onAppear {
            withAnimation(
                SwiftUI.Animation.linear(duration: 1)
                    .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ModernSearchBar(text: .constant(""))
        
        HStack {
            ModernChip(text: "グッズ", icon: "gift.fill", color: DesignSystem.Colors.goods, isSelected: true)
            ModernChip(text: "聖地巡礼", icon: "mappin", color: DesignSystem.Colors.pilgrimage)
            ModernChip(text: "ライブ", icon: "music.note", color: DesignSystem.Colors.liveRecord)
        }
        
        ModernBadge(count: 5)
        
        ModernEmptyState(
            icon: "star.fill",
            title: "まだ記録がありません",
            message: "推しのアイテムを追加して\nコレクションを始めましょう",
            buttonTitle: "追加する"
        ) {}
        
        ModernLoadingView()
    }
    .padding()
}
