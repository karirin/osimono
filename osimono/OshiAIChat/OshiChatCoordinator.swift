////
////  OshiChatCoordinator.swift
////  osimono
////
////  Created by Apple on 2025/05/08.
////
//
import SwiftUI
import FirebaseDatabase
import FirebaseAuth
//
//// 推しチャットシステム全体を管理するクラス
class OshiChatCoordinator: ObservableObject {
    static let shared = OshiChatCoordinator()
    
    @Published var recentChats: [OshiChatSession] = []
    @Published var isLoading: Bool = false
    
    private let database = Database.database().reference()
    
    private var userId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    // 最近のチャットセッションを取得
    func fetchRecentChats(completion: @escaping () -> Void) {
        guard let userId = userId else {
            completion()
            return
        }
        
        isLoading = true
        
        let chatRef = database.child("oshiChats").child(userId)
        chatRef.observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self else { return }
            
            var chatSessions: [OshiChatSession] = []
            var pendingFetches = 0
            
            // チャットがない場合
            if !snapshot.exists() {
                self.isLoading = false
                self.recentChats = []
                completion()
                return
            }
            
            // 推しIDごとにグループ化
            let oshiIds = snapshot.children.allObjects.compactMap { ($0 as? DataSnapshot)?.key }
            pendingFetches = oshiIds.count
            
            if pendingFetches == 0 {
                self.isLoading = false
                self.recentChats = []
                completion()
                return
            }
            
            for oshiId in oshiIds {
                // 各推しIDについて最新のチャットを取得
                self.fetchOshiDetails(oshiId: oshiId) { oshi in
                    self.fetchLatestChatForOshi(oshiId: oshiId) { latestMessage in
                        if let oshi = oshi, let latestMessage = latestMessage {
                            let session = OshiChatSession(
                                oshi: oshi,
                                latestMessage: latestMessage
                            )
                            chatSessions.append(session)
                        }
                        
                        pendingFetches -= 1
                        
                        // すべての取得が完了したら結果を更新
                        if pendingFetches == 0 {
                            DispatchQueue.main.async {
                                // 最新のメッセージの時間でソート
                                self.recentChats = chatSessions.sorted(by: { $0.latestMessage.timestamp > $1.latestMessage.timestamp })
                                self.isLoading = false
                                completion()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 推し情報の取得
    func fetchOshiDetails(oshiId: String, completion: @escaping (Oshi?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        
        let ref = Database.database().reference().child("oshis").child(userId).child(oshiId)
        
        ref.observeSingleEvent(of: .value) { snapshot in
            guard let data = snapshot.value as? [String: Any] else {
                completion(nil)
                return
            }
            
            let oshi = Oshi(
                id: oshiId,
                name: data["name"] as? String ?? "名前なし",
                imageUrl: data["imageUrl"] as? String,
                backgroundImageUrl: data["backgroundImageUrl"] as? String,
                memo: data["memo"] as? String,
                createdAt: data["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970,
                // 新しい属性を追加
                personality: data["personality"] as? String,
                interests: data["interests"] as? [String],
                speaking_style: data["speaking_style"] as? String,
                favorite_food: data["favorite_food"] as? String,
                disliked_food: data["disliked_food"] as? String,
                gender: data["gender"] as? String ?? "男性" // 性別情報を追加（デフォルトは男性）
            )
            
            completion(oshi)
        }
    }
    
    // 特定の推しの最新メッセージを取得
    private func fetchLatestChatForOshi(oshiId: String, completion: @escaping (ChatMessage?) -> Void) {
        guard let userId = userId else {
            completion(nil)
            return
        }
        
        let chatRef = database.child("oshiChats").child(userId).child(oshiId)
        chatRef.queryOrdered(byChild: "timestamp").queryLimited(toLast: 1).observeSingleEvent(of: .value) { snapshot in
            var latestMessage: ChatMessage? = nil
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let messageDict = childSnapshot.value as? [String: Any],
                   let message = ChatMessage.fromDictionary(messageDict) {
                    latestMessage = message
                    break
                }
            }
            
            completion(latestMessage)
        }
    }
    
    // 特定の推しとのチャット数を取得
    func fetchChatCount(for oshiId: String, completion: @escaping (Int) -> Void) {
        guard let userId = userId else {
            completion(0)
            return
        }
        
        let chatRef = database.child("oshiChats").child(userId).child(oshiId)
        chatRef.observeSingleEvent(of: .value) { snapshot in
            let count = snapshot.childrenCount
            completion(Int(count))
        }
    }
    
    // 特定の推しとの最後のチャット時間を取得
    func fetchLastChatTime(for oshiId: String, completion: @escaping (Date?) -> Void) {
        guard let userId = userId else {
            completion(nil)
            return
        }
        
        let chatRef = database.child("oshiChats").child(userId).child(oshiId)
        chatRef.queryOrdered(byChild: "timestamp").queryLimited(toLast: 1).observeSingleEvent(of: .value) { snapshot in
            var timestamp: TimeInterval? = nil
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let messageDict = childSnapshot.value as? [String: Any],
                   let messageTimestamp = messageDict["timestamp"] as? TimeInterval {
                    timestamp = messageTimestamp
                    break
                }
            }
            
            if let timestamp = timestamp {
                completion(Date(timeIntervalSince1970: timestamp))
            } else {
                completion(nil)
            }
        }
    }
}

// チャットセッションモデル（UIのリスト表示用）
struct OshiChatSession: Identifiable {
    var id: String { oshi.id }
    let oshi: Oshi
    let latestMessage: ChatMessage
}
