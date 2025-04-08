//
//  Untitled.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth

// 推しグッズデータモデル
struct OshiItem: Identifiable, Codable {
    var id: String = UUID().uuidString
    var title: String?
    var category: String?
    var memo: String?
    var imageUrl: String?
    var price: Int?
    var purchaseDate: TimeInterval?
    var eventName: String?
    var favorite: Int?  // お気に入り度（5段階）
    var memories: String? // 思い出・エピソード
    var tags: [String]?  // タグ（メンバー名など）
    var location: String? // 購入場所
    var itemType: String? // グッズ/SNS投稿/ライブ記録/聖地巡礼/その他
    
    // 聖地巡礼用フィールド
    var locationAddress: String? // 聖地の場所・住所
    var visitDate: TimeInterval? // 訪問日
    
    // その他用フィールド
    var recordDate: TimeInterval? // 記録日
    var details: String? // 詳細メモ
    
    // Firebase用のタイムスタンプ
    var createdAt: TimeInterval?
    
    var date: Date? {
        if let timestamp = createdAt {
            return Date(timeIntervalSince1970: timestamp)
        }
        return nil
    }
    
    // 各タイプごとの日付取得
    var typeSpecificDate: Date? {
        switch itemType {
        case "グッズ":
            if let timestamp = purchaseDate {
                return Date(timeIntervalSince1970: timestamp)
            }
        case "ライブ記録":
            if let timestamp = purchaseDate {
                return Date(timeIntervalSince1970: timestamp)
            }
        case "SNS投稿":
            if let timestamp = purchaseDate {
                return Date(timeIntervalSince1970: timestamp)
            }
        case "聖地巡礼":
            if let timestamp = visitDate {
                return Date(timeIntervalSince1970: timestamp)
            }
        case "その他":
            if let timestamp = recordDate {
                return Date(timeIntervalSince1970: timestamp)
            }
        default:
            break
        }
        return date
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, category, memo, imageUrl, price, purchaseDate, eventName
        case favorite, memories, tags, location, itemType, createdAt
        case locationAddress, visitDate, recordDate, details
    }
}

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
    @State var isLoading = false
    @State private var showingFilterMenu = false
    @State private var sortOption = "新しい順"
    @State private var showingItemTypeFilter = false
    @State private var selectedItemType: String = "すべて"
    
    // 色の定義 - 推し活向けカラー
    let primaryColor = Color(.systemPink) // ピンク
    let accentColor = Color(.purple) // 紫
    let backgroundColor = Color(.white) // 明るい背景色
    let cardColor = Color(.white) // カード背景色
    
    // カテゴリーリスト - 推し活向けカテゴリー
    let categories = ["すべて", "グッズ", "CD・DVD", "雑誌", "写真集", "アクリルスタンド", "ぬいぐるみ", "Tシャツ", "タオル", "その他"]
    
    // アイテムタイプ（「聖地巡礼」と「その他」を追加）
    let itemTypes = ["すべて", "グッズ", "聖地巡礼", "ライブ記録", "SNS投稿", "その他"]
    
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
    
    var body: some View {
        VStack(spacing: -5) {
            // 検索バーとフィルター
            HStack(spacing: 12) {
                // 検索バー
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("推しの名前、グッズ名で検索", text: $searchText)
                        .font(.system(size: 14))
                    
                    if !searchText.isEmpty {
                        Button(action: {
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
                
                // フィルターボタン
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
            .padding(.top, isSmallDevice() ? 0 : 0)
            // 変更部分: showingFilterMenuがtrueの時に表示されるフィルターメニューの内容を変更します
            if showingFilterMenu {
                VStack(alignment: .leading, spacing: 12) {
                    // カテゴリー選択
                    VStack(alignment: .leading, spacing: 10) {
                        Text("カテゴリー")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        // カテゴリボタン
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(categories, id: \.self) { category in
                                    Button(action: {
                                        selectedCategory = category
                                        generateHapticFeedback()
                                    }) {
                                        Text(category)
                                            .font(.system(size: 12))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .fill(selectedCategory == category ? accentColor : Color.gray.opacity(0.1))
                                            )
                                            .foregroundColor(selectedCategory == category ? .white : .gray)
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // 並び替え
                    VStack(alignment: .leading, spacing: 10) {
                        Text("並び替え")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        // 並び替えオプション
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(["新しい順", "古い順", "価格高い順", "価格安い順", "お気に入り順"], id: \.self) { option in
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
                                    }
                                }
                            }
                        }
                    }
                    
                    // 適用ボタン
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation {
                                showingFilterMenu = false
                            }
                        }) {
                            Text("適用")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(primaryColor)
                                )
                        }
                        Spacer()
                    }
                    .padding(.top, 12)
                }
                .padding()
                .background(cardColor)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 3)
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // メインコンテンツ
            if isLoading {
                // ローディング表示
                VStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                    Text("読み込み中...")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                    Spacer()
                }
            } else if filteredItems.isEmpty {
                // 空の状態表示
                VStack(spacing: isSmallDevice() ? 5 : 20) {
                    Spacer()
                    
                    Image(systemName: "star.square.on.square")
                        .resizable()
                        .scaledToFit()
                        .frame(width: isSmallDevice() ? 40 : 60, height: isSmallDevice() ? 50 : 60)
                        .foregroundColor(primaryColor.opacity(0.3))
                    
                    VStack(spacing: 8) {
                        Text("推しコレクションがありません")
                            .font(.system(size: isSmallDevice() ? 16 : 20, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Text("右下の「+」ボタンから推しグッズやSNS投稿を追加してみましょう！")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button(action: {
                        addFlag = true
                        generateHapticFeedback()
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("推しアイテムを追加")
                        }
                        .font(.system(size: isSmallDevice() ? 12 : 16, weight: .medium))
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
                // コレクション表示
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                        ForEach(filteredItems) { item in
                            NavigationLink(destination: OshiItemDetailView(item: item)) {
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
        .padding(.top, isSmallDevice() ? 0 : 0)
        .background(backgroundColor)
        .onAppear {
            fetchOshiItems()
        }
        .onChange(of: addFlag) { newValue in
            if !newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    fetchOshiItems()
                }
            }
        }
        .fullScreenCover(isPresented: $addFlag) {
            OshiItemFormView()
        }
    }
    
    // アイテムタイプのアイコンを取得
    func itemTypeIcon(for type: String) -> String {
        switch type {
        case "グッズ": return "gift.fill"
        case "聖地巡礼": return "mappin.and.ellipse"
        case "ライブ記録": return "music.note.list"
        case "SNS投稿": return "bubble.right.fill"
        case "その他": return "ellipsis.circle.fill"
        default: return "square.grid.2x2.fill"
        }
    }
    
    // データ取得
    func fetchOshiItems() {
        guard let userId = userId else { return }
        self.isLoading = true
        let ref = Database.database().reference().child("oshiItems").child(userId)
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
    
    // 触覚フィードバック
    func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

#Preview {
    TopView()
}
