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
    
    static func == (lhs: Oshi, rhs: Oshi) -> Bool {
        return lhs.id == rhs.id
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, imageUrl, backgroundImageUrl, memo, createdAt
    }
}
