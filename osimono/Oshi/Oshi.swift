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
    
    static func == (lhs: Oshi, rhs: Oshi) -> Bool {
        return lhs.id == rhs.id
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, imageUrl, backgroundImageUrl, memo, createdAt
        case personality, interests, speaking_style, birthday
        case height, favorite_color, favorite_food, disliked_food, hometown
        case gender
    }
}
