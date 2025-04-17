////
////  FavoritesView.swift
////  osimono
////
////  Created by Apple on 2025/04/06.
////
//
//import SwiftUI
//import Firebase
//import FirebaseAuth
//
//struct FavoritesView: View {
//    @State private var oshiItems: [OshiItem] = []
//    @State private var isLoading = true
//    
//    // 色の定義
//    let primaryColor = Color(.systemPink) // 明るいピンク
//    let accentColor = Color(.purple) // 紫系
//    let backgroundColor = Color(.white) // 明るい背景色
//    let cardColor = Color(.white) // カード背景色
//    let textColor = Color(.black) // テキスト色
//    
//    var body: some View {
//        ZStack {
//            backgroundColor.ignoresSafeArea()
//            
//            if isLoading {
//                ProgressView()
//                    .scaleEffect(1.2)
//            } else if oshiItems.isEmpty {
//                VStack(spacing: 20) {
//                    Image(systemName: "heart.fill")
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: 60, height: 60)
//                        .foregroundColor(primaryColor.opacity(0.3))
//                    
//                    Text("お気に入りの推しアイテムがありません")
//                        .font(.system(size: 18, weight: .medium))
//                        .foregroundColor(.gray)
//                        .multilineTextAlignment(.center)
//                    
//                    Text("コレクションタブでお気に入り度を設定してみましょう")
//                        .font(.system(size: 14))
//                        .foregroundColor(.gray.opacity(0.7))
//                        .multilineTextAlignment(.center)
//                        .padding(.horizontal, 40)
//                }
//            } else {
//                ScrollView {
//                    // ヘッダー
//                    VStack(alignment: .leading) {
//                        Text("お気に入りの推しアイテム")
//                            .font(.system(size: 22, weight: .bold))
//                            .foregroundColor(primaryColor)
//                        
//                        Text("お気に入り度4以上のアイテム")
//                            .font(.system(size: 14))
//                            .foregroundColor(.gray)
//                    }
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding()
//                    
//                    // アイテム一覧
//                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
//                        ForEach(oshiItems) { item in
//                            NavigationLink(destination: OshiItemDetailView(item: item)) {
//                                FavoriteItemRow(item: item)
//                            }
//                        }
//                    }
//                    .padding(.horizontal)
//                    .padding(.bottom, 80)
//                }
//            }
//        }
//        .onAppear {
//            fetchFavoriteItems()
//        }
//    }
//    
//    // お気に入りアイテムを取得
//    func fetchFavoriteItems() {
//        guard let userId = Auth.auth().currentUser?.uid else {
//            isLoading = false
//            return
//        }
//        
//        isLoading = true
//        let ref = Database.database().reference().child("oshiItems").child(userId)
//        
//        ref.observeSingleEvent(of: .value) { snapshot in
//            var newItems: [OshiItem] = []
//            
//            for child in snapshot.children {
//                if let childSnapshot = child as? DataSnapshot,
//                   let value = childSnapshot.value as? [String: Any] {
//                    do {
//                        let jsonData = try JSONSerialization.data(withJSONObject: value)
//                        let item = try JSONDecoder().decode(OshiItem.self, from: jsonData)
//                        
//                        // お気に入り度が4以上のアイテムのみ表示
//                        if let favorite = item.favorite, favorite >= 4 {
//                            newItems.append(item)
//                        }
//                    } catch {
//                        print("デコードエラー: \(error.localizedDescription)")
//                    }
//                }
//            }
//            
//            // 日付順（新しい順）でソート
//            newItems.sort { (item1, item2) -> Bool in
//                if let date1 = item1.date, let date2 = item2.date {
//                    return date1 > date2
//                }
//                return false
//            }
//            
//            DispatchQueue.main.async {
//                self.oshiItems = newItems
//                self.isLoading = false
//            }
//        }
//    }
//}
