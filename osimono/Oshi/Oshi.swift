//
//  Oshi.swift
//  osimono
//
//  Created by Apple on 2025/04/13.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct Oshi: Identifiable, Codable {
    var id: String = UUID().uuidString
    var name: String
    var imageUrl: String?
    var backgroundImageUrl: String?  // 背景画像URL追加
    var memo: String?
    var createdAt: TimeInterval?
    
    enum CodingKeys: String, CodingKey {
        case id, name, imageUrl, backgroundImageUrl, memo, createdAt
    }
}
