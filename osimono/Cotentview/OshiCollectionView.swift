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
    @State var isLoading = false
    @State private var showingFilterMenu = false
    @State private var sortOption = "新しい順"
    @State private var showingItemTypeFilter = false
    @State private var selectedItemType: String = "すべて"
    var oshiId: String
    var refreshTrigger: Bool
    @Binding var editFlag: Bool
    @Binding var isEditingUsername: Bool
    @Binding var showChangeOshiButton: Bool
    
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
                    // アイテムタイプ選択
                    VStack(alignment: .leading, spacing: 10) {
                        // アイテムタイプボタン
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
                    
                    Divider()
                    
                    // 並び替え
                    VStack(alignment: .leading, spacing: 10) {
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
                        .frame(width: 60, height: 60)
                        .foregroundColor(primaryColor.opacity(0.3))
                    
                    VStack(spacing: 8) {
                        Text("推しコレクションがありません")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Text("右下の「+」ボタンから推しグッズやSNS投稿を追加してみましょう！")
                            .font(.system(size: 16))
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
        .overlay(
            VStack(spacing: -5) {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring()) {
                            editFlag.toggle()
                            isEditingUsername.toggle()
                            showChangeOshiButton.toggle()
                            generateHapticFeedback()
                        }
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 22, weight: .medium))
                            .padding(15)
                            .background(
                                Circle()
                                    .fill(accentColor)
                                    .shadow(color: accentColor.opacity(0.3), radius: 5, x: 0, y: 3)
                            )
                            .foregroundColor(.white)
                    }
                    .padding(.trailing)
                }
                
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring()) {
                            addFlag = true
                        }
                        generateHapticFeedback()
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .medium))
                            .padding(18)
                            .background(
                                Circle()
                                    .fill(primaryColor)
                                    .shadow(color: primaryColor.opacity(0.3), radius: 5, x: 0, y: 3)
                            )
                            .foregroundColor(.white)
                    }
                    .padding()
                }
            }.padding(.trailing,0)
        )
        .dismissKeyboardOnTap()
        .background(backgroundColor)
        .onAppear {
//            fetchOshiItems()
        }
        .onChange(of: oshiId) { newOshiId in
            fetchOshiItems()
        }
        .onChange(of: refreshTrigger) { _ in
            // リフレッシュトリガーが変更されたときに投稿を再取得
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
            OshiItemFormView(oshiId: oshiId)
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
    
    // 特定のアイテムタイプの色を取得
    func colorForItemType(_ type: String) -> Color {
        return itemTypeColors[type] ?? accentColor
    }
    
    // データ取得
    func fetchOshiItems() {
            guard let userId = userId else { return }
            self.isLoading = true
            
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
                    self.isLoading = false
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
