//
//  ChatDatabaseManager.swift
//  osimono
//
//  Created by Apple on 2025/05/08.
//

import Foundation
import FirebaseDatabase
import FirebaseAuth

/// チャット履歴のリアルタイム監視。解放されると監視を解除する
/// （解除しないと画面を開くたびに監視が増え、別の推しのチャット更新で表示が上書きされる）
final class ChatMessagesObservation {
    private let query: DatabaseQuery
    private let handle: DatabaseHandle
    private var isCancelled = false
    
    init(query: DatabaseQuery, handle: DatabaseHandle) {
        self.query = query
        self.handle = handle
    }
    
    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        query.removeObserver(withHandle: handle)
    }
    
    deinit {
        cancel()
    }
}

// チャットメッセージのデータモデル
struct ChatMessage: Identifiable, Codable {
    let id: String
    let content: String
    let isUser: Bool
    let timestamp: TimeInterval
    let oshiId: String
    let itemId: String?  // 関連するアイテムID（オプショナル）
    // ロールプレイの構造化返答（AIメッセージのみ）。content にはセリフ本文が入る
    var emotion: String? = nil
    var action: String? = nil
    var innerThought: String? = nil
    
    // SwiftUIのIdentifiableプロトコル用
    var uuid: UUID {
        return UUID(uuidString: id) ?? UUID()
    }
    
    // Firebaseから読み込むためのイニシャライザ
    init(id: String, content: String, isUser: Bool, timestamp: TimeInterval, oshiId: String, itemId: String? = nil, emotion: String? = nil, action: String? = nil, innerThought: String? = nil) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.oshiId = oshiId
        self.itemId = itemId
        self.emotion = emotion
        self.action = action
        self.innerThought = isUser ? nil : RoleplayReply.cleanInnerThought(innerThought)
    }

    var characterEmotion: CharacterEmotion {
        CharacterEmotion(rawOrNeutral: emotion)
    }
    
    // Dictionary変換用
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "content": content,
            "isUser": isUser,
            "timestamp": timestamp,
            "oshiId": oshiId
        ]
        
        if let itemId = itemId {
            dict["itemId"] = itemId
        }
        if let emotion = emotion {
            dict["emotion"] = emotion
        }
        if let action = action, !action.isEmpty {
            dict["action"] = action
        }
        if !isUser, let innerThought = RoleplayReply.cleanInnerThought(innerThought) {
            dict["innerThought"] = innerThought
        }
        
        return dict
    }
    
    // Dictionary -> ChatMessage変換用
    static func fromDictionary(_ dict: [String: Any]) -> ChatMessage? {
        guard let id = dict["id"] as? String,
              let content = dict["content"] as? String,
              let isUser = dict["isUser"] as? Bool,
              let timestamp = dict["timestamp"] as? TimeInterval,
              let oshiId = dict["oshiId"] as? String else {
            return nil
        }
        
        let itemId = dict["itemId"] as? String
        
        return ChatMessage(
            id: id,
            content: content,
            isUser: isUser,
            timestamp: timestamp,
            oshiId: oshiId,
            itemId: itemId,
            emotion: dict["emotion"] as? String,
            action: dict["action"] as? String,
            innerThought: dict["innerThought"] as? String
        )
    }
}

// UIにバインドするためのChatMessage拡張
extension ChatMessage {
    // SwiftUIのView用の簡易変換イニシャライザ
    init(id: UUID, content: String, isUser: Bool, timestamp: Date) {
        self.id = id.uuidString
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp.timeIntervalSince1970
        self.oshiId = ""  // 必要に応じて設定
        self.itemId = nil
    }
}

// チャットデータベース管理クラス
class ChatDatabaseManager {
    static let shared = ChatDatabaseManager()
    
    private let database = Database.database().reference()
    
    // ユーザーID取得
    private var userId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    // メッセージを保存
    func saveMessage(_ message: ChatMessage, completion: @escaping (Error?) -> Void) {
        guard let userId = userId else {
            completion(NSError(domain: "ChatDatabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "ユーザーが認証されていません"]))
            return
        }
        
        let chatRef = database.child("oshiChats").child(userId).child(message.oshiId).child(message.id)
        chatRef.setValue(message.toDictionary()) { error, _ in
            completion(error)
        }
    }

    // 特定の推しのメッセージを単発で取得
    func fetchRecentMessagesOnce(for oshiId: String, limit: UInt = 10, completion: @escaping ([ChatMessage]?, Error?) -> Void) {
        guard let userId = userId else {
            completion(nil, NSError(domain: "ChatDatabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "ユーザーが認証されていません"]))
            return
        }

        let chatRef = database.child("oshiChats").child(userId).child(oshiId)
        chatRef.queryOrdered(byChild: "timestamp").queryLimited(toLast: limit).observeSingleEvent(of: .value) { snapshot in
            var messages: [ChatMessage] = []

            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let messageDict = childSnapshot.value as? [String: Any],
                   let message = ChatMessage.fromDictionary(messageDict) {
                    messages.append(message)
                }
            }

            messages.sort { $0.timestamp < $1.timestamp }
            completion(messages, nil)
        }
    }

    // 特定の推しの最新メッセージを単発で取得
    func fetchLatestMessageOnce(for oshiId: String, completion: @escaping (ChatMessage?, Error?) -> Void) {
        fetchRecentMessagesOnce(for: oshiId, limit: 1) { messages, error in
            completion(messages?.last, error)
        }
    }
    
    // 特定の推しのメッセージを全て取得
    /// 戻り値を保持している間だけ監視が続く。破棄すると監視を解除する
    @discardableResult
    func fetchMessages(for oshiId: String, completion: @escaping ([ChatMessage]?, Error?) -> Void) -> ChatMessagesObservation? {
        guard let userId = userId else {
            completion(nil, NSError(domain: "ChatDatabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "ユーザーが認証されていません"]))
            return nil
        }
        
        let query = database.child("oshiChats").child(userId).child(oshiId).queryOrdered(byChild: "timestamp")
        let handle = query.observe(.value) { snapshot in
            var messages: [ChatMessage] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let messageDict = childSnapshot.value as? [String: Any],
                   let message = ChatMessage.fromDictionary(messageDict) {
                    messages.append(message)
                }
            }
            
            // 時間順にソート
            messages.sort { $0.timestamp < $1.timestamp }
            completion(messages, nil)
        }
        return ChatMessagesObservation(query: query, handle: handle)
    }

    // 特定の推しの最近のメッセージを取得
    func fetchRecentMessages(for oshiId: String, limit: UInt = 20, completion: @escaping ([ChatMessage]?, Error?) -> Void) {
        guard let userId = userId else {
            completion(nil, NSError(domain: "ChatDatabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "ユーザーが認証されていません"]))
            return
        }

        let chatRef = database.child("oshiChats").child(userId).child(oshiId)
        chatRef.queryOrdered(byChild: "timestamp").queryLimited(toLast: limit).observeSingleEvent(of: .value) { snapshot in
            var messages: [ChatMessage] = []

            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let messageDict = childSnapshot.value as? [String: Any],
                   let message = ChatMessage.fromDictionary(messageDict) {
                    messages.append(message)
                }
            }

            messages.sort { $0.timestamp < $1.timestamp }
            completion(messages, nil)
        }
    }
    
    // 特定のアイテムに関連するメッセージを取得
    @discardableResult
    func fetchMessages(for oshiId: String, itemId: String, completion: @escaping ([ChatMessage]?, Error?) -> Void) -> ChatMessagesObservation? {
        guard let userId = userId else {
            completion(nil, NSError(domain: "ChatDatabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "ユーザーが認証されていません"]))
            return nil
        }
        
        let query = database.child("oshiChats").child(userId).child(oshiId).queryOrdered(byChild: "itemId").queryEqual(toValue: itemId)
        let handle = query.observe(.value) { snapshot in
            var messages: [ChatMessage] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let messageDict = childSnapshot.value as? [String: Any],
                   let message = ChatMessage.fromDictionary(messageDict) {
                    messages.append(message)
                }
            }
            
            // 時間順にソート
            messages.sort { $0.timestamp < $1.timestamp }
            completion(messages, nil)
        }
        return ChatMessagesObservation(query: query, handle: handle)
    }
    
    // 未読メッセージの数を取得する
    func fetchUnreadMessageCount(for oshiId: String, completion: @escaping (Int, Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(0, nil)
            return
        }
        
        // ユーザーが最後に読んだタイムスタンプを取得
        let userRef = Database.database().reference().child("users").child(userId)
        userRef.child("lastReadTimestamps").child(oshiId).observeSingleEvent(of: .value) { snapshot in
            let lastReadTimestamp = snapshot.value as? TimeInterval ?? 0
            
            // ここを修正: messages → oshiChats に変更
            let messagesRef = Database.database().reference().child("oshiChats").child(userId).child(oshiId)
            
            // クエリ修正: queryEnding は使わず、単純に timestamp でソートして全件取得
            messagesRef.queryOrdered(byChild: "timestamp").observeSingleEvent(of: .value) { snapshot in
                
                var unreadCount = 0
                
                for child in snapshot.children {
                    guard let childSnapshot = child as? DataSnapshot,
                          let messageData = childSnapshot.value as? [String: Any],
                          let timestamp = messageData["timestamp"] as? TimeInterval,
                          let isUser = messageData["isUser"] as? Bool,
                          !isUser, // ユーザー以外（AI/推し）からのメッセージのみカウント
                          timestamp > lastReadTimestamp // 最後に読んだ時間より後のメッセージ
                    else {
                        continue
                    }
                    
                    unreadCount += 1
                }
                
                completion(unreadCount, nil)
            }
        }
    }
    
    // すべての推しの未読メッセージ総数を取得
    func fetchTotalUnreadMessageCount(forOshiList oshiList: [Oshi], completion: @escaping (Int, Error?) -> Void) {
        let dispatchGroup = DispatchGroup()
        var totalUnreadCount = 0
        var fetchError: Error?
        
        for oshi in oshiList {
            dispatchGroup.enter()
            
            fetchUnreadMessageCount(for: oshi.id) { count, error in
                if let error = error {
                    fetchError = error
                } else {
                    totalUnreadCount += count
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(totalUnreadCount, fetchError)
        }
    }
    
    // メッセージを既読としてマーク
    func markMessagesAsRead(for oshiId: String, completion: @escaping (Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        
        let currentTimestamp = Date().timeIntervalSince1970
        let userRef = Database.database().reference().child("users").child(userId)
        
        userRef.child("lastReadTimestamps").child(oshiId).setValue(currentTimestamp) { error, _ in
            completion(error)
        }
    }
    
    func updateMessage(_ message: ChatMessage, completion: @escaping (Error?) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "ユーザーが認証されていません"]))
            return
        }
        
        // 正しいパスを使用: oshiChats
        let chatRef = database.child("oshiChats").child(userID).child(message.oshiId).child(message.id)
        
        let messageData = message.toDictionary()
        
        chatRef.updateChildValues(messageData) { error, _ in
            if let error = error {
                print("❌ メッセージ更新エラー: \(error.localizedDescription)")
            } else {
                print("✅ メッセージ更新完了")
            }
            completion(error)
        }
    }
    
    // メッセージ削除
    func deleteMessage(_ message: ChatMessage, completion: @escaping (Error?) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "ユーザーが認証されていません"]))
            return
        }
        
        // 正しいパスを使用: oshiChats
        let chatRef = database.child("oshiChats").child(userID).child(message.oshiId).child(message.id)
        
        chatRef.removeValue { error, _ in
            if let error = error {
                print("❌ メッセージ削除エラー: \(error.localizedDescription)")
            } else {
                print("✅ メッセージ削除完了")
            }
            completion(error)
        }
    }
}
