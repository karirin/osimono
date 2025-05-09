//
//  UnreadPostTracker.swift
//  osimono
//
//  Created by Apple on 2025/05/09.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseDatabase

// 未読投稿を管理するクラス
class UnreadPostTracker {
    static let shared = UnreadPostTracker()
    
    private init() {}
    
    // 特定の推しの未読投稿数を取得
    func fetchUnreadPostCount(for oshiId: String, completion: @escaping (Int, Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(0, nil)
            return
        }
        
        // ユーザーが最後に投稿を読んだタイムスタンプを取得
        let userRef = Database.database().reference().child("users").child(userId)
        userRef.child("lastReadPosts").child(oshiId).observeSingleEvent(of: .value) { snapshot in
            let lastReadTimestamp = snapshot.value as? TimeInterval ?? 0
            
            // 指定された推しの投稿を取得し、未読のものをカウント
            let postsRef = Database.database().reference().child("oshiItems").child(oshiId)
            postsRef.queryOrdered(byChild: "createdAt").observeSingleEvent(of: .value) { snapshot in
                var unreadCount = 0
                
                for child in snapshot.children {
                    guard let childSnapshot = child as? DataSnapshot,
                          let postData = childSnapshot.value as? [String: Any],
                          let createdAt = postData["createdAt"] as? TimeInterval,
                          createdAt > lastReadTimestamp // 最後に読んだ時間より後に作成された投稿
                    else { continue }
                    
                    unreadCount += 1
                }
                
                completion(unreadCount, nil)
            }
        }
    }
    
    // すべての推しの未読投稿の総数を取得
    func fetchTotalUnreadPostCount(forOshiList oshiList: [Oshi], completion: @escaping (Int, Error?) -> Void) {
        let dispatchGroup = DispatchGroup()
        var totalUnreadCount = 0
        var fetchError: Error?
        
        for oshi in oshiList {
            dispatchGroup.enter()
            
            fetchUnreadPostCount(for: oshi.id) { count, error in
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
    
    // 投稿を既読としてマーク
    func markPostsAsRead(for oshiId: String, completion: @escaping (Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        
        let currentTimestamp = Date().timeIntervalSince1970
        let userRef = Database.database().reference().child("users").child(userId)
        
        userRef.child("lastReadPosts").child(oshiId).setValue(currentTimestamp) { error, _ in
            completion(error)
        }
    }
}
