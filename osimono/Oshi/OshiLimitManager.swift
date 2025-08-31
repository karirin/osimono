//
//  OshiLimitManager.swift
//  osimono
//
//  推しの登録数制限を管理するクラス
//

import Foundation
import FirebaseAuth

class OshiLimitManager {
    static let shared = OshiLimitManager()
    
    // 無料ユーザーの推し登録上限
    private let freeUserOshiLimit = 5
    
    // 管理者ユーザーIDリスト
    private let adminUserIds = [
        "bZwehJdm4RTQ7JWjl20yaxTWS7l2"
        // 必要に応じて他の管理者IDを追加
    ]
    
    private init() {}
    
    // 現在のユーザーが管理者かどうかをチェック（外部からも呼び出し可能）
    func isCurrentUserAdmin() -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return false
        }
        return adminUserIds.contains(currentUserId)
    }
    
    // 推しの登録上限数を取得
    func getOshiLimit(isSubscribed: Bool) -> Int {
        // 管理者は無制限
        if isCurrentUserAdmin() {
            return Int.max
        }
        return isSubscribed ? Int.max : freeUserOshiLimit
    }
    
    // 新しい推しを登録可能かチェック
    func canAddNewOshi(currentOshiCount: Int, isSubscribed: Bool) -> Bool {
        // 管理者は無制限で登録可能
        if isCurrentUserAdmin() {
            return true
        }
        
        if isSubscribed {
            return true // サブスクリプション会員は無制限
        }
        return currentOshiCount < freeUserOshiLimit
    }
    
    // 残り登録可能数を取得
    func getRemainingOshiCount(currentOshiCount: Int, isSubscribed: Bool) -> Int {
        // 管理者は無制限
        if isCurrentUserAdmin() {
            return Int.max
        }
        
        if isSubscribed {
            return Int.max
        }
        return max(0, freeUserOshiLimit - currentOshiCount)
    }
    
    // 制限に達しているかチェック
    func hasReachedOshiLimit(currentOshiCount: Int, isSubscribed: Bool) -> Bool {
        // 管理者は制限なし
        if isCurrentUserAdmin() {
            return false
        }
        
        if isSubscribed {
            return false
        }
        return currentOshiCount >= freeUserOshiLimit
    }
    
    // 制限メッセージを取得
    func getLimitMessage(currentOshiCount: Int) -> String {
        // 管理者の場合は特別メッセージ
        if isCurrentUserAdmin() {
            return "管理者権限により、無制限で推しを登録できます。\n現在 \(currentOshiCount) 人登録済みです。"
        }
        
        return "無料プランでは推しを\(freeUserOshiLimit)人まで登録できます。\n現在 \(currentOshiCount)/\(freeUserOshiLimit) 人登録済みです。"
    }
    
    // デバッグ用：現在のユーザーの権限状態を取得
    func getUserPermissionStatus() -> String {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return "ユーザー未認証"
        }
        
        if isCurrentUserAdmin() {
            return "管理者権限ユーザー (ID: \(currentUserId))"
        } else {
            return "一般ユーザー (ID: \(currentUserId))"
        }
    }
    
    // 管理者IDを安全に追加するメソッド（必要に応じて）
    func isUserAdmin(userId: String) -> Bool {
        return adminUserIds.contains(userId)
    }
}
