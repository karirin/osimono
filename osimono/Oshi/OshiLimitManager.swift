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
    
    private init() {}
    
    // 推しの登録上限数を取得
    func getOshiLimit(isSubscribed: Bool) -> Int {
        return isSubscribed ? Int.max : freeUserOshiLimit
    }
    
    // 新しい推しを登録可能かチェック
    func canAddNewOshi(currentOshiCount: Int, isSubscribed: Bool) -> Bool {
        if isSubscribed {
            return true // サブスクリプション会員は無制限
        }
        return currentOshiCount < freeUserOshiLimit
    }
    
    // 残り登録可能数を取得
    func getRemainingOshiCount(currentOshiCount: Int, isSubscribed: Bool) -> Int {
        if isSubscribed {
            return Int.max
        }
        return max(0, freeUserOshiLimit - currentOshiCount)
    }
    
    // 制限に達しているかチェック
    func hasReachedOshiLimit(currentOshiCount: Int, isSubscribed: Bool) -> Bool {
        if isSubscribed {
            return false
        }
        return currentOshiCount >= freeUserOshiLimit
    }
    
    // 制限メッセージを取得
    func getLimitMessage(currentOshiCount: Int) -> String {
        return "無料プランでは推しを\(freeUserOshiLimit)人まで登録できます。\n現在 \(currentOshiCount)/\(freeUserOshiLimit) 人登録済みです。"
    }
}
