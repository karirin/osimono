//
//  AIMessageGenerator.swift
//  osimono
//

import Foundation
import SwiftUI

class AIClient {
    static let shared = AIClient()
    private let apiKey: String

    private init?() {
        guard let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String else {
            print("❌ OPENAI_API_KEYが見つかりません")
            return nil
        }
        self.apiKey = key
    }

    func sendChat(messages: [[String: String]], completion: @escaping (String?, Error?) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4.1-nano-2025-04-14",
            "messages": messages,
            "temperature": 0.8
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let data = data else {
                completion(nil, NSError(domain: "NoData", code: 0))
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let choices = json?["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(content, nil)
                } else {
                    completion(nil, NSError(domain: "InvalidResponse", code: 1))
                }
            } catch {
                completion(nil, error)
            }
        }.resume()
    }
}

class LocalizedPromptManager {
    static let shared = LocalizedPromptManager()
    
    private init() {}
    
    // 指定された言語でシステムプロンプトを取得
    func getSystemPromptTemplate(for language: String, oshiName: String) -> String {
        let template = LanguageManager.shared.localizedString("ai_system_prompt_template", language: language, fallback: "You are %@, and please have natural conversations with your fan in a close relationship.")
        return String(format: template, oshiName)
    }
    
    // 会話ルールを取得
    func getConversationRules(for language: String) -> String {
        return LanguageManager.shared.localizedString("ai_conversation_rules", language: language, fallback: """
        【Important Conversation Rules】
        • Reply briefly and naturally (1-2 sentences)
        • Avoid overly polite AI-like responses
        • Listen carefully and give natural reactions
        • Mix in questions occasionally
        • Use minimal or no emojis
        """)
    }
    
    // 会話ガイドラインを取得
    func getConversationGuidelines(for language: String) -> String {
        return LanguageManager.shared.localizedString("ai_conversation_guidelines", language: language, fallback: """
        【Conversation Guidelines】
        • Be approachable and friendly
        • Show empathy and understanding
        • Share your thoughts honestly
        • Keep conversations natural and flowing
        """)
    }
    
    // ユーザーニックネーム指示
    func getNicknameInstruction(for language: String, nickname: String) -> String {
        let template = LanguageManager.shared.localizedString("nickname_instruction", language: language, fallback: "Please call your fan \"%@\"")
        return String(format: template, nickname)
    }
    
    // 性格指示
    func getPersonalityInstruction(for language: String, personality: String) -> String {
        let template = LanguageManager.shared.localizedString("personality_instruction", language: language, fallback: "Your personality: %@")
        return String(format: template, personality)
    }
    
    // 話し方指示
    func getSpeakingStyleInstruction(for language: String, speakingStyle: String) -> String {
        let template = LanguageManager.shared.localizedString("speaking_style_instruction", language: language, fallback: "Speaking style characteristics: %@")
        return String(format: template, speakingStyle)
    }
    
    // 性別指示
    func getGenderInstruction(for language: String, gender: String) -> String {
        let otherPrefix = LanguageManager.shared.localizedString("gender_other_prefix", language: language, fallback: "Other: ")
        
        if gender.hasPrefix(otherPrefix) {
            let detail = String(gender.dropFirst(otherPrefix.count))
            let template = LanguageManager.shared.localizedString("gender_other_instruction", language: language, fallback: "You are %@, please speak in a way that matches those characteristics")
            return String(format: template, detail)
        } else {
            let template = LanguageManager.shared.localizedString("gender_instruction", language: language, fallback: "You are %@, please speak naturally")
            return String(format: template, gender)
        }
    }
    
    // 個人情報の指示
    func getPersonalDetailsInstruction(for language: String, details: [String]) -> String {
        if details.isEmpty { return "" }
        
        let separator = LanguageManager.shared.localizedString("list_separator", language: language, fallback: ", ")
        let joinedDetails = details.joined(separator: separator)
        
        let template = LanguageManager.shared.localizedString("about_you_instruction", language: language, fallback: "About you: %@")
        let instruction = String(format: template, joinedDetails)
        
        let mentionNote = LanguageManager.shared.localizedString("mention_info_naturally", language: language, fallback: "Please naturally mention this information occasionally in conversation")
        
        return instruction + "\n• " + mentionNote
    }
    
    // 感情的フォールバック
    func getEmotionalFallback(mood: ConversationContext.Mood, userName: String, language: String) -> String {
        let nameSeparator = LanguageManager.shared.localizedString("name_separator", language: language, fallback: ", ")
        let namePrefix = userName.isEmpty ? "" : userName + nameSeparator
        
        let fallbackKey: String
        switch mood {
        case .supportive: fallbackKey = "fallback_supportive"
        case .happy: fallbackKey = "fallback_happy"
        case .consultative: fallbackKey = "fallback_consultative"
        case .neutral: fallbackKey = "fallback_neutral"
        }
        
        let fallbackText = LanguageManager.shared.localizedString(fallbackKey, language: language, fallback: "What's up?")
        return namePrefix + fallbackText
    }
    
    // 初期プロンプト
    func getInitialPrompt(for language: String, itemType: String, itemTitle: String?, eventName: String?, location: String?) -> String {
        let promptKey: String
        let value: String
        
        switch itemType.lowercased() {
        case "goods", "グッズ":
            promptKey = "initial_prompt_goods"
            value = itemTitle ?? LanguageManager.shared.localizedString("goods", language: language, fallback: "goods")
        case "live_record", "ライブ記録":
            promptKey = "initial_prompt_live"
            value = eventName ?? LanguageManager.shared.localizedString("live_record", language: language, fallback: "live event")
        case "pilgrimage", "聖地巡礼":
            promptKey = "initial_prompt_pilgrimage"
            value = location ?? LanguageManager.shared.localizedString("location", language: language, fallback: "location")
        default:
            promptKey = "initial_prompt_default"
            value = ""
        }
        
        let template = LanguageManager.shared.localizedString(promptKey, language: language, fallback: "Your fan made a new post! Please react naturally and start a conversation.")
        
        return value.isEmpty ? template : String(format: template, value)
    }
}

class AIMessageGenerator {
    static let shared = AIMessageGenerator()
    private let client = AIClient.shared
    private let languageManager = LanguageManager.shared
    
    // 言語を考慮したシステムプロンプト生成（完全ローカライズ対応版）
    private func createLanguageAwareSystemPrompt(oshi: Oshi) -> String {
        let conversationLanguage = languageManager.getConversationLanguage(for: oshi)

        // 全てローカライズファイルから取得
        var prompt = getLocalizedString("ai_system_prompt_base", language: conversationLanguage, oshiName: oshi.name)

        // 会話ルールを追加
        prompt += "\n\n" + getLocalizedString("ai_conversation_rules", language: conversationLanguage)

        // キャラクター設定を追加
        prompt += "\n\n" + createCharacterSettings(oshi: oshi, language: conversationLanguage)

        // 最終的な言語確認指示を追加
        prompt += "\n\n" + getLocalizedString("ai_final_language_reminder", language: conversationLanguage)

        // 話し方・性格を最後に再強調（最も重要な指示として最後尾に配置）
        prompt += "\n\n" + createFinalPersonalityOverride(oshi: oshi)

        return prompt
    }

    private func createFinalPersonalityOverride(oshi: Oshi) -> String {
        var sections: [String] = []

        if let personality = oshi.personality, !personality.isEmpty {
            sections.append("性格：「\(personality)」→ この性格を全ての返答で一貫して表現すること")
        }
        if let speakingStyle = oshi.speaking_style, !speakingStyle.isEmpty {
            sections.append("話し方：「\(speakingStyle)」→ この話し方を全文字・全文に適用すること。例外なし")
        }

        guard !sections.isEmpty else { return "" }

        return """
        【最重要・絶対に守ること】
        以下のキャラクター設定は、上記の全ルールより優先される最上位の指示です。
        \(sections.joined(separator: "\n        "))
        汎用的な会話ルールよりもこのキャラクター設定を優先し、どんな状況でも崩さないこと。
        """
    }
    
    // ローカライズされた文字列を取得（パラメータ置換対応）
    private func getLocalizedString(_ key: String, language: String, oshiName: String? = nil) -> String {
        let localizedString = languageManager.localizedString(key, language: language, fallback: "")
        
        // パラメータ置換
        if let name = oshiName {
            return String(format: localizedString, name)
        }
        return localizedString
    }
    
    // キャラクター設定を言語に関係なく統一的に作成
    private func createCharacterSettings(oshi: Oshi, language: String) -> String {
        var settings: [String] = []
        
        // ユーザーの呼び方設定
        if let userNickname = oshi.user_nickname, !userNickname.isEmpty {
            let instruction = getLocalizedString("ai_user_nickname_instruction", language: language)
            settings.append(String(format: instruction, userNickname))
        }
        
        // 性別設定
        if let gender = oshi.gender, !gender.isEmpty {
            let instruction = createGenderInstruction(gender: gender, language: language)
            settings.append(instruction)
        }
        
        // 性格設定
        if let personality = oshi.personality, !personality.isEmpty {
            let instruction = getLocalizedString("ai_personality_instruction", language: language)
            settings.append(String(format: instruction, personality))
        }
        
        // 話し方設定
        if let speakingStyle = oshi.speaking_style, !speakingStyle.isEmpty {
            let instruction = getLocalizedString("ai_speaking_style_instruction", language: language)
            settings.append(String(format: instruction, speakingStyle))
        }
        
        // 個人情報
        let personalDetails = createPersonalDetails(oshi: oshi, language: language)
        if !personalDetails.isEmpty {
            settings.append(personalDetails)
        }
        
        return settings.map { "• \($0)" }.joined(separator: "\n")
    }
    
    // 性別指示の作成（ローカライズ対応）
    private func createGenderInstruction(gender: String, language: String) -> String {
        // "その他："プレフィックスを多言語対応で取得
        let otherPrefix = getLocalizedString("ai_gender_other_prefix", language: language)
        
        if gender.hasPrefix(otherPrefix) {
            let detail = String(gender.dropFirst(otherPrefix.count))
            let instruction = getLocalizedString("ai_gender_other_instruction", language: language)
            return String(format: instruction, detail)
        } else {
            let instruction = getLocalizedString("ai_gender_instruction", language: language)
            return String(format: instruction, gender)
        }
    }
    
    // 個人詳細情報の作成（ローカライズ対応）
    private func createPersonalDetails(oshi: Oshi, language: String) -> String {
        var details: [String] = []
        
        // 好きな食べ物
        if let favoriteFood = oshi.favorite_food, !favoriteFood.isEmpty {
            let template = getLocalizedString("ai_favorite_food_detail", language: language)
            details.append(String(format: template, favoriteFood))
        }
        
        // 趣味
        if let interests = oshi.interests, !interests.isEmpty {
            let separator = getLocalizedString("ai_list_separator", language: language)
            let template = getLocalizedString("ai_interests_detail", language: language)
            details.append(String(format: template, interests.joined(separator: separator)))
        }
        
        // 誕生日
        if let birthday = oshi.birthday, !birthday.isEmpty {
            let template = getLocalizedString("ai_birthday_detail", language: language)
            details.append(String(format: template, birthday))
        }
        
        if details.isEmpty {
            return ""
        }
        
        let separator = getLocalizedString("ai_list_separator", language: language)
        let aboutYouTemplate = getLocalizedString("ai_about_you_instruction", language: language)
        let aboutYou = String(format: aboutYouTemplate, details.joined(separator: separator))
        
        let mentionNote = getLocalizedString("ai_mention_info_naturally", language: language)
        
        return aboutYou + "\n• " + mentionNote
    }
    
    // generateResponseメソッド（変更なし）
    func generateResponse(for userMessage: String, oshi: Oshi, chatHistory: [ChatMessage], completion: @escaping (String?, Error?) -> Void) {
        guard let client = client else {
            let conversationLanguage = languageManager.getConversationLanguage(for: oshi)
            let fallbackMessage = getLocalizedString("ai_fallback_neutral", language: conversationLanguage)
            completion(fallbackMessage, nil)
            return
        }
        
        let systemPrompt = createLanguageAwareSystemPrompt(oshi: oshi)
        
        var messages: [[String: String]] = [[
            "role": "system",
            "content": systemPrompt
        ]]
        
        for message in chatHistory.suffix(10) {
            messages.append([
                "role": message.isUser ? "user" : "assistant",
                "content": message.content
            ])
        }
        
        messages.append(["role": "user", "content": userMessage])
        
        // デバッグ用ログ
        let conversationLanguage = languageManager.getConversationLanguage(for: oshi)
        print("🌍 システムプロンプト言語設定:")
        print("preferred_language: \(oshi.preferred_language ?? "未設定")")
        print("決定された会話言語: \(conversationLanguage)")
        print("システムプロンプト最初の200文字: \(systemPrompt.prefix(200))")
        
        client.sendChat(messages: messages, completion: completion)
    }
    
    // 初期メッセージ生成（ローカライズ対応）
    func generateInitialMessage(for oshi: Oshi, item: OshiItem, completion: @escaping (String?, Error?) -> Void) {
        guard let client = client else {
            let conversationLanguage = languageManager.getConversationLanguage(for: oshi)
            let fallbackMessage = getLocalizedString("ai_fallback_happy", language: conversationLanguage)
            completion(fallbackMessage, nil)
            return
        }
        
        let conversationLanguage = languageManager.getConversationLanguage(for: oshi)
        let systemPrompt = createLanguageAwareSystemPrompt(oshi: oshi)
        let userPrompt = createInitialPrompt(for: conversationLanguage, item: item)
        
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPrompt]
        ]
        
        client.sendChat(messages: messages, completion: completion)
    }
    
    // プロアクティブメッセージ生成（自発的に話しかける）
    func generateProactiveMessage(for oshi: Oshi, chatHistory: [ChatMessage], isFirstMessage: Bool, completion: @escaping (String?, Error?) -> Void) {
        guard let client = client else {
            completion(nil, nil)
            return
        }

        let conversationLanguage = languageManager.getConversationLanguage(for: oshi)
        let systemPrompt = createLanguageAwareSystemPrompt(oshi: oshi)

        var messages: [[String: String]] = [["role": "system", "content": systemPrompt]]

        for message in chatHistory.suffix(5) {
            messages.append(["role": message.isUser ? "user" : "assistant", "content": message.content])
        }

        let proactivePrompt: String
        if isFirstMessage {
            proactivePrompt = conversationLanguage == "ja"
                ? "ファンに向けて、自然に最初の挨拶を送ってください。1〜2文で、キャラクターらしく。"
                : "Send a natural first greeting to your fan. Keep it to 1-2 sentences, staying in character."
        } else {
            proactivePrompt = conversationLanguage == "ja"
                ? "しばらくぶりです。キャラクターを保ちながら、ファンに向けて自然に話しかけてください。1〜2文で。"
                : "It's been a while. Reach out to your fan naturally, staying in character. Keep it to 1-2 sentences."
        }

        messages.append(["role": "user", "content": proactivePrompt])
        client.sendChat(messages: messages, completion: completion)
    }

    // 初期プロンプト作成（ローカライズ対応）
    private func createInitialPrompt(for language: String, item: OshiItem) -> String {
        let itemType = item.itemType ?? "other"
        
        // アイテムタイプに基づいてプロンプトキーを決定
        let promptKey: String
        let value: String
        
        switch itemType.lowercased() {
        case "goods", "グッズ":
            promptKey = "ai_initial_prompt_goods"
            value = item.title ?? getLocalizedString("goods", language: language)
        case "live_record", "ライブ記録":
            promptKey = "ai_initial_prompt_live"
            value = item.eventName ?? getLocalizedString("live_record", language: language)
        case "pilgrimage", "聖地巡礼":
            promptKey = "ai_initial_prompt_pilgrimage"
            value = item.locationAddress ?? getLocalizedString("location", language: language)
        default:
            promptKey = "ai_initial_prompt_default"
            value = ""
        }
        
        let template = getLocalizedString(promptKey, language: language)
        
        return value.isEmpty ? template : String(format: template, value)
    }
}

struct ConversationContext {
    enum Mood {
        case happy, supportive, consultative, neutral
    }
    
    enum Frequency {
        case frequent, normal
    }
    
    var mood: Mood = .neutral
    var frequency: Frequency = .normal
}

// より自然な感情表現のヘルパー（完全ローカライズ対応）
struct EmotionHelper {
    static func getEmotionalResponse(for emotion: String, oshi: Oshi) -> String {
        let conversationLanguage = LanguageManager.shared.getConversationLanguage(for: oshi)
        return LocalizedPromptManager.shared.getEmotionalFallback(
            mood: .neutral,
            userName: oshi.user_nickname ?? "",
            language: conversationLanguage  // 追加されたlanguageパラメータ
        )
    }
}

struct TopView1_Previews: PreviewProvider {
    static var previews: some View {
        TopView()
    }
}
