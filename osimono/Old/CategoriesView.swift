////
////  Untitled.swift
////  osimono
////
////  Created by Apple on 2025/04/06.
////
//
//import SwiftUI
//import Firebase
//import FirebaseAuth
//
//struct CategoriesView: View {
//    @State private var categories: [OshiCategory] = []
//    @State private var itemCounts: [String: Int] = [:]
//    @State private var selectedCategory: String? = nil
//    @State private var oshiItems: [OshiItem] = []
//    @State private var isLoading = true
//    @State private var allItems: [OshiItem] = []
//    
//    // 色の定義
//    let primaryColor = Color(.systemPink) // 明るいピンク
//    let accentColor = Color(.purple) // 紫系
//    let backgroundColor = Color(.white) // 明るい背景色
//    let cardColor = Color(.white) // カード背景色
//    let textColor = Color(.black) // テキスト色
//    
//    // 定義済みカテゴリー
//    let predefinedCategories: [OshiCategory] = [
//        OshiCategory(name: "グッズ", icon: "gift.fill"),
//        OshiCategory(name: "CD・DVD", icon: "opticaldisc.fill"),
//        OshiCategory(name: "雑誌", icon: "book.fill"),
//        OshiCategory(name: "写真集", icon: "photo.on.rectangle.angled"),
//        OshiCategory(name: "アクリルスタンド", icon: "person.fill"),
//        OshiCategory(name: "ぬいぐるみ", icon: "heart.fill"),
//        OshiCategory(name: "Tシャツ", icon: "tshirt.fill"),
//        OshiCategory(name: "タオル", icon: "scribble"),
//        OshiCategory(name: "ライブグッズ", icon: "music.note"),
//        OshiCategory(name: "その他", icon: "ellipsis.circle.fill")
//    ]
//    
//    // アイテムタイプ（「聖地巡礼」と「その他」を追加）
//    let itemTypes = [
//        OshiCategory(name: "グッズ", icon: "gift.fill"),
//        OshiCategory(name: "聖地巡礼", icon: "mappin.and.ellipse"),
//        OshiCategory(name: "ライブ記録", icon: "music.note.list"),
//        OshiCategory(name: "SNS投稿", icon: "bubble.right.fill"),
//        OshiCategory(name: "その他", icon: "ellipsis.circle.fill")
//    ]
//    
//    var body: some View {
//        ZStack {
//            backgroundColor.ignoresSafeArea()
//            
//            if isLoading {
//                ProgressView()
//                    .scaleEffect(1.2)
//            } else {
//                ScrollView {
//                    VStack(alignment: .leading, spacing: 20) {
//                        // ヘッダー
//                        Text("カテゴリー")
//                            .font(.system(size: 22, weight: .bold))
//                            .foregroundColor(primaryColor)
//                            .padding(.horizontal)
//                            .padding(.top)
//                        
//                        // アイテムタイプセクション
//                        VStack(alignment: .leading, spacing: 10) {
//                            Text("アイテムタイプ")
//                                .font(.system(size: 18, weight: .medium))
//                                .foregroundColor(.black)
//                                .padding(.horizontal)
//                            
//                            ScrollView(.horizontal, showsIndicators: false) {
//                                HStack(spacing: 15) {
//                                    ForEach(itemTypes) { category in
//                                        CategoryButton(
//                                            category: category,
//                                            count: itemCountForType(category.name),
//                                            isSelected: selectedCategory == category.name,
//                                            onTap: {
//                                                if selectedCategory == category.name {
//                                                    selectedCategory = nil
//                                                } else {
//                                                    selectedCategory = category.name
//                                                }
//                                                generateHapticFeedback()
//                                                filterItems()
//                                            }
//                                        )
//                                    }
//                                }
//                                .padding(.horizontal)
//                            }
//                        }
//                        
//                        // カテゴリーセクション（グッズのカテゴリーのみ表示）
//                        if selectedCategory == nil || selectedCategory == "グッズ" {
//                            VStack(alignment: .leading, spacing: 10) {
//                                Text("グッズカテゴリー")
//                                    .font(.system(size: 18, weight: .medium))
//                                    .foregroundColor(.black)
//                                    .padding(.horizontal)
//                                
//                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
//                                    ForEach(categories) { category in
//                                        if let count = itemCounts[category.name], count > 0 {
//                                            CategoryButton(
//                                                category: category,
//                                                count: count,
//                                                isSelected: selectedCategory == category.name,
//                                                onTap: {
//                                                    if selectedCategory == category.name {
//                                                        selectedCategory = nil
//                                                    } else {
//                                                        selectedCategory = category.name
//                                                    }
//                                                    generateHapticFeedback()
//                                                    filterItems()
//                                                }
//                                            )
//                                        }
//                                    }
//                                }
//                                .padding(.horizontal)
//                            }
//                        }
//                        
//                        // 選択したカテゴリーの表示
//                        if let selectedCategory = selectedCategory, !oshiItems.isEmpty {
//                            VStack(alignment: .leading, spacing: 10) {
//                                HStack {
//                                    Text("\(selectedCategory)のアイテム")
//                                        .font(.system(size: 18, weight: .medium))
//                                        .foregroundColor(.black)
//                                    
//                                    Spacer()
//                                    
//                                    Button(action: {
//                                        generateHapticFeedback()
//                                        self.selectedCategory = nil
//                                        filterItems()
//                                    }) {
//                                        Text("クリア")
//                                            .font(.system(size: 14))
//                                            .foregroundColor(accentColor)
//                                    }
//                                }
//                                .padding(.horizontal)
//                                
//                                LazyVGrid(columns: [GridItem(.flexible())], spacing: 15) {
//                                    ForEach(oshiItems) { item in
//                                        NavigationLink(destination: OshiItemDetailView(item: item)) {
//                                            FavoriteItemRow(item: item)
//                                        }
//                                    }
//                                }
//                                .padding(.horizontal)
//                            }
//                        }
//                    }
//                    .padding(.bottom, 80)
//                }
//            }
//        }
//        .onAppear {
//            loadData()
//        }
//    }
//    
//    // 特定のタイプのアイテム数を取得
//    func itemCountForType(_ type: String) -> Int {
//        var count = 0
//        for item in allItems {
//            if item.itemType == type {
//                count += 1
//            }
//        }
//        return count
//    }
//    
//    // すべてのアイテムを格納する内部配列
//    func getAllItems() -> [OshiItem] {
//        return allItems
//    }
//    
//    // 選択されたカテゴリーでアイテムをフィルタリング
//    func filterItems() {
//        guard let selectedCategory = selectedCategory else {
//            // カテゴリー未選択時は何も表示しない
//            oshiItems = []
//            return
//        }
//        
//        var filteredItems: [OshiItem] = []
//        
//        // 既に取得済みのアイテムからフィルタリング
//        for item in allItems {
//            if item.category == selectedCategory || item.itemType == selectedCategory {
//                filteredItems.append(item)
//            }
//        }
//        
//        // 日付順でソート
//        filteredItems.sort { (item1, item2) -> Bool in
//            if let date1 = item1.date, let date2 = item2.date {
//                return date1 > date2
//            }
//            return false
//        }
//        
//        self.oshiItems = filteredItems
//    }
//    
//    // カテゴリーとアイテムの読み込み
//    func loadData() {
//        isLoading = true
//        categories = predefinedCategories
//        
//        guard let userId = Auth.auth().currentUser?.uid else {
//            isLoading = false
//            return
//        }
//        
//        let ref = Database.database().reference().child("oshiItems").child(userId)
//        ref.observeSingleEvent(of: .value) { snapshot in
//            var items: [OshiItem] = []
//            var counts: [String: Int] = [:]
//            
//            // カテゴリー初期値
//            for category in self.predefinedCategories {
//                counts[category.name] = 0
//            }
//            
//            for child in snapshot.children {
//                if let childSnapshot = child as? DataSnapshot,
//                   let value = childSnapshot.value as? [String: Any] {
//                    do {
//                        let jsonData = try JSONSerialization.data(withJSONObject: value)
//                        let item = try JSONDecoder().decode(OshiItem.self, from: jsonData)
//                        items.append(item)
//                        
//                        // カテゴリーカウントを更新
//                        if let category = item.category {
//                            counts[category] = (counts[category] ?? 0) + 1
//                        }
//                    } catch {
//                        print("デコードエラー: \(error.localizedDescription)")
//                    }
//                }
//            }
//            
//            DispatchQueue.main.async {
//                self.allItems = items
//                self.itemCounts = counts
//                self.isLoading = false
//            }
//        }
//    }
//}
//
//#Preview {
//    TopView()
//}
