//
//  GroupChatManager.swift
//  osimono
//
//  グループチャット管理クラス - 既読マーク改善版
//

import Foundation
import FirebaseDatabase
import FirebaseAuth

class GroupChatManager: ObservableObject {
    private let database = Database.database().reference()
    
    // ユーザーID取得
    private var userId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    // グループチャットメッセージを保存
    func saveMessage(_ message: GroupChatMessage, completion: @escaping (Error?) -> Void) {
        guard let userId = userId else {
            completion(NSError(domain: "GroupChatManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "ユーザーが認証されていません"]))
            return
        }
        
        let messageRef = database.child("groupChats").child(userId).child(message.groupId).child("messages").child(message.id)
        messageRef.setValue(message.toDictionary()) { error, _ in
            if error == nil {
                // グループ情報も更新（最新メッセージ時間など）
                self.updateGroupLastMessage(groupId: message.groupId, message: message)
            }
            completion(error)
        }
    }
    
    // グループチャットメッセージを取得
    func fetchMessages(for groupId: String, completion: @escaping ([GroupChatMessage]?, Error?) -> Void) {
        guard let userId = userId else {
            completion(nil, NSError(domain: "GroupChatManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "ユーザーが認証されていません"]))
            return
        }
        
        let messagesRef = database.child("groupChats").child(userId).child(groupId).child("messages")
        messagesRef.queryOrdered(byChild: "timestamp").observe(.value) { snapshot in
            var messages: [GroupChatMessage] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let messageDict = childSnapshot.value as? [String: Any],
                   let message = GroupChatMessage.fromDictionary(messageDict) {
                    messages.append(message)
                }
            }
            
            // 時間順にソート
            messages.sort { $0.timestamp < $1.timestamp }
            completion(messages, nil)
        }
    }
    
    // グループ情報を作成または更新
    func createOrUpdateGroup(groupId: String, name: String, memberIds: [String], completion: @escaping (Error?) -> Void) {
        guard let userId = userId else {
            completion(NSError(domain: "GroupChatManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "ユーザーが認証されていません"]))
            return
        }
        
        print("グループ作成中 - ID: \(groupId), メンバー: \(memberIds)")
        
        let groupInfo = GroupChatInfo(
            id: groupId,
            name: name,
            memberIds: memberIds,
            createdAt: Date().timeIntervalSince1970,
            lastMessageTime: 0,
            lastMessage: nil
        )
        
        let groupRef = database.child("groupChats").child(userId).child(groupId).child("info")
        groupRef.setValue(groupInfo.toDictionary()) { error, _ in
            if let error = error {
                print("グループ情報保存エラー: \(error.localizedDescription)")
            } else {
                print("グループ情報保存成功 - メンバー: \(memberIds)")
            }
            completion(error)
        }
    }
    
    // グループメンバーを更新
    func updateGroupMembers(groupId: String, memberIds: [String], completion: @escaping (Error?) -> Void) {
        guard let userId = userId else {
            completion(NSError(domain: "GroupChatManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "ユーザーが認証されていません"]))
            return
        }
        
        let memberRef = database.child("groupChats").child(userId).child(groupId).child("info").child("memberIds")
        memberRef.setValue(memberIds) { error, _ in
            completion(error)
        }
    }
    
    // グループメンバーを取得
    func fetchGroupMembers(for groupId: String, completion: @escaping ([String]?, Error?) -> Void) {
        guard let userId = userId else {
            completion(nil, NSError(domain: "GroupChatManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "ユーザーが認証されていません"]))
            return
        }
        
        let memberRef = database.child("groupChats").child(userId).child(groupId).child("info").child("memberIds")
        memberRef.observeSingleEvent(of: .value) { snapshot in
            if let memberIds = snapshot.value as? [String] {
                completion(memberIds, nil)
            } else {
                completion([], nil)
            }
        }
    }
    
    // グループ一覧を取得
    func fetchGroupList(completion: @escaping ([GroupChatInfo]?, Error?) -> Void) {
        guard let userId = userId else {
            completion(nil, NSError(domain: "GroupChatManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "ユーザーが認証されていません"]))
            return
        }
        
        let groupsRef = database.child("groupChats").child(userId)
        groupsRef.observe(.value) { snapshot in
            var groups: [GroupChatInfo] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let groupData = childSnapshot.value as? [String: Any],
                   let infoData = groupData["info"] as? [String: Any],
                   let groupInfo = GroupChatInfo.fromDictionary(infoData) {
                    groups.append(groupInfo)
                }
            }
            
            // 最新メッセージ時間でソート
            groups.sort { $0.lastMessageTime > $1.lastMessageTime }
            completion(groups, nil)
        }
    }
    
    // グループの最新メッセージ情報を更新
    private func updateGroupLastMessage(groupId: String, message: GroupChatMessage) {
        guard let userId = userId else { return }
        
        let updates: [String: Any] = [
            "lastMessageTime": message.timestamp,
            "lastMessage": message.content
        ]
        
        let groupInfoRef = database.child("groupChats").child(userId).child(groupId).child("info")
        groupInfoRef.updateChildValues(updates)
    }
    
    // グループを削除
    func deleteGroup(groupId: String, completion: @escaping (Error?) -> Void) {
        guard let userId = userId else {
            completion(NSError(domain: "GroupChatManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "ユーザーが認証されていません"]))
            return
        }
        
        let groupRef = database.child("groupChats").child(userId).child(groupId)
        groupRef.removeValue { error, _ in
            completion(error)
        }
    }
    
    // 未読メッセージ数を取得
    func fetchUnreadMessageCount(for groupId: String, completion: @escaping (Int, Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(0, nil)
            return
        }
        
        // ユーザーが最後に読んだタイムスタンプを取得
        let userRef = Database.database().reference().child("users").child(userId)
        userRef.child("lastReadGroupChats").child(groupId).observeSingleEvent(of: .value) { snapshot in
            let lastReadTimestamp = snapshot.value as? TimeInterval ?? 0
            
            // グループチャットのメッセージを取得
            let messagesRef = Database.database().reference().child("groupChats").child(userId).child(groupId).child("messages")
            
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
                
                print("グループ \(groupId) の未読数: \(unreadCount) (最終既読: \(lastReadTimestamp))")
                completion(unreadCount, nil)
            }
        }
    }
    
    // グループチャットを既読としてマーク
    func markGroupChatAsRead(for groupId: String, completion: @escaping (Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        
        print("グループ \(groupId) を既読マーク中...")
        
        let currentTimestamp = Date().timeIntervalSince1970
        let userRef = Database.database().reference().child("users").child(userId)
        
        userRef.child("lastReadGroupChats").child(groupId).setValue(currentTimestamp) { error, _ in
            if let error = error {
                print("グループ既読マークエラー: \(error.localizedDescription)")
            } else {
                print("グループ \(groupId) の既読マーク完了 (タイムスタンプ: \(currentTimestamp))")
            }
            completion(error)
        }
    }
}

extension GroupChatMessage {
    func toChatMessage() -> ChatMessage {
        return ChatMessage(
            id: self.id,
            content: self.content,
            isUser: self.isUser,
            timestamp: self.timestamp,
            oshiId: self.senderId,
            itemId: nil
        )
    }
}
