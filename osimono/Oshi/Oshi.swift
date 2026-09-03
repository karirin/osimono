//
//  Oshi.swift
//  osimono
//
//  Created by Apple on 2025/04/13.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct Oshi: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    var imageUrl: String?
    var backgroundImageUrl: String?
    var memo: String?
    var createdAt: TimeInterval?
    
    // 性格関連の属性
    var personality: String?  // 性格（明るい、優しい、クールなど）
    var interests: [String]?  // 興味・関心（音楽、スポーツ、ゲームなど）
    var speaking_style: String? // 話し方の特徴（敬語、タメ口、絵文字多用など）
    var birthday: String?     // 誕生日
    var height: Int?          // 身長（cm）
    var favorite_color: String? // 好きな色
    var favorite_food: String?  // 好きな食べ物
    var disliked_food: String?  // 苦手な食べ物
    var hometown: String?     // 出身地
    var gender: String?       // 性別（男性、女性、その他）
    var user_nickname: String? // 推しがユーザーを呼ぶ呼び方（例：「〇〇ちゃん」「〇〇くん」「〇〇さん」など）
    var relationship_status: String? // 推しとユーザーの関係性
    var relationship_detail: String? // 距離感や接し方の詳細
    var shared_memory: String? // 二人の共有エピソード
    var signature_phrase: String? // 口癖・決め台詞
    var conversation_topics: [String]? // よく話す話題
    var forbidden_topics: [String]? // 避けたい話題
    
    // 新規追加：言語設定プロパティ
    var preferred_language: String? // 会話言語設定（"ja", "en", "auto"など）
    
    static func == (lhs: Oshi, rhs: Oshi) -> Bool {
        return lhs.id == rhs.id
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, imageUrl, backgroundImageUrl, memo, createdAt
        case personality, interests, speaking_style, birthday
        case height, favorite_color, favorite_food, disliked_food, hometown
        case gender, user_nickname
        case relationship_status, relationship_detail, shared_memory, signature_phrase
        case conversation_topics, forbidden_topics
        case preferred_language // 新しいキーを追加
    }
}
