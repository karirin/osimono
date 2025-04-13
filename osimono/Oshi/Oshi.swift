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
    var memo: String?
    var createdAt: TimeInterval?
}
