//
//  APIKeyManager.swift
//  osimono
//
//  Created by Apple on 2025/05/05.
//

import Foundation

class APIKeyManager {
    static let shared = APIKeyManager()
    
    var openAIAPIKey: String {
        // Info.plistからキーを取得
        guard let apiKey = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String else {
            fatalError("APIキーを設定してください")
        }
        return apiKey
    }
}
