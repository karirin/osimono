//
//  Untitled.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth

// 推しカテゴリー
struct OshiCategory: Identifiable {
    var id = UUID()
    var name: String
    var icon: String
}

struct OshiCollectionView: View {
    @State private var oshiItems: [OshiItem] = []
    @State private var selectedImage: UIImage?
    @State private var isShowingForm = false
    @State private var selectedCategory: String = "すべて"
    @State private var searchText: String = ""
    @Binding var addFlag: Bool
    @State var isLoading = true
    @State private var showingFilterMenu = false
    @State private var sortOption = "新しい順"
    @State private var showingItemTypeFilter = false
    @State private var selectedItemType: String = "すべて"
    var oshiId: String
    var refreshTrigger: Bool
    @Binding var showingOshiAlert: Bool
    @Binding var editFlag: Bool
    @Binding var isEditingUsername: Bool
    @Binding var showChangeOshiButton: Bool
    @Binding var isShowingEditOshiView: Bool
    @State private var hasLoadedInitialData = false
    @State private var showAddOshiForm = false
    
    // NavigationLink用の状態変数を追加
    @Binding var navigateToItemForm: Bool
    @State private var navigateToAddOshiForm = false
    
    @StateObject private var subscriptionManager = SubscriptionManager()
    
    private var shouldShowAd: Bool {
        return !isAdmin && !subscriptionManager.isSubscribed
    }
    
    // 色の定義 - 推し活向けカラー
    let primaryColor = Color(.systemPink) // ピンク
    let accentColor = Color(.purple) // 紫
    let backgroundColor = Color(.white) // 明るい背景色
    let cardColor = Color(.white) // カード背景色
    
    // 各アイテムタイプごとの色定義
    let itemTypeColors: [String: Color] = [
        "すべて": Color(.systemBlue),
        "グッズ": Color(.systemPink),
        "聖地巡礼": Color(.systemGreen),
        "ライブ記録": Color(.systemOrange),
        "SNS投稿": Color(.systemPurple),
        "その他": Color(.systemGray)
    ]
    
    // カテゴリーリスト - 推し活向けカテゴリー
    let categories = ["すべて", "グッズ", "CD・DVD", "雑誌", "写真集", "アクリルスタンド", "ぬいぐるみ", "Tシャツ", "タオル", "その他"]
    
    // アイテムタイプ（「聖地巡礼」と「その他」を追加）
    let itemTypes = [L10n.all, L10n.goods, L10n.pilgrimage, L10n.liveRecord, L10n.snsPost, L10n.other]
    
    var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // 検索とフィルター適用後の商品リスト
    var filteredItems: [OshiItem] {
        var result = oshiItems
        
        // アイテムタイプフィルター
        if selectedItemType != "すべて" {
            result = result.filter { $0.itemType == selectedItemType }
        }
        
        // カテゴリーフィルター
        if selectedCategory != "すべて" {
            result = result.filter { $0.category == selectedCategory }
        }
        
        // 検索テキストフィルター
        if !searchText.isEmpty {
            result = result.filter { item in
                return item.title?.lowercased().contains(searchText.lowercased()) ?? false ||
                item.memo?.lowercased().contains(searchText.lowercased()) ?? false ||
                item.eventName?.lowercased().contains(searchText.lowercased()) ?? false ||
                item.locationAddress?.lowercased().contains(searchText.lowercased()) ?? false ||
                (item.tags?.joined(separator: " ").lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
        
        // ソート
        switch sortOption {
        case "新しい順":
            result.sort { (a, b) -> Bool in
                guard let dateA = a.date, let dateB = b.date else { return false }
                return dateA > dateB
            }
        case "古い順":
            result.sort { (a, b) -> Bool in
                guard let dateA = a.date, let dateB = b.date else { return false }
                return dateA < dateB
            }
        case "価格高い順":
            result.sort { (a, b) -> Bool in
                return (a.price ?? 0) > (b.price ?? 0)
            }
        case "価格安い順":
            result.sort { (a, b) -> Bool in
                return (a.price ?? 0) < (b.price ?? 0)
            }
        case "お気に入り順":
            result.sort { (a, b) -> Bool in
                return (a.favorite ?? 0) > (b.favorite ?? 0)
            }
        default:
            break
        }
        
        return result
    }
    
    private let adminUserIds = [
        ""
//        "3UDNienzhkdheKIy77lyjMJhY4D3",
//        "bZwehJdm4RTQ7JWjl20yaxTWS7l2"
    ]
    
    @State private var isAdmin = false
    @State private var isCheckingAdminStatus = true
    
    @State private var totalUnreadCount = 0
    @State private var hasNewMessages = false
    
    private func checkAdminStatus() {
        guard let userID = Auth.auth().currentUser?.uid else {
            isAdmin = false
            isCheckingAdminStatus = false
            return
        }
        
        // UserIDで管理者権限をチェック
        isAdmin = adminUserIds.contains(userID)
        isCheckingAdminStatus = false
        
        if isAdmin {
            print("🔑 管理者としてログイン中: \(userID)")
        }
    }
    
    var body: some View {
        ZStack{
            VStack(spacing: -5) {
                if !isAdmin {
                    if shouldShowAd {
                        BannerAdView()
                            .frame(height: 60)
                    }
                }
                
                // 検索バーとフィルター
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        ZStack(alignment: .leading) {
                            if searchText.isEmpty {
                                Text(L10n.searchText)
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                            }
                            TextField("", text: $searchText)
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                        }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                generateHapticFeedback()
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(8)
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.05), radius: 2)
                    
                    Button(action: {
                        withAnimation {
                            showingFilterMenu.toggle()
                        }
                        generateHapticFeedback()
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(primaryColor)
                            .padding(8)
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.05), radius: 2)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // フィルターメニュー - itemTypesに変更
                if showingFilterMenu {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 10) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(itemTypes, id: \.self) { itemType in
                                        Button(action: {
                                            selectedItemType = itemType
                                            generateHapticFeedback()
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: itemTypeIcon(for: itemType))
                                                    .font(.system(size: 10))
                                                Text(itemType)
                                                    .font(.system(size: 12))
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(selectedItemType == itemType ? Color.white : Color.gray.opacity(0.3), lineWidth: 1)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 20)
                                                            .fill(selectedItemType == itemType ?
                                                                  (itemTypeColors[itemType] ?? accentColor) :
                                                                    (Color.white ?? Color.gray))
                                                    )
                                            )
                                            .foregroundColor(selectedItemType == itemType ? .white : .gray ?? .gray)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Updated sorting options
                        VStack(alignment: .leading, spacing: 10) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach([L10n.sortNewest, L10n.sortOldest, L10n.sortPriceHigh, L10n.sortPriceLow, L10n.sortFavorite], id: \.self) { option in
                                        Button(action: {
                                            sortOption = option
                                            generateHapticFeedback()
                                        }) {
                                            Text(option)
                                                .font(.system(size: 12))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 20)
                                                        .stroke(sortOption == option ? primaryColor : Color.gray.opacity(0.3), lineWidth: 1)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 20)
                                                                .fill(sortOption == option ? primaryColor.opacity(0.1) : Color.clear)
                                                        )
                                                )
                                                .foregroundColor(sortOption == option ? primaryColor : .gray)
                                                .padding(3)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                    .background(cardColor)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // メインコンテンツ
                if isLoading {
                    VStack {
                        Spacer()
                        LoadingView2()
                        Spacer()
                    }
                } else if filteredItems.isEmpty {
                    VStack(spacing: isSmallDevice() ? 5 : 20) {
                        Spacer()
                        
                        Image(systemName: "star.square.on.square")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundColor(primaryColor.opacity(0.3))
                        
                        VStack(spacing: 8) {
                            Text(L10n.noRecords)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text(L10n.addItemsMessage)
                                .font(.system(size: 16))
                                .foregroundColor(.gray.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Button(action: {
                            if oshiId == "default" {
                                showingOshiAlert = true
                            } else {
                                navigateToItemForm = true
                            }
                            generateHapticFeedback()
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text(L10n.addItem)
                            }
                            .font(.system(size: isSmallDevice() ? 13 : 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, isSmallDevice() ? 8 : 12)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(primaryColor)
                            )
                        }
                        .padding(.top, isSmallDevice() ? 8 : 16)
                        
                        Spacer()
                        Spacer()
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                            ForEach(filteredItems) { item in
                                NavigationLink(destination: OshiItemDetailView(item: item)
                                    .gesture(
                                        DragGesture()
                                            .onEnded { value in
                                                if value.translation.width > 80 {
                                                    // NavigationLinkは自動的に戻る
                                                }
                                            }
                                    )
                                ) {
                                    OshiItemCard(item: item)
                                }
                            }
                        }
                        .padding(.horizontal,5)
                        .padding(.top, 8)
                        .padding(.bottom, 160) // 下部のボタンのためのスペース
                    }
                }
            }
            
            // NavigationLinkを非表示で配置
            NavigationLink(
                destination: AddOshiView()
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.width > 80 {
                                    navigateToAddOshiForm = false
                                }
                            }
                    ),
                isActive: $navigateToAddOshiForm
            ) {
                EmptyView()
            }
            .hidden()
        }
        .overlay(
            VStack(spacing: -5) {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring()) {
                            // ここで検証を追加
                            if oshiId == "default" {
                                showingOshiAlert = true
                            } else {
                                navigateToItemForm = true
                            }
                        }
                        generateHapticFeedback()
                    }) {
                        ZStack{
                            Circle()
                                .frame(width: 56, height: 56).foregroundColor(Color.white)
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [primaryColor.opacity(0.7), accentColor.opacity(0.7)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .shadow(color: Color.customPink.opacity(0.3), radius: 15, x: 0, y: 8)
                        }
                    }
                    .padding()
                }
            }.padding(.trailing,0)
        )
        .dismissKeyboardOnTap()
        .background(backgroundColor)
        .onAppear {
            fetchOshiItems()
            checkAdminStatus()
            Task {
                await subscriptionManager.updateSubscriptionStatus()
            }
        }
        .onChange(of: oshiId) { newOshiId in
            fetchOshiItems()
        }
        .onChange(of: isShowingEditOshiView) { newOshiId in
            loadSelectedOshi()
        }
        .onChange(of: refreshTrigger) { _ in
            fetchOshiItems()
        }
        .onChange(of: addFlag) { newValue in
            if newValue {
                navigateToItemForm = true
                addFlag = false
            }
        }
        .onChange(of: showAddOshiForm) { newValue in
            if newValue {
                navigateToAddOshiForm = true
                showAddOshiForm = false
            }
        }
    }
    
    func loadSelectedOshi() {
        guard let userId = userId else { return }
        
        let dbRef = Database.database().reference().child("users").child(userId)
        dbRef.observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else { return }
            
            if let selectedOshiId = value["selectedOshiId"] as? String {
                self.isLoading = true
                
                // 変更：選択中の推しIDのパスから取得
                let ref = Database.database().reference().child("oshiItems").child(userId).child(selectedOshiId)
                
                ref.observeSingleEvent(of: .value) { snapshot in
                    var newItems: [OshiItem] = []
                    
                    for child in snapshot.children {
                        if let childSnapshot = child as? DataSnapshot {
                            if let value = childSnapshot.value as? [String: Any] {
                                do {
                                    let jsonData = try JSONSerialization.data(withJSONObject: value)
                                    let item = try JSONDecoder().decode(OshiItem.self, from: jsonData)
                                    newItems.append(item)
                                } catch {
                                    print("デコードエラー: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self.oshiItems = newItems
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    // アイテムタイプのアイコンを取得
    func itemTypeIcon(for type: String) -> String {
        switch type {
        case L10n.all, "すべて":
            return "square.grid.2x2"
        case L10n.goods, "グッズ":
            return "gift.fill"
        case L10n.pilgrimage, "聖地巡礼":
            return "mappin.and.ellipse"
        case L10n.liveRecord, "ライブ記録":
            return "music.note"
        case L10n.snsPost, "SNS投稿":
            return "bubble.right.fill"
        case L10n.other, "その他":
            return "questionmark.circle"
        default:
            return "photo"
        }
    }
    
    // 特定のアイテムタイプの色を取得
    func colorForItemType(_ type: String) -> Color {
        return itemTypeColors[type] ?? accentColor
    }
    
    // データ取得
    func fetchOshiItems() {
        guard let userId = userId else { return }
        // 変更：選択中の推しIDのパスから取得
        let ref = Database.database().reference().child("oshiItems").child(userId).child(oshiId)
        ref.observeSingleEvent(of: .value) { snapshot in
            var newItems: [OshiItem] = []
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot {
                    if let value = childSnapshot.value as? [String: Any] {
                        do {
                            let jsonData = try JSONSerialization.data(withJSONObject: value)
                            let item = try JSONDecoder().decode(OshiItem.self, from: jsonData)
                            newItems.append(item)
                        } catch {
                            print("デコードエラー: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.oshiItems = newItems
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isLoading = false
                }
            }
        }
    }
    
    // 触覚フィードバック
    func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // isSmallDevice関数（この関数がコード内で使用されていますが、定義がないため追加します）
    func isSmallDevice() -> Bool {
        return UIScreen.main.bounds.height < 700
    }
}

#Preview {
    TopView()
}
