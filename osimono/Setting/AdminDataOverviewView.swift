//
//  AdminDataOverviewView.swift
//  osimono
//
//  Created by Apple on 2025/07/22.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseDatabase

// MARK: - データ管理用の構造体
struct AdminUserData: Identifiable {
    let id: String // userID
    let username: String
    let oshiList: [Oshi]
    let oshiItemCount: Int
    let locationCount: Int
    let selectedOshiId: String?
    
    var displayName: String {
        return username.isEmpty ? "名前未設定" : username
    }
}

struct AdminOshiItemData: Identifiable {
    let id: String
    let userId: String
    let username: String
    let oshiId: String
    let oshiName: String
    let title: String
    let itemType: String
    let memo: String
    let createdAt: Date
    let price: Int?
    let imageUrl: String?
}

struct AdminLocationData: Identifiable {
    let id: String
    let userId: String
    let username: String
    let oshiId: String
    let oshiName: String
    let title: String
    let category: String
    let latitude: Double
    let longitude: Double
    let rating: Int
    let createdAt: Date
    let imageUrl: String?
}

// MARK: - メインの管理者ビュー
struct AdminDataOverviewView: View {
    @State private var allUserData: [AdminUserData] = []
    @State private var allOshiItems: [AdminOshiItemData] = []
    @State private var allLocations: [AdminLocationData] = []
    @State private var isLoading = true
    @State private var selectedTab = 0
    @State private var searchText = ""
    
    private let tabs = ["ユーザー一覧", "推し活記録", "聖地巡礼"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // タブ選択
                TabSelector(selectedTab: $selectedTab, tabs: tabs)
                    .padding(.horizontal)
                
//                // 検索バー
//                SearchBar(text: $searchText)
//                    .padding(.horizontal)
                
                if isLoading {
                    Spacer()
                    ProgressView("データを取得中...")
                        .scaleEffect(1.2)
                    Spacer()
                } else {
                    // タブごとの内容
                    TabView(selection: $selectedTab) {
                        UserListView(userData: filteredUserData)
                            .tag(0)
                        
                        OshiItemListView(items: filteredOshiItems)
                            .tag(1)
                        
                        LocationListView(locations: filteredLocations)
                            .tag(2)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
            }
            .navigationTitle("管理者ダッシュボード")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadAllData()
            }
        }
    }
    
    // MARK: - フィルタリング
    var filteredUserData: [AdminUserData] {
        if searchText.isEmpty {
            return allUserData
        }
        return allUserData.filter { user in
            user.displayName.localizedCaseInsensitiveContains(searchText) ||
            user.oshiList.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var filteredOshiItems: [AdminOshiItemData] {
        if searchText.isEmpty {
            return allOshiItems.sorted { $0.createdAt > $1.createdAt }
        }
        return allOshiItems.filter { item in
            item.title.localizedCaseInsensitiveContains(searchText) ||
            item.username.localizedCaseInsensitiveContains(searchText) ||
            item.oshiName.localizedCaseInsensitiveContains(searchText) ||
            item.itemType.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.createdAt > $1.createdAt }
    }
    
    var filteredLocations: [AdminLocationData] {
        if searchText.isEmpty {
            return allLocations.sorted { $0.createdAt > $1.createdAt }
        }
        return allLocations.filter { location in
            location.title.localizedCaseInsensitiveContains(searchText) ||
            location.username.localizedCaseInsensitiveContains(searchText) ||
            location.oshiName.localizedCaseInsensitiveContains(searchText) ||
            location.category.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.createdAt > $1.createdAt }
    }
    
    // MARK: - データ取得
    func loadAllData() {
        isLoading = true
        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        loadAllUsers { users in
            self.allUserData = users
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        loadAllOshiItems { items in
            self.allOshiItems = items
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        loadAllLocations { locations in
            self.allLocations = locations
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            self.isLoading = false
        }
    }
    
    func loadAllUsers(completion: @escaping ([AdminUserData]) -> Void) {
        let usersRef = Database.database().reference().child("users")
        let oshisRef = Database.database().reference().child("oshis")
        
        usersRef.observeSingleEvent(of: .value) { snapshot in
            var userData: [AdminUserData] = []
            let dispatchGroup = DispatchGroup()
            
            for child in snapshot.children {
                guard let childSnapshot = child as? DataSnapshot,
                      let userDict = childSnapshot.value as? [String: Any] else { continue }
                
                let userId = childSnapshot.key
                let username = userDict["username"] as? String ?? ""
                let selectedOshiId = userDict["selectedOshiId"] as? String
                
                dispatchGroup.enter()
                
                // 各ユーザーの推しデータを取得
                oshisRef.child(userId).observeSingleEvent(of: .value) { oshiSnapshot in
                    var oshiList: [Oshi] = []
                    
                    for oshiChild in oshiSnapshot.children {
                        guard let oshiChildSnapshot = oshiChild as? DataSnapshot,
                              let oshiDict = oshiChildSnapshot.value as? [String: Any] else { continue }
                        
                        let oshi = Oshi(
                            id: oshiChildSnapshot.key,
                            name: oshiDict["name"] as? String ?? "名前なし",
                            imageUrl: oshiDict["imageUrl"] as? String,
                            backgroundImageUrl: oshiDict["backgroundImageUrl"] as? String,
                            memo: oshiDict["memo"] as? String,
                            createdAt: oshiDict["createdAt"] as? TimeInterval
                        )
                        oshiList.append(oshi)
                    }
                    
                    // アイテム数とロケーション数を取得（簡略化のため0で初期化）
                    let adminUser = AdminUserData(
                        id: userId,
                        username: username,
                        oshiList: oshiList,
                        oshiItemCount: 0,
                        locationCount: 0,
                        selectedOshiId: selectedOshiId
                    )
                    
                    DispatchQueue.main.async {
                        userData.append(adminUser)
                    }
                    
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                completion(userData.sorted { $0.displayName < $1.displayName })
            }
        }
    }
    
    func loadAllOshiItems(completion: @escaping ([AdminOshiItemData]) -> Void) {
        let oshiItemsRef = Database.database().reference().child("oshiItems")
        
        oshiItemsRef.observeSingleEvent(of: .value) { snapshot in
            var allItems: [AdminOshiItemData] = []
            
            for userChild in snapshot.children {
                guard let userSnapshot = userChild as? DataSnapshot else { continue }
                let userId = userSnapshot.key
                
                for oshiChild in userSnapshot.children {
                    guard let oshiSnapshot = oshiChild as? DataSnapshot else { continue }
                    let oshiId = oshiSnapshot.key
                    
                    for itemChild in oshiSnapshot.children {
                        guard let itemSnapshot = itemChild as? DataSnapshot,
                              let itemDict = itemSnapshot.value as? [String: Any] else { continue }
                        
                        let createdAt = Date(timeIntervalSince1970: itemDict["createdAt"] as? TimeInterval ?? 0)
                        
                        let item = AdminOshiItemData(
                            id: itemSnapshot.key,
                            userId: userId,
                            username: getUserName(for: userId),
                            oshiId: oshiId,
                            oshiName: getOshiName(for: userId, oshiId: oshiId),
                            title: itemDict["title"] as? String ?? "タイトルなし",
                            itemType: itemDict["itemType"] as? String ?? "不明",
                            memo: itemDict["memo"] as? String ?? "",
                            createdAt: createdAt,
                            price: itemDict["price"] as? Int,
                            imageUrl: itemDict["imageUrl"] as? String
                        )
                        
                        allItems.append(item)
                    }
                }
            }
            
            DispatchQueue.main.async {
                completion(allItems)
            }
        }
    }
    
    func loadAllLocations(completion: @escaping ([AdminLocationData]) -> Void) {
        let locationsRef = Database.database().reference().child("locations")
        
        locationsRef.observeSingleEvent(of: .value) { snapshot in
            var allLocations: [AdminLocationData] = []
            
            for userChild in snapshot.children {
                guard let userSnapshot = userChild as? DataSnapshot else { continue }
                let userId = userSnapshot.key
                
                for oshiChild in userSnapshot.children {
                    guard let oshiSnapshot = oshiChild as? DataSnapshot else { continue }
                    let oshiId = oshiSnapshot.key
                    
                    for locationChild in oshiSnapshot.children {
                        guard let locationSnapshot = locationChild as? DataSnapshot,
                              let locationDict = locationSnapshot.value as? [String: Any] else { continue }
                        
                        let createdAt = Date(timeIntervalSince1970: locationDict["createdAt"] as? TimeInterval ?? 0)
                        
                        let location = AdminLocationData(
                            id: locationSnapshot.key,
                            userId: userId,
                            username: getUserName(for: userId),
                            oshiId: oshiId,
                            oshiName: getOshiName(for: userId, oshiId: oshiId),
                            title: locationDict["title"] as? String ?? "タイトルなし",
                            category: locationDict["category"] as? String ?? "不明",
                            latitude: locationDict["latitude"] as? Double ?? 0,
                            longitude: locationDict["longitude"] as? Double ?? 0,
                            rating: locationDict["ratingSum"] as? Int ?? 0,
                            createdAt: createdAt,
                            imageUrl: locationDict["imageURL"] as? String
                        )
                        
                        allLocations.append(location)
                    }
                }
            }
            
            DispatchQueue.main.async {
                completion(allLocations)
            }
        }
    }
    
    // ヘルパー関数
    func getUserName(for userId: String) -> String {
        return allUserData.first { $0.id == userId }?.displayName ?? "不明なユーザー"
    }
    
    func getOshiName(for userId: String, oshiId: String) -> String {
        guard let userData = allUserData.first(where: { $0.id == userId }) else {
            return "不明な推し"
        }
        return userData.oshiList.first { $0.id == oshiId }?.name ?? "不明な推し"
    }
}

// MARK: - UI コンポーネント
struct TabSelector: View {
    @Binding var selectedTab: Int
    let tabs: [String]
    
    var body: some View {
        HStack {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring()) {
                        selectedTab = index
                    }
                }) {
//                    VStack(spacing: 4) {
//                        Text(tabs[index])
//                            .font(.system(size: 16, weight: selectedTab == index ? .bold : .regular))
//                            .foregroundColor(selectedTab == index ? .pink : .gray)
//                        
//                        Rectangle()
//                            .height(2)
//                            .foregroundColor(selectedTab == index ? .pink : .clear)
//                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 10)
    }
}

struct UserListView: View {
    let userData: [AdminUserData]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(userData) { user in
                    UserCardView(user: user)
                }
            }
            .padding()
        }
    }
}

struct UserCardView: View {
    let user: AdminUserData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(user.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("ユーザーID: \(user.id)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("推し: \(user.oshiList.count)人")
                        .font(.caption)
                        .foregroundColor(.pink)
                    
                    Text("記録: \(user.oshiItemCount)件")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if !user.oshiList.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(user.oshiList) { oshi in
                            Text(oshi.name)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.pink.opacity(0.1))
                                .foregroundColor(.pink)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4)
    }
}

struct OshiItemListView: View {
    let items: [AdminOshiItemData]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(items) { item in
                    OshiItemCardView(item: item)
                }
            }
            .padding()
        }
    }
}

struct OshiItemCardView: View {
    let item: AdminOshiItemData
    
    var body: some View {
        HStack {
            AsyncImage(url: item.imageUrl != nil ? URL(string: item.imageUrl!) : nil) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 60, height: 60)
            .clipped()
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    Text(item.itemType)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.pink.opacity(0.2))
                        .foregroundColor(.pink)
                        .cornerRadius(8)
                    
                    Spacer()
                }
                
                Text("\(item.username) → \(item.oshiName)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(DateFormatter.adminDate.string(from: item.createdAt))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4)
    }
}

struct LocationListView: View {
    let locations: [AdminLocationData]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(locations) { location in
                    LocationCardView1(location: location)
                }
            }
            .padding()
        }
    }
}

struct LocationCardView1: View {
    let location: AdminLocationData
    
    var body: some View {
        HStack {
            AsyncImage(url: location.imageUrl != nil ? URL(string: location.imageUrl!) : nil) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "mappin")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 60, height: 60)
            .clipped()
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(location.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    Text(location.category)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    
                    HStack(spacing: 2) {
                        ForEach(0..<min(location.rating, 5), id: \.self) { _ in
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Spacer()
                }
                
                Text("\(location.username) → \(location.oshiName)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("緯度: \(location.latitude, specifier: "%.4f"), 経度: \(location.longitude, specifier: "%.4f")")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(DateFormatter.adminDate.string(from: location.createdAt))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4)
    }
}

// MARK: - 拡張
extension DateFormatter {
    static let adminDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}
