//
//  OshiChatListView.swift
//  osimono
//
//  推しとのチャット一覧画面（削除機能付き）
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseDatabase
import FirebaseStorage

extension Color {
    static let oshiPrimary = Color(red: 1.0, green: 0.4, blue: 0.5)
    static let oshiSecondary = Color(red: 1.0, green: 0.6, blue: 0.7)
    static let oshiAccent = Color(red: 0.98, green: 0.3, blue: 0.45)
    static let oshiBackground = Color(red: 0.98, green: 0.97, blue: 0.98)
    static let oshiCardBg = Color.white
    static let oshiGlow = Color(red: 1.0, green: 0.5, blue: 0.6).opacity(0.4)
}

struct OshiChatListView: View {
    @StateObject private var coordinator = OshiChatCoordinator.shared
    @State private var searchText = ""
    @State private var oshiList: [Oshi] = []
    @State private var selectedOshiId: String = ""
    @State private var isLoading = true
    @State private var unreadCounts: [String: Int] = [:]
    @State private var lastMessages: [String: String] = [:]
    @State private var lastMessageTimes: [String: TimeInterval] = [:]
    @State private var showDeleteAlert = false
    @State private var oshiToDelete: Oshi?
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isEditing = false
    @State private var showAddOshiForm = false
    
    @State private var helpFlag = false
    @State private var customerFlag = false
    @ObservedObject var authManager = AuthManager()
    
    @State private var showDeleteOshiAlert = false
    @State private var oshiToDeleteCompletely: Oshi?
    @State private var isDeletingOshi = false
    
    // アニメーション用
    @State private var headerAppeared = false
    @State private var cardsAppeared = false
    
    // private let adminUserIds = [
    //     "3UDNienzhkdheKIy77lyjMJhY4D3",
    //     "bZwehJdm4RTQ7JWjl20yaxTWS7l2"
    // ]

    private func checkAdminStatus() {
        isAdmin = false
        isCheckingAdminStatus = false
    }
    
    @State private var isCheckingAdminStatus = true
    @StateObject private var subscriptionManager = SubscriptionManager()
    
    private var shouldShowAd: Bool {
        AdConfiguration.shouldShowAds(isAdmin: isAdmin, isSubscribed: subscriptionManager.isSubscribed)
    }
    
    @State private var isAdmin = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // グラデーション背景
                backgroundGradient
                
                VStack(spacing: 0) {
                    // モダンヘッダー
                    modernHeaderView
                    
                    // 広告表示
                    if shouldShowAd {
                        BannerAdChatListView()
                            .frame(height: 60)
                            .background(Color.white.opacity(0.8))
                    }
                    
                    // メインコンテンツ
                    if isLoading {
                        modernLoadingView
                    } else if oshiList.isEmpty {
                        modernEmptyStateView
                    } else {
                        modernChatListView
                    }
                }
                
                // 削除中オーバーレイ
                if isDeletingOshi {
                    deletingOverlay
                }
                
                // モーダル表示
                if helpFlag {
                    HelpModalView(isPresented: $helpFlag)
                }
                
                if customerFlag {
                    ReviewView(isPresented: $customerFlag, helpFlag: $helpFlag)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadData()
            withAnimation(.easeOut(duration: 0.6)) {
                headerAppeared = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                cardsAppeared = true
            }
            
            authManager.fetchUserFlag { userFlag, error in
                if let error = error {
                    print(error.localizedDescription)
                } else if let userFlag = userFlag {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        if userFlag == 0 {
                            executeProcessEveryThreeTimes()
                        }
                    }
                }
            }
        }
        .refreshable {
            loadData()
        }
        .alert("チャット履歴を削除", isPresented: $showDeleteAlert) {
            Button("削除", role: .destructive) {
                if let oshi = oshiToDelete {
                    deleteChatHistory(for: oshi)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(oshiToDelete?.name ?? "")とのチャット履歴を削除しますか？この操作は元に戻せません。")
        }
        .alert("推しを削除", isPresented: $showDeleteOshiAlert) {
            Button("削除", role: .destructive) {
                if let oshi = oshiToDeleteCompletely {
                    deleteOshiCompletely(oshi)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(oshiToDeleteCompletely?.name ?? "")を完全に削除しますか？この操作は元に戻せません。\n関連するチャット履歴やアイテム記録もすべて削除されます。")
        }
        .fullScreenCover(isPresented: $showAddOshiForm, onDismiss: {
            loadData()
        }) {
            AddOshiView()
        }
    }
    
    // MARK: - 背景グラデーション
    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.97, blue: 0.98),
                    Color(red: 0.98, green: 0.95, blue: 0.97),
                    Color(red: 0.96, green: 0.94, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // 装飾的な円形グラデーション
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.oshiPrimary.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
                .offset(x: 150, y: -200)
                .blur(radius: 60)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.08), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
                    )
                )
                .frame(width: 500, height: 500)
                .offset(x: -150, y: 400)
                .blur(radius: 50)
        }
    }
    
    // MARK: - モダンヘッダー
    private var modernHeaderView: some View {
        VStack(spacing: 0) {
            // メインヘッダー
            HStack(alignment: .center) {
                // 追加ボタン
                Button(action: {
                    generateHapticFeedback()
                    showAddOshiForm = true
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.oshiPrimary, Color.oshiAccent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .shadow(color: Color.oshiPrimary.opacity(0.4), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .scaleEffect(headerAppeared ? 1 : 0.5)
                .opacity(headerAppeared ? 1 : 0)
                
                Spacer()
                
                // タイトル
                VStack(spacing: 2) {
                    Text("チャット")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.oshiPrimary, Color.oshiAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    if !oshiList.isEmpty {
                        Text("\(oshiList.count)人の推し")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                .offset(y: headerAppeared ? 0 : -20)
                .opacity(headerAppeared ? 1 : 0)
                
                Spacer()
                
                // 編集ボタン
                if hasAnyChats {
                    Button(action: {
                        generateHapticFeedback()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            isEditing.toggle()
                        }
                    }) {
                        Text(isEditing ? "完了" : "編集")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(isEditing ? .white : Color.oshiPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(isEditing ?
                                          AnyShapeStyle(LinearGradient(colors: [Color.oshiPrimary, Color.oshiAccent], startPoint: .leading, endPoint: .trailing)) :
                                          AnyShapeStyle(Color.oshiPrimary.opacity(0.12)))
                            )
                    }
                    .scaleEffect(headerAppeared ? 1 : 0.5)
                    .opacity(headerAppeared ? 1 : 0)
                } else {
                    Spacer().frame(width: 60)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            // 検索バー
            if !oshiList.isEmpty {
                modernSearchBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .opacity(headerAppeared ? 1 : 0)
                    .offset(y: headerAppeared ? 0 : 10)
            }
        }
        .background(
            // グラスモーフィズム効果
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        )
    }
    
    // MARK: - モダン検索バー
    private var modernSearchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray.opacity(0.6))
            
            TextField("推しを検索", text: $searchText)
                .font(.system(size: 16))
                .foregroundColor(.primary)
            
            if !searchText.isEmpty {
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        searchText = ""
                    }
                    hideKeyboard()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.8))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - モダンローディング
    private var modernLoadingView: some View {
        VStack(spacing: 24) {
            // カスタムローディングアニメーション
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.oshiPrimary.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .offset(x: CGFloat(index - 1) * 24)
                        .scaleEffect(isLoading ? 1.2 : 0.8)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: isLoading
                        )
                }
            }
            
            Text("読み込み中...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - モダン空状態
    private var modernEmptyStateView: some View {
        VStack(spacing: 32) {
            // イラスト風アイコン
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.oshiPrimary.opacity(0.15), Color.oshiPrimary.opacity(0.05)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.oshiPrimary.opacity(0.2), Color.oshiSecondary.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "heart.text.square")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.oshiPrimary, Color.oshiAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(cardsAppeared ? 1 : 0.8)
            .opacity(cardsAppeared ? 1 : 0)
            
            VStack(spacing: 12) {
                Text("推しとの会話を始めよう")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("推しを登録して、いつでもどこでも\nあなたの推しとチャットできます")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .opacity(cardsAppeared ? 1 : 0)
            .offset(y: cardsAppeared ? 0 : 20)
            
            // 追加ボタン
            Button(action: {
                generateHapticFeedback()
                showAddOshiForm = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                    Text("推しを登録する")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.oshiPrimary, Color.oshiAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.oshiPrimary.opacity(0.4), radius: 16, x: 0, y: 8)
                )
            }
            .scaleEffect(cardsAppeared ? 1 : 0.9)
            .opacity(cardsAppeared ? 1 : 0)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - モダンチャットリスト
    private var modernChatListView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                // 追加カード
                addOshiCard
                    .padding(.top, 8)
                
                // チャット一覧
                ForEach(Array(filteredOshiList.enumerated()), id: \.element.id) { index, oshi in
                    if isEditing {
                        modernChatCard(oshi: oshi, index: index, isEditMode: true)
                    } else {
                        NavigationLink(destination: destinationView(for: oshi)) {
                            modernChatCard(oshi: oshi, index: index, isEditMode: false)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - 推し追加カード
    private var addOshiCard: some View {
        Button(action: {
            generateHapticFeedback()
            showAddOshiForm = true
        }) {
            HStack(spacing: 16) {
                // アイコン
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.oshiPrimary.opacity(0.15), Color.oshiSecondary.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.oshiPrimary, Color.oshiAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("新しい推しを追加")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("推しを登録してチャットを始めよう")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.4))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [Color.oshiPrimary.opacity(0.2), Color.oshiSecondary.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .opacity(cardsAppeared ? 1 : 0)
        .offset(y: cardsAppeared ? 0 : 20)
    }
    
    // MARK: - モダンチャットカード
    private func modernChatCard(oshi: Oshi, index: Int, isEditMode: Bool) -> some View {
        let isSelected = oshi.id == selectedOshiId
        let unreadCount = unreadCounts[oshi.id] ?? 0
        let lastMessage = lastMessages[oshi.id] ?? "まだメッセージがありません"
        let lastMessageTime = lastMessageTimes[oshi.id] ?? 0
        
        return HStack(spacing: 0) {
            HStack(spacing: 14) {
                // プロフィール画像
                ZStack {
                    // グロウエフェクト（選択中）
                    if isSelected {
                        Circle()
                            .fill(Color.oshiGlow)
                            .frame(width: 68, height: 68)
                            .blur(radius: 10)
                    }
                    
                    // 画像コンテナ
                    modernProfileImage(oshi: oshi, isSelected: isSelected)
                        .frame(width: 56, height: 56)
                    
                    // 未読バッジ
                    if unreadCount > 0 && !isEditMode {
                        modernUnreadBadge(count: unreadCount)
                            .offset(x: 22, y: -22)
                    }
                }
                .frame(width: 60, height: 60)
                
                // コンテンツ
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center) {
                        HStack(spacing: 8) {
                            Text(oshi.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            if isSelected {
                                selectedBadge
                            }
                        }
                        
                        Spacer()
                        
                        if !isEditMode {
                            Text(formatTime(lastMessageTime))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray.opacity(0.7))
                        }
                    }
                    
                    Text(lastMessage == "まだメッセージがありません" ?
                         NSLocalizedString("no_messages_yet", comment: "No messages yet") :
                         lastMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                if !isEditMode {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray.opacity(0.3))
                        .padding(.leading, 4)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            
            // 編集モード時の削除ボタン
            if isEditMode {
                editModeButtons(oshi: oshi)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(
                    color: isSelected ? Color.oshiPrimary.opacity(0.15) : Color.black.opacity(0.04),
                    radius: isSelected ? 16 : 12,
                    x: 0,
                    y: isSelected ? 6 : 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isSelected ?
                    LinearGradient(colors: [Color.oshiPrimary.opacity(0.5), Color.oshiSecondary.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                    LinearGradient(colors: [Color.clear, Color.clear], startPoint: .leading, endPoint: .trailing),
                    lineWidth: isSelected ? 2 : 0
                )
        )
        .opacity(cardsAppeared ? 1 : 0)
        .offset(y: cardsAppeared ? 0 : 20)
        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.05), value: cardsAppeared)
    }
    
    // MARK: - モダンプロフィール画像
    private func modernProfileImage(oshi: Oshi, isSelected: Bool) -> some View {
        Group {
            if let imageUrl = oshi.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        isSelected ?
                                        LinearGradient(colors: [Color.oshiPrimary, Color.oshiAccent], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                        LinearGradient(colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.1)], startPoint: .leading, endPoint: .trailing),
                                        lineWidth: isSelected ? 3 : 1
                                    )
                            )
                    default:
                        defaultAvatar(name: oshi.name, isSelected: isSelected)
                    }
                }
            } else {
                defaultAvatar(name: oshi.name, isSelected: isSelected)
            }
        }
    }
    
    private func defaultAvatar(name: String, isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.oshiPrimary.opacity(0.2), Color.oshiSecondary.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(String(name.prefix(1)))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.oshiPrimary, Color.oshiAccent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .overlay(
            Circle()
                .stroke(
                    isSelected ?
                    LinearGradient(colors: [Color.oshiPrimary, Color.oshiAccent], startPoint: .topLeading, endPoint: .bottomTrailing) :
                    LinearGradient(colors: [Color.clear, Color.clear], startPoint: .leading, endPoint: .trailing),
                    lineWidth: isSelected ? 3 : 0
                )
        )
    }
    
    // MARK: - 選択中バッジ
    private var selectedBadge: some View {
        Text(NSLocalizedString("selected", comment: "Selected"))
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.oshiPrimary, Color.oshiAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
    }
    
    // MARK: - モダン未読バッジ
    private func modernUnreadBadge(count: Int) -> some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, count > 9 ? 6 : 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.9), Color.red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.red.opacity(0.4), radius: 4, x: 0, y: 2)
            )
    }
    
    // MARK: - 編集モードボタン
    private func editModeButtons(oshi: Oshi) -> some View {
        HStack(spacing: 8) {
            // チャット履歴削除
            Button(action: {
                generateHapticFeedback()
                oshiToDelete = oshi
                showDeleteAlert = true
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .medium))
                    Text("履歴")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.orange)
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                )
            }
            
            // 推し削除
            Button(action: {
                generateHapticFeedback()
                oshiToDeleteCompletely = oshi
                showDeleteOshiAlert = true
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "person.badge.minus")
                        .font(.system(size: 18, weight: .medium))
                    Text("削除")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.red)
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                )
            }
        }
        .padding(.trailing, 12)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
    
    // MARK: - 削除中オーバーレイ
    private var deletingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // カスタムローディング
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(isDeletingOshi ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isDeletingOshi)
                }
                
                Text("推しを削除中...")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
            )
        }
    }
    
    // MARK: - チャットが存在するかどうかを判定
    private var hasAnyChats: Bool {
        return oshiList.contains { oshi in
            if let lastTime = lastMessageTimes[oshi.id], lastTime > 0 {
                return true
            }
            return false
        }
    }
    
    // MARK: - フィルタリングされた推しリスト
    private var filteredOshiList: [Oshi] {
        let filteredList = searchText.isEmpty ? oshiList : oshiList.filter {
            $0.name.lowercased().contains(searchText.lowercased())
        }
        
        return filteredList.sorted { oshi1, oshi2 in
            let isOshi1Selected = oshi1.id == selectedOshiId
            let isOshi2Selected = oshi2.id == selectedOshiId
            
            if isOshi1Selected && !isOshi2Selected {
                return true
            } else if !isOshi1Selected && isOshi2Selected {
                return false
            } else {
                let time1 = lastMessageTimes[oshi1.id] ?? 0
                let time2 = lastMessageTimes[oshi2.id] ?? 0
                return time1 > time2
            }
        }
    }
    
    // MARK: - 遷移先ビュー
    private func destinationView(for oshi: Oshi) -> some View {
        let viewModel = OshiViewModel(oshi: oshi)
        return OshiAIChatView(viewModel: viewModel, oshiItem: nil)
            .onDisappear {
                loadUnreadCounts()
                loadLastMessages()
                loadSelectedOshiId()
            }
    }
    
    // MARK: - 時間フォーマット
    private func formatTime(_ timestamp: TimeInterval) -> String {
        if timestamp == 0 {
            return ""
        }
        
        let date = Date(timeIntervalSince1970: timestamp)
        let calendar = Calendar.current
        let now = Date()
        
        let currentLanguage = Locale.current.languageCode ?? "en"
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            formatter.locale = currentLanguage == "ja" ? Locale(identifier: "ja_JP") : Locale(identifier: "en_US")
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return NSLocalizedString("yesterday", comment: "Yesterday")
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) == true {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            formatter.locale = currentLanguage == "ja" ? Locale(identifier: "ja_JP") : Locale(identifier: "en_US")
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            formatter.locale = currentLanguage == "ja" ? Locale(identifier: "ja_JP") : Locale(identifier: "en_US")
            return formatter.string(from: date)
        }
    }
    
    func executeProcessEveryThreeTimes() {
        let count = UserDefaults.standard.integer(forKey: "launchCount") + 1
        UserDefaults.standard.set(count, forKey: "launchCount")
        
        if count % 10 == 0 {
            customerFlag = true
        }
    }
    
    // MARK: - チャット履歴削除
    private func deleteChatHistory(for oshi: Oshi) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let chatRef = Database.database().reference()
            .child("oshiChats")
            .child(userId)
            .child(oshi.id)
        
        chatRef.removeValue { error, _ in
            DispatchQueue.main.async {
                if let error = error {
                    print("チャット履歴削除エラー: \(error.localizedDescription)")
                } else {
                    print("チャット履歴を削除しました: \(oshi.name)")
                    self.lastMessages[oshi.id] = "まだメッセージがありません"
                    self.lastMessageTimes[oshi.id] = 0
                    self.unreadCounts[oshi.id] = 0
                    
                    let userRef = Database.database().reference().child("users").child(userId)
                    userRef.child("lastReadTimestamps").child(oshi.id).removeValue()
                }
            }
        }
    }
    
    // MARK: - 推し完全削除
    private func deleteOshiCompletely(_ oshi: Oshi) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isDeletingOshi = true
        
        let dispatchGroup = DispatchGroup()
        var deletionError: Error? = nil
        
        dispatchGroup.enter()
        let oshiRef = Database.database().reference().child("oshis").child(userId).child(oshi.id)
        oshiRef.removeValue { error, _ in
            if let error = error {
                deletionError = error
            }
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        let chatRef = Database.database().reference().child("oshiChats").child(userId).child(oshi.id)
        chatRef.removeValue { error, _ in
            if let error = error { deletionError = error }
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        let itemsRef = Database.database().reference().child("oshiItems").child(userId).child(oshi.id)
        itemsRef.removeValue { error, _ in
            if let error = error { deletionError = error }
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        let storageRef = Storage.storage().reference().child("oshis").child(userId).child(oshi.id)
        storageRef.delete { error in
            if let error = error, (error as NSError).code != StorageErrorCode.objectNotFound.rawValue {
                print("ストレージ削除エラー: \(error.localizedDescription)")
            }
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        let userRef = Database.database().reference().child("users").child(userId)
        userRef.child("lastReadTimestamps").child(oshi.id).removeValue { error, _ in
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        userRef.child("selectedOshiId").observeSingleEvent(of: .value) { snapshot in
            if let selectedOshiId = snapshot.value as? String, selectedOshiId == oshi.id {
                let oshisRef = Database.database().reference().child("oshis").child(userId)
                oshisRef.observeSingleEvent(of: .value) { oshiSnapshot in
                    var newSelectedId = "default"
                    
                    for child in oshiSnapshot.children {
                        if let childSnapshot = child as? DataSnapshot, childSnapshot.key != oshi.id {
                            newSelectedId = childSnapshot.key
                            break
                        }
                    }
                    
                    userRef.updateChildValues(["selectedOshiId": newSelectedId]) { _, _ in
                        dispatchGroup.leave()
                    }
                }
            } else {
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.isDeletingOshi = false
            
            if deletionError == nil {
                if let index = self.oshiList.firstIndex(where: { $0.id == oshi.id }) {
                    self.oshiList.remove(at: index)
                }
                self.lastMessages.removeValue(forKey: oshi.id)
                self.lastMessageTimes.removeValue(forKey: oshi.id)
                self.unreadCounts.removeValue(forKey: oshi.id)
                
                if self.selectedOshiId == oshi.id {
                    self.selectedOshiId = self.oshiList.first?.id ?? ""
                }
                
                self.loadData()
            }
        }
    }
    
    // MARK: - データ読み込み
    private func loadData() {
        isLoading = true
        loadOshiList()
        loadSelectedOshiId()
    }
    
    private func loadSelectedOshiId() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let userRef = Database.database().reference().child("users").child(userId)
        userRef.child("selectedOshiId").observeSingleEvent(of: .value) { snapshot in
            if let selectedId = snapshot.value as? String {
                DispatchQueue.main.async {
                    self.selectedOshiId = selectedId
                }
            }
        }
    }
    
    private func loadOshiList() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        let ref = Database.database().reference().child("oshis").child(userId)
        
        ref.observeSingleEvent(of: .value) { snapshot in
            var newOshis: [Oshi] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let value = childSnapshot.value as? [String: Any] {
                    let id = childSnapshot.key
                    let name = value["name"] as? String ?? "名前なし"
                    let imageUrl = value["imageUrl"] as? String
                    let backgroundImageUrl = value["backgroundImageUrl"] as? String
                    let memo = value["memo"] as? String
                    let createdAt = value["createdAt"] as? TimeInterval
                    let personality = value["personality"] as? String
                    let speakingStyle = value["speaking_style"] as? String
                    let birthday = value["birthday"] as? String
                    let height = value["height"] as? Int
                    let favoriteColor = value["favorite_color"] as? String
                    let favoriteFood = value["favorite_food"] as? String
                    let dislikedFood = value["disliked_food"] as? String
                    let hometown = value["hometown"] as? String
                    let interests = value["interests"] as? [String]
                    let gender = value["gender"] as? String ?? "男性"
                    let userNickname = value["user_nickname"] as? String
                    let relationshipStatus = value["relationship_status"] as? String
                    let relationshipDetail = value["relationship_detail"] as? String
                    let sharedMemory = value["shared_memory"] as? String
                    let signaturePhrase = value["signature_phrase"] as? String
                    let conversationTopics = value["conversation_topics"] as? [String]
                    let forbiddenTopics = value["forbidden_topics"] as? [String]
                    let preferredLanguage = value["preferred_language"] as? String
                    
                    let oshi = Oshi(
                        id: id,
                        name: name,
                        imageUrl: imageUrl,
                        backgroundImageUrl: backgroundImageUrl,
                        memo: memo,
                        createdAt: createdAt,
                        personality: personality,
                        interests: interests,
                        speaking_style: speakingStyle,
                        birthday: birthday,
                        height: height,
                        favorite_color: favoriteColor,
                        favorite_food: favoriteFood,
                        disliked_food: dislikedFood,
                        hometown: hometown,
                        gender: gender,
                        user_nickname: userNickname,
                        relationship_status: relationshipStatus,
                        relationship_detail: relationshipDetail,
                        shared_memory: sharedMemory,
                        signature_phrase: signaturePhrase,
                        conversation_topics: conversationTopics,
                        forbidden_topics: forbiddenTopics,
                        preferred_language: preferredLanguage
                    )
                    newOshis.append(oshi)
                }
            }
            
            DispatchQueue.main.async {
                self.oshiList = newOshis
                self.loadUnreadCounts()
                self.loadLastMessages()
            }
        }
    }
    
    private func loadLastMessages() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let dispatchGroup = DispatchGroup()
        var tempLastMessages: [String: String] = [:]
        var tempLastMessageTimes: [String: TimeInterval] = [:]
        
        for oshi in oshiList {
            dispatchGroup.enter()
            
            let chatRef = Database.database().reference()
                .child("oshiChats")
                .child(userId)
                .child(oshi.id)
            
            chatRef.queryOrdered(byChild: "timestamp")
                .queryLimited(toLast: 1)
                .observeSingleEvent(of: .value) { snapshot in
                    
                    var latestMessage: String = "まだメッセージがありません"
                    var latestTimestamp: TimeInterval = 0
                    
                    for child in snapshot.children {
                        if let childSnapshot = child as? DataSnapshot,
                           let messageDict = childSnapshot.value as? [String: Any],
                           let content = messageDict["content"] as? String,
                           let timestamp = messageDict["timestamp"] as? TimeInterval {
                            latestMessage = content
                            latestTimestamp = timestamp
                            break
                        }
                    }
                    
                    tempLastMessages[oshi.id] = latestMessage
                    tempLastMessageTimes[oshi.id] = latestTimestamp
                    
                    dispatchGroup.leave()
                }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.lastMessages = tempLastMessages
            self.lastMessageTimes = tempLastMessageTimes
            self.isLoading = false
            self.sendProactiveMessageIfNeeded()
        }
    }
    
    private func loadUnreadCounts() {
        let dispatchGroup = DispatchGroup()
        var tempUnreadCounts: [String: Int] = [:]
        
        for oshi in oshiList {
            dispatchGroup.enter()
            
            ChatDatabaseManager.shared.fetchUnreadMessageCount(for: oshi.id) { count, _ in
                tempUnreadCounts[oshi.id] = count
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.unreadCounts = tempUnreadCounts
        }
    }
    
    private func sendProactiveMessageIfNeeded() {
        guard !oshiList.isEmpty else { return }

        let sortedCandidates = oshiList.sorted { lhs, rhs in
            let lhsPriority = lhs.id == selectedOshiId ? 0 : 1
            let rhsPriority = rhs.id == selectedOshiId ? 0 : 1

            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }

            let lhsLastMessage = lastMessageTimes[lhs.id] ?? 0
            let rhsLastMessage = lastMessageTimes[rhs.id] ?? 0
            return lhsLastMessage < rhsLastMessage
        }

        attemptProactiveMessage(with: sortedCandidates)
    }

    private func attemptProactiveMessage(with candidates: [Oshi]) {
        guard let candidate = candidates.first else { return }

        RandomMessageManager.shared.sendProactiveMessageIfNeeded(for: candidate) { message in
            guard let message = message else {
                self.attemptProactiveMessage(with: Array(candidates.dropFirst()))
                return
            }

            DispatchQueue.main.async {
                self.lastMessages[candidate.id] = message.content
                self.lastMessageTimes[candidate.id] = message.timestamp
                self.unreadCounts[candidate.id] = (self.unreadCounts[candidate.id] ?? 0) + 1
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - チャット行ビュー（修正版）
struct ChatRowView: View {
    let oshi: Oshi
    let unreadCount: Int
    let lastMessage: String
    let lastMessageTime: TimeInterval
    let isSelected: Bool
    var showEditButtons: Bool = false
    var onDeleteChat: (() -> Void)? = nil
    var onDeleteOshi: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            // プロフィール画像
            ZStack {
                profileImageView
                    .frame(width: 56, height: 56)
                
                // 選択中の推しには特別なインジケーターを表示
                if isSelected {
                    Circle()
                        .stroke(Color.pink, lineWidth: 3)
                        .frame(width: 56, height: 56)
                }
            }
            
            // メッセージ情報
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    HStack(spacing: 6) {
                        Text(oshi.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .lineLimit(1)
                        
                        // 選択中の推しにはバッジを表示
                        if isSelected {
                            Text(NSLocalizedString("selected", comment: "Selected"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.pink)
                                .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                    
                    Text(formatTime(lastMessageTime))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text(lastMessage == "まだメッセージがありません" ?
                         NSLocalizedString("no_messages_yet", comment: "No messages yet") :
                         lastMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if unreadCount > 0 {
                        unreadBadge
                    }
                }
            }
            
            // 編集モード時の削除ボタン
            if showEditButtons {
                VStack(spacing: 5) {
                    // チャット履歴削除ボタン
                    Button(action: {
                        onDeleteChat?()
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(.orange)
                            Text(NSLocalizedString("chat_history_short", comment: "History"))
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // 推し完全削除ボタン
                    Button(action: {
                        onDeleteOshi?()
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: "person.crop.circle.badge.minus")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                            Text(NSLocalizedString("oshi", comment: "Oshi"))
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isSelected ? Color.pink.opacity(0.05) : Color.white) // 選択中は背景色を変更
    }
    
    // プロフィール画像
    private var profileImageView: some View {
        Group {
            if let imageUrl = oshi.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                    default:
                        defaultProfileImage
                    }
                }
            } else {
                defaultProfileImage
            }
        }
    }
    
    private var defaultProfileImage: some View {
        Circle()
            .fill(Color.gray.opacity(0.2))
            .overlay(
                Text(String(oshi.name.prefix(1)))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.gray)
            )
    }
    
    // 未読バッジ
    private var unreadBadge: some View {
        Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, unreadCount > 9 ? 6 : 8)
            .padding(.vertical, 4)
            .background(Color.red)
            .clipShape(Capsule())
            .scaleEffect(0.9)
    }
    
    // 時間フォーマット（多言語対応）
    private func formatTime(_ timestamp: TimeInterval) -> String {
        if timestamp == 0 {
            return ""
        }
        
        let date = Date(timeIntervalSince1970: timestamp)
        let calendar = Calendar.current
        let now = Date()
        
        // 現在の言語を取得
        let currentLanguage = Locale.current.languageCode ?? "en"
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            if currentLanguage == "ja" {
                formatter.locale = Locale(identifier: "ja_JP")
            } else {
                formatter.locale = Locale(identifier: "en_US")
            }
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return NSLocalizedString("yesterday", comment: "Yesterday")
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) == true {
            let formatter = DateFormatter()
            if currentLanguage == "ja" {
                formatter.dateFormat = "EEEE"
                formatter.locale = Locale(identifier: "ja_JP")
            } else {
                formatter.dateFormat = "EEEE"
                formatter.locale = Locale(identifier: "en_US")
            }
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            if currentLanguage == "ja" {
                formatter.locale = Locale(identifier: "ja_JP")
            } else {
                formatter.locale = Locale(identifier: "en_US")
            }
            return formatter.string(from: date)
        }
    }
}

// MARK: - プレビュー
#Preview {
    TopView()
}
