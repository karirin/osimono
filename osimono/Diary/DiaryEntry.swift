//
//  DiaryEntry.swift
//  osimono
//
//  Created by Apple on 2025/05/04.
//

import SwiftUI

struct DiaryEntry: Identifiable, Codable {
    var id: String
    var oshiId: String
    var title: String
    var content: String
    var mood: Int // 1-5 scale
    var imageUrls: [String]?
    var createdAt: TimeInterval
    var updatedAt: TimeInterval
    var tags: [String]?
    
    init(id: String = UUID().uuidString,
         oshiId: String,
         title: String,
         content: String,
         mood: Int = 3,
         imageUrls: [String]? = nil,
         tags: [String]? = nil) {
        self.id = id
        self.oshiId = oshiId
        self.title = title
        self.content = content
        self.mood = mood
        self.imageUrls = imageUrls
        self.createdAt = Date().timeIntervalSince1970
        self.updatedAt = Date().timeIntervalSince1970
        self.tags = tags
    }
}
