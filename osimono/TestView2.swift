//
//  TestView2.swift
//  osimono
//
//  Created by Apple on 2025/05/04.
//

import SwiftUI

struct EnhancedAnimatedTabView: View {
    @State private var selectedTab = 0
    @State private var dragOffset: CGFloat = 0
    @State private var scale: CGFloat = 1.0
    @State private var activeGesture: Bool = false
    @Namespace private var animation
    
    let tabs = ["ホーム", "検索", "通知", "プロフィール"]
    let colors: [Color] = [.blue, .green, .purple, .orange]
    let icons = ["house.fill", "magnifyingglass", "bell.fill", "person.circle.fill"]
    
    var body: some View {
        VStack(spacing: 0) {
            headerWithParallax
            
            mainContent
            
            advancedTabBar
        }
    }
    
    // パララックス効果付きヘッダー
    var headerWithParallax: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [
                    colors[selectedTab],
                    colors[selectedTab].opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 120)
            .offset(x: dragOffset * 0.3) // パララックス効果
            .scaleEffect(1 + abs(dragOffset * 0.001))
            
            // 装飾パーティクル
            ForEach(0..<10, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: CGFloat.random(in: 5...15))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...120)
                    )
                    .blur(radius: 2)
                    .offset(x: dragOffset * CGFloat.random(in: 0.1...0.5))
            }
            
            // タイトル
            Text(tabs[selectedTab])
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .offset(x: dragOffset * 0.1) // パララックス効果
                .scaleEffect(1 - abs(dragOffset * 0.001))
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    withAnimation(.easeOut(duration: 0.2)) {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring()) {
                        dragOffset = 0
                    }
                }
        )
    }
    
    // メインコンテンツエリア
    var mainContent: some View {
        ZStack {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                advancedTabContent(for: index)
                    .opacity(selectedTab == index ? 1 : 0)
                    .scaleEffect(selectedTab == index ? 1 : 0.8)
                    .offset(x: CGFloat(index - selectedTab) * UIScreen.main.bounds.width)
                    .rotation3DEffect(
                        .degrees(Double(dragOffset) * 0.5),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 1.0
                    )
                    .gesture(dragGestureForContent)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0), value: selectedTab)
        .gesture(dragGestureForContent)
    }
    
    // より高度なタブコンテンツ
    func advancedTabContent(for index: Int) -> some View {
        VStack(spacing: 20) {
            // アニメーションカード
            CardView(color: colors[index], icon: icons[index], title: tabs[index])
                .rotation3DEffect(
                    .degrees(Double(dragOffset) * -0.2),
                    axis: (x: 0, y: 1, z: 0)
                )
            
            // ダミーリスト
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(0..<5) { i in
                        ListItemView(index: i, color: colors[index])
                            .transition(.asymmetric(
                                insertion: .slide.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [colors[index].opacity(0.1), colors[index].opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // 高度なタブバー
    var advancedTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, _ in
                TabBarButton(
                    icon: icons[index],
                    title: tabs[index],
                    color: colors[index],
                    isSelected: selectedTab == index,
                    selectedTab: $selectedTab,
                    currentIndex: index,
                    animation: animation
                )
            }
        }
        .padding(.vertical, 10)
        .background(
            ZStack {
                // グラス効果
                BlurView(style: .systemMaterial)
                
                // 底部のライン
                LinearGradient(
                    colors: [Color.white.opacity(0.1), Color.clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 1)
                .offset(y: -1)
            }
        )
    }
    
    // コンテンツ用のドラッグジェスチャー
    var dragGestureForContent: some Gesture {
        DragGesture()
            .onChanged { value in
                withAnimation(.interactiveSpring()) {
                    dragOffset = value.translation.width
                    activeGesture = true
                }
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    let threshold: CGFloat = 50
                    let velocity = value.predictedEndTranslation.width
                    
                    if velocity > threshold && selectedTab > 0 {
                        selectedTab -= 1
                    } else if velocity < -threshold && selectedTab < tabs.count - 1 {
                        selectedTab += 1
                    }
                    
                    dragOffset = 0
                    activeGesture = false
                }
            }
    }
}

// タブバーボタンコンポーネント
struct TabBarButton: View {
    let icon: String
    let title: String
    let color: Color
    let isSelected: Bool
    @Binding var selectedTab: Int
    let currentIndex: Int
    let animation: Namespace.ID
    
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isSelected {
                    // アニメーション付き背景
                    RoundedRectangle(cornerRadius: 15)
                        .fill(color.opacity(0.2))
                        .frame(width: 45, height: 30)
                        .matchedGeometryEffect(id: "background", in: animation)
                }
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? color : .gray)
                    .scaleEffect(isSelected ? 1.2 : 1.0)
                    .rotationEffect(.degrees(isPressed ? 5 : 0))
            }
            
            Text(title)
                .font(.caption2)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundColor(isSelected ? color : .gray)
                .opacity(isSelected ? 1 : 0.6)
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .gesture(
            LongPressGesture(minimumDuration: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring()) {
                        isPressed = false
                        selectedTab = currentIndex
                    }
                }
        )
    }
}

// カードビューコンポーネント
struct CardView: View {
    let color: Color
    let icon: String
    let title: String
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 150)
                .shadow(color: color.opacity(0.3), radius: 15, y: 5)
            
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("最新のコンテンツ")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding()
        }
        .padding(.horizontal)
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// リストアイテムコンポーネント
struct ListItemView: View {
    let index: Int
    let color: Color
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 15) {
            Circle()
                .fill(color.opacity(0.8))
                .frame(width: 40, height: 40)
                .overlay(
                    Text("\(index + 1)")
                        .font(.headline)
                        .foregroundColor(.white)
                )
                .scaleEffect(isHovered ? 1.1 : 1.0)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("アイテム \(index + 1)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("説明テキスト...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .opacity(isHovered ? 1 : 0.5)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(isHovered ? 0.1 : 0.05))
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .gesture(
            DragGesture()
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isHovered = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring()) {
                        isHovered = false
                    }
                }
        )
    }
}

// ブラーエフェクト
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

#Preview {
    EnhancedAnimatedTabView()
}
