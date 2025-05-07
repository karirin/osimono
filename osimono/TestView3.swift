//
//  TestView3.swift
//  osimono
//
//  Created by Apple on 2025/05/04.
//

import SwiftUI

struct ContentView1: View {
    @State private var selectedTab = 0
    @Namespace private var animation
    
    // タブの定義
    let tabs = ["ホーム", "検索", "プロフィール", "設定"]
    let icons = ["house", "magnifyingglass", "person", "gearshape"]
    let colors: [Color] = [.blue, .green, .purple, .orange]
    
    var body: some View {
        VStack(spacing: 0) {
            // メインコンテンツエリア
            TabView(selection: $selectedTab) {
//                ContentView()
//                    .tag(0)
                
                MapView(oshiId: "default")
                    .tag(1)
                
                TimelineView(oshiId: "default")
                    .tag(2)
                
                DiaryView(oshiId: "default")
                    .tag(3)
                
//                SettingsView()
//                    .tag(4)
            }
            .animation(.easeInOut, value: selectedTab)
            
            // 下部のカスタムタブバー
            advancedTabBar
        }
    }
    
    var advancedTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, _ in
                TabBarButton1(
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
                BlurView1(style: .systemMaterial)
                
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
}

// カスタムタブバーボタン（修正版）
struct TabBarButton1: View {
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

// BlurViewの実装
struct BlurView1: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// 各ページのビュー
struct HomePageView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("ホームページ")
                    .font(.largeTitle)
                    .bold()
                Spacer()
            }
            .navigationTitle("ホーム")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
    }
}

struct SearchPageView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("検索ページ")
                    .font(.largeTitle)
                    .bold()
                Spacer()
            }
            .navigationTitle("検索")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
    }
}

struct ProfilePageView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("プロフィールページ")
                    .font(.largeTitle)
                    .bold()
                Spacer()
            }
            .navigationTitle("プロフィール")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
    }
}

struct SettingsPageView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("設定ページ")
                    .font(.largeTitle)
                    .bold()
                Spacer()
            }
            .navigationTitle("設定")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
    }
}

// プレビュー
struct ContentView1_Previews: PreviewProvider {
    static var previews: some View {
        ContentView1()
    }
}
