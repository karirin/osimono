//
//  ChatDatabaseManager.swift
//  osimono
//
//  Created by Apple on 2025/05/08.
//

import Foundation
import FirebaseDatabase
import FirebaseAuth

// チャットメッセージのデータモデル
struct ChatMessage: Identifiable, Codable {
    let id: String
    let content: String
    let isUser: Bool
    let timestamp: TimeInterval
    let oshiId: String
    let itemId: String?  // 関連するアイテムID（オプショナル）
    
    // SwiftUIのIdentifiableプロトコル用
    var uuid: UUID {
        return UUID(uuidString: id) ?? UUID()
    }
    
    // Firebaseから読み込むためのイニシャライザ
    init(id: String, content: String, isUser: Bool, timestamp: TimeInterval, oshiId: String, itemId: String? = nil) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.oshiId = oshiId
        self.itemId = itemId
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
            itemId: itemId
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
    
    // 特定の推しのメッセージを全て取得
    func fetchMessages(for oshiId: String, completion: @escaping ([ChatMessage]?, Error?) -> Void) {
        guard let userId = userId else {
            completion(nil, NSError(domain: "ChatDatabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "ユーザーが認証されていません"]))
            return
        }
        
        let chatRef = database.child("oshiChats").child(userId).child(oshiId)
        chatRef.queryOrdered(byChild: "timestamp").observe(.value) { snapshot in
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
    }
    
    // 特定のアイテムに関連するメッセージを取得
    func fetchMessages(for oshiId: String, itemId: String, completion: @escaping ([ChatMessage]?, Error?) -> Void) {
        guard let userId = userId else {
            completion(nil, NSError(domain: "ChatDatabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "ユーザーが認証されていません"]))
            return
        }
        
        let chatRef = database.child("oshiChats").child(userId).child(oshiId)
        chatRef.queryOrdered(byChild: "itemId").queryEqual(toValue: itemId).observe(.value) { snapshot in
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
            
            // 指定された推しの最新メッセージを取得
            let messagesRef = Database.database().reference().child("messages").child(userId).child(oshiId)
            messagesRef.queryOrdered(byChild: "timestamp")
                .queryEnding(atValue: false, childKey: "isUser") // ユーザー以外（AI/推し）からのメッセージのみ
                .observeSingleEvent(of: .value) { snapshot in
                    
                    var unreadCount = 0
                    
                    for child in snapshot.children {
                        guard let childSnapshot = child as? DataSnapshot,
                              let messageData = childSnapshot.value as? [String: Any],
                              let timestamp = messageData["timestamp"] as? TimeInterval,
                              let isUser = messageData["isUser"] as? Bool,
                              !isUser, // ユーザー以外（AI/推し）からのメッセージのみカウント
                              timestamp > lastReadTimestamp // 最後に読んだ時間より後のメッセージ
                        else { continue }
                        
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
}
