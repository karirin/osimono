//
//  AIMessageGenerator.swift
//  osimono
//

import Foundation

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
    private let promptManager = LocalizedPromptManager.shared
    private let languageManager = LanguageManager.shared
    
    // 言語を考慮したシステムプロンプト生成
    private func createLanguageAwareSystemPrompt(oshi: Oshi) -> String {
        let conversationLanguage = languageManager.getConversationLanguage(for: oshi)
        
        var prompt = promptManager.getSystemPromptTemplate(for: conversationLanguage, oshiName: oshi.name)
        prompt += "\n\n" + promptManager.getConversationRules(for: conversationLanguage)
        
        // ユーザーの呼び方設定
        if let userNickname = oshi.user_nickname, !userNickname.isEmpty {
            prompt += "\n• " + promptManager.getNicknameInstruction(for: conversationLanguage, nickname: userNickname)
        }
        
        // 性別に応じた話し方調整
        if let gender = oshi.gender, !gender.isEmpty {
            prompt += "\n• " + promptManager.getGenderInstruction(for: conversationLanguage, gender: gender)
        }
        
        // 性格設定
        if let personality = oshi.personality, !personality.isEmpty {
            prompt += "\n• " + promptManager.getPersonalityInstruction(for: conversationLanguage, personality: personality)
        }
        
        // 話し方の特徴
        if let speakingStyle = oshi.speaking_style, !speakingStyle.isEmpty {
            prompt += "\n• " + promptManager.getSpeakingStyleInstruction(for: conversationLanguage, speakingStyle: speakingStyle)
        }
        
        // 個人的な詳細情報
        var personalDetails: [String] = []
        
        if let favoriteFood = oshi.favorite_food, !favoriteFood.isEmpty {
            let template = languageManager.localizedString("favorite_food_detail", language: conversationLanguage, fallback: "favorite food is %@")
            personalDetails.append(String(format: template, favoriteFood))
        }
        
        if let interests = oshi.interests, !interests.isEmpty {
            let separator = languageManager.localizedString("list_separator", language: conversationLanguage, fallback: ", ")
            let template = languageManager.localizedString("interests_detail", language: conversationLanguage, fallback: "hobbies are %@")
            personalDetails.append(String(format: template, interests.joined(separator: separator)))
        }
        
        if let birthday = oshi.birthday, !birthday.isEmpty {
            let template = languageManager.localizedString("birthday_detail", language: conversationLanguage, fallback: "birthday is %@")
            personalDetails.append(String(format: template, birthday))
        }
        
        if !personalDetails.isEmpty {
            prompt += "\n• " + promptManager.getPersonalDetailsInstruction(for: conversationLanguage, details: personalDetails)
        }
        
        prompt += "\n\n" + promptManager.getConversationGuidelines(for: conversationLanguage)
        
        return prompt
    }
    
    func generateResponse(for userMessage: String, oshi: Oshi, chatHistory: [ChatMessage], completion: @escaping (String?, Error?) -> Void) {
        guard let client = client else {
            let conversationLanguage = languageManager.getConversationLanguage(for: oshi)
            let fallbackMessage = promptManager.getEmotionalFallback(mood: .neutral, userName: oshi.user_nickname ?? "", language: conversationLanguage)
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
        
        client.sendChat(messages: messages, completion: completion)
    }
    
    func generateInitialMessage(for oshi: Oshi, item: OshiItem, completion: @escaping (String?, Error?) -> Void) {
        guard let client = client else {
            let conversationLanguage = languageManager.getConversationLanguage(for: oshi)
            let fallbackMessage = promptManager.getEmotionalFallback(mood: .happy, userName: oshi.user_nickname ?? "", language: conversationLanguage)
            completion(fallbackMessage, nil)
            return
        }
        
        let conversationLanguage = languageManager.getConversationLanguage(for: oshi)
        let systemPrompt = createLanguageAwareSystemPrompt(oshi: oshi)
        let userPrompt = promptManager.getInitialPrompt(
            for: conversationLanguage,
            itemType: item.itemType ?? "other",
            itemTitle: item.title,
            eventName: item.eventName,
            location: item.locationAddress
        )
        
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPrompt]
        ]
        
        client.sendChat(messages: messages, completion: completion)
    }
    
    private func createNaturalSystemPrompt(oshi: Oshi) -> String {
        // 会話言語を取得
        let conversationLanguage = LanguageManager.shared.getConversationLanguage(for: oshi)
        
        // デバッグ出力
        print("🌍 推し「\(oshi.name)」の会話言語: \(conversationLanguage)")
        print("🌍 preferred_language: \(oshi.preferred_language ?? "未設定")")
        
        // 言語別の明確な指示を追加
        let languageInstruction: String
        switch conversationLanguage {
        case "en":
            languageInstruction = "IMPORTANT: You MUST respond in English only. Do not use Japanese at all."
        case "ja":
            languageInstruction = "重要：必ず日本語のみで返答してください。英語は使わないでください。"
        default:
            languageInstruction = "IMPORTANT: You MUST respond in English only. Do not use Japanese at all."
        }
        
        // 言語別のシステムプロンプトテンプレートを取得
        let systemPromptTemplate: String
        if conversationLanguage == "ja" {
            systemPromptTemplate = "あなたは%@として、推しとファンという親しい関係で自然に日本語で会話してください。"
        } else {
            systemPromptTemplate = "You are %@, and please have natural conversations with your fan in a close relationship using English only."
        }
        
        var prompt = languageInstruction + "\n\n" + String(format: systemPromptTemplate, oshi.name)
        
        // 言語別の会話ルールを追加
        let conversationRules: String
        if conversationLanguage == "ja" {
            conversationRules = """
            【重要な会話ルール】
            • 短く自然に返答する（1〜2文程度）
            • AIっぽい丁寧すぎる返答は避ける
            • 相手の話をよく聞いて、それに対する自然な反応をする
            • 時々質問を混ぜて会話を続ける
            • 絵文字は使わないか、特別な時だけ1個まで
            • 「〜」「！」「？」などの文字で感情を表現する
            """
        } else {
            conversationRules = """
            【Important Conversation Rules】
            • Reply briefly and naturally in English (1-2 sentences)
            • Avoid overly polite AI-like responses
            • Listen carefully and give natural reactions
            • Mix in questions occasionally
            • Use minimal or no emojis
            • Express emotions with characters like "~", "!", "?" etc.
            """
        }
        
        prompt += "\n\n" + conversationRules

        // ユーザーの呼び方設定（言語対応）
        if let userNickname = oshi.user_nickname, !userNickname.isEmpty {
            let nicknameInstruction: String
            if conversationLanguage == "ja" {
                nicknameInstruction = "ファンのことは「\(userNickname)」と呼んでください"
            } else {
                nicknameInstruction = "Please call your fan \"\(userNickname)\""
            }
            prompt += "\n• " + nicknameInstruction
        }

        // 性別に応じた話し方調整
        if let gender = oshi.gender, !gender.isEmpty {
            let genderInstruction: String
            if conversationLanguage == "ja" {
                if gender.hasPrefix("その他：") {
                    let detail = String(gender.dropFirst(4))
                    genderInstruction = "あなたは\(detail)として、その特徴に合った話し方をしてください"
                } else {
                    genderInstruction = "あなたは\(gender)として、自然な話し方をしてください"
                }
            } else {
                if gender.hasPrefix("Other: ") {
                    let detail = String(gender.dropFirst(7))
                    genderInstruction = "You are \(detail), please speak in a way that matches those characteristics"
                } else {
                    genderInstruction = "You are \(gender), please speak naturally in English"
                }
            }
            prompt += "\n• " + genderInstruction
        }

        // 性格設定
        if let personality = oshi.personality, !personality.isEmpty {
            let personalityInstruction: String
            if conversationLanguage == "ja" {
                personalityInstruction = "あなたの性格: \(personality)"
            } else {
                personalityInstruction = "Your personality: \(personality)"
            }
            prompt += "\n• " + personalityInstruction
        }

        // 話し方の特徴
        if let speakingStyle = oshi.speaking_style, !speakingStyle.isEmpty {
            let styleInstruction: String
            if conversationLanguage == "ja" {
                styleInstruction = "話し方の特徴: \(speakingStyle)"
            } else {
                styleInstruction = "Speaking style characteristics: \(speakingStyle)"
            }
            prompt += "\n• " + styleInstruction
        }

        // その他の特徴を会話に活かす
        var personalDetails: [String] = []
        
        if let favoriteFood = oshi.favorite_food, !favoriteFood.isEmpty {
            let foodDetail: String
            if conversationLanguage == "ja" {
                foodDetail = "好きな食べ物は\(favoriteFood)"
            } else {
                foodDetail = "favorite food is \(favoriteFood)"
            }
            personalDetails.append(foodDetail)
        }
        
        if let interests = oshi.interests, !interests.isEmpty {
            let separator = conversationLanguage == "ja" ? "、" : ", "
            let interestsDetail: String
            if conversationLanguage == "ja" {
                interestsDetail = "趣味は\(interests.joined(separator: separator))"
            } else {
                interestsDetail = "hobbies are \(interests.joined(separator: separator))"
            }
            personalDetails.append(interestsDetail)
        }
        
        if let birthday = oshi.birthday, !birthday.isEmpty {
            let birthdayDetail: String
            if conversationLanguage == "ja" {
                birthdayDetail = "誕生日は\(birthday)"
            } else {
                birthdayDetail = "birthday is \(birthday)"
            }
            personalDetails.append(birthdayDetail)
        }
        
        if !personalDetails.isEmpty {
            let separator = conversationLanguage == "ja" ? "、" : ", "
            let aboutYou: String
            let mentionNote: String
            
            if conversationLanguage == "ja" {
                aboutYou = "あなたについて: \(personalDetails.joined(separator: separator))"
                mentionNote = "これらの情報を自然な会話の中で時々触れてください"
            } else {
                aboutYou = "About you: \(personalDetails.joined(separator: separator))"
                mentionNote = "Please naturally mention this information occasionally in conversation"
            }
            
            prompt += "\n• " + aboutYou
            prompt += "\n• " + mentionNote
        }

        // 会話ガイドライン
        let conversationGuidelines: String
        if conversationLanguage == "ja" {
            conversationGuidelines = """
            【会話の心がけ】
            • 推しとしての親しみやすさを大切にする
            • 相手の気持ちに寄り添う返答をする
            • 時には少し甘えたり、励ましたりする
            • 自分の日常や気持ちも素直に表現する
            • 長すぎる説明は避け、会話のキャッチボールを意識する
            """
        } else {
            conversationGuidelines = """
            【Conversation Guidelines】
            • Be approachable and friendly as an oshi
            • Show empathy and understanding
            • Sometimes be sweet or encouraging
            • Share your thoughts and daily life honestly
            • Keep conversations natural and flowing in English
            """
        }
        
        prompt += "\n\n" + conversationGuidelines
        
        // 最終的な言語確認指示を追加
        if conversationLanguage == "en" {
            prompt += "\n\nREMEMBER: Your response must be in English only. Do not mix languages."
        } else if conversationLanguage == "ja" {
            prompt += "\n\n忘れずに：返答は日本語のみで行ってください。言語を混在させないでください。"
        }

        // デバッグ用：生成されたプロンプトの一部を出力
        print("🤖 生成されたプロンプト（最初の200文字）:")
        print(String(prompt.prefix(200)) + "...")
        
        return prompt
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
