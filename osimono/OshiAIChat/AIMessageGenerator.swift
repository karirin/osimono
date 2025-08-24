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

// MARK: - Localization Helper
class LocalizedPromptManager {
    static let shared = LocalizedPromptManager()
    
    private init() {}
    
    // 感情分析キーワードを取得（完全にローカライズファイルから）
    func getEmotionKeywords() -> [String: [String]] {
        let tiredKeywords = NSLocalizedString("emotion_keywords_tired", comment: "tired,exhausted,difficult,hard").components(separatedBy: ",")
        let happyKeywords = NSLocalizedString("emotion_keywords_happy", comment: "happy,fun,great,amazing").components(separatedBy: ",")
        let consultativeKeywords = NSLocalizedString("emotion_keywords_consultative", comment: "what do you think,advice,help,opinion").components(separatedBy: ",")
        
        return [
            "tired": tiredKeywords,
            "happy": happyKeywords,
            "consultative": consultativeKeywords
        ]
    }
    
    // 感情に応じたフォールバック応答を取得
    func getEmotionalFallback(mood: ConversationContext.Mood, userName: String) -> String {
        let namePrefix = userName.isEmpty ? "" : userName + NSLocalizedString("name_separator", comment: "、")
        
        switch mood {
        case .supportive:
            return namePrefix + NSLocalizedString("fallback_supportive", comment: "Good job today! Don't push yourself too hard~")
        case .happy:
            return namePrefix + NSLocalizedString("fallback_happy", comment: "I'm happy too! That's great!")
        case .consultative:
            return namePrefix + NSLocalizedString("fallback_consultative", comment: "Yeah, what's going on? I'm listening~")
        case .neutral:
            return namePrefix + NSLocalizedString("fallback_neutral", comment: "What's up?")
        }
    }
    
    // プロンプトテンプレートを取得
    func getSystemPromptTemplate() -> String {
        return NSLocalizedString("ai_system_prompt_template", comment: "System prompt template for AI")
    }
    
    func getConversationRules() -> String {
        return NSLocalizedString("ai_conversation_rules", comment: "Conversation rules for AI")
    }
    
    func getConversationGuidelines() -> String {
        return NSLocalizedString("ai_conversation_guidelines", comment: "Conversation guidelines for AI")
    }
    
    // 特別指示のテンプレート
    func getSpecialInstruction(for mood: ConversationContext.Mood) -> String {
        switch mood {
        case .supportive:
            return NSLocalizedString("special_instruction_supportive", comment: "The user seems tired, so please encourage them gently.")
        case .happy:
            return NSLocalizedString("special_instruction_happy", comment: "The user seems happy, so please share in their joy.")
        case .consultative:
            return NSLocalizedString("special_instruction_consultative", comment: "The user seems to be seeking consultation.")
        case .neutral:
            return ""
        }
    }
    
    func getFrequentChatInstruction() -> String {
        return NSLocalizedString("special_instruction_frequent", comment: "Since you've been talking frequently recently, please speak more intimately.")
    }
    
    // 性格・話し方の説明マッピング
    func getPersonalityEnhancement(for personality: String) -> String {
        // ローカライズキーを動的に作成
        let personalityKey = "personality_\(personality.lowercased().replacingOccurrences(of: " ", with: "_"))"
        let enhanced = NSLocalizedString(personalityKey, value: personality, comment: "Enhanced personality description")
        return enhanced != personality ? enhanced : personality
    }
    
    func getSpeakingStyleEnhancement(for style: String) -> String {
        // ローカライズキーを動的に作成
        let styleKey = "speaking_style_\(style.lowercased().replacingOccurrences(of: " ", with: "_"))"
        let enhanced = NSLocalizedString(styleKey, value: style, comment: "Enhanced speaking style description")
        return enhanced != style ? enhanced : style
    }
    
    // 初期メッセージのプロンプト
    func getInitialPrompt(for itemType: String, itemTitle: String?, eventName: String?, location: String?) -> String {
        switch itemType {
        case NSLocalizedString("goods", comment: ""):
            return String(format: NSLocalizedString("initial_prompt_goods", comment: "Fan bought goods prompt"), itemTitle ?? NSLocalizedString("goods", comment: ""))
        case NSLocalizedString("live_record", comment: ""):
            return String(format: NSLocalizedString("initial_prompt_live", comment: "Fan attended live prompt"), eventName ?? NSLocalizedString("live_record", comment: ""))
        case NSLocalizedString("pilgrimage", comment: ""):
            return String(format: NSLocalizedString("initial_prompt_pilgrimage", comment: "Fan went to pilgrimage prompt"), location ?? NSLocalizedString("location", comment: ""))
        default:
            return NSLocalizedString("initial_prompt_default", comment: "Fan made a new post prompt")
        }
    }
    
    // シミュレートされた応答
    func getSimulatedResponse(for itemType: String, userName: String, itemTitle: String?, eventName: String?, location: String?) -> String {
        let namePrefix = userName.isEmpty ? "" : userName + NSLocalizedString("name_separator", comment: "、")
        
        switch itemType {
        case NSLocalizedString("goods", comment: ""):
            return String(format: NSLocalizedString("simulated_response_goods", comment: "Simulated response for goods"),
                         namePrefix, itemTitle ?? NSLocalizedString("goods", comment: ""))
        case NSLocalizedString("live_record", comment: ""):
            return String(format: NSLocalizedString("simulated_response_live", comment: "Simulated response for live"),
                         namePrefix, eventName ?? NSLocalizedString("live_record", comment: ""))
        case NSLocalizedString("pilgrimage", comment: ""):
            return String(format: NSLocalizedString("simulated_response_pilgrimage", comment: "Simulated response for pilgrimage"),
                         location ?? NSLocalizedString("location", comment: ""))
        default:
            let defaultGreeting = userName.isEmpty ? NSLocalizedString("default_greeting", comment: "Good job") :
                                  String(format: NSLocalizedString("default_greeting_with_name", comment: "Good job with name"), userName)
            return defaultGreeting + NSLocalizedString("post_seen_suffix", comment: "! I saw your post~")
        }
    }
    
    func getFallbackWelcome(for oshiName: String) -> String {
        return String(format: NSLocalizedString("fallback_welcome_message", comment: "Hello! I'm %@! Feel free to talk to me!"), oshiName)
    }
}

class AIMessageGenerator {
    static let shared = AIMessageGenerator()
    private let client = AIClient.shared
    private let promptManager = LocalizedPromptManager.shared
    
    func generateContextAwareResponse(for userMessage: String, oshi: Oshi, chatHistory: [ChatMessage], completion: @escaping (String?, Error?) -> Void) {
        
        // 最近の会話パターンを分析
        let conversationContext = analyzeConversationContext(chatHistory: chatHistory)
        
        // 文脈に応じてプロンプトを調整
        let enhancedPrompt = createContextAwarePrompt(
            oshi: oshi,
            userMessage: userMessage,
            context: conversationContext
        )
        
        guard let client = client else {
            let fallbackMessage = promptManager.getEmotionalFallback(
                mood: conversationContext.mood,
                userName: oshi.user_nickname ?? ""
            )
            completion(fallbackMessage, nil)
            return
        }
        
        var messages: [[String: String]] = [[
            "role": "system",
            "content": enhancedPrompt
        ]]
        
        // 会話履歴を追加（最新10件）
        for message in chatHistory.suffix(10) {
            messages.append([
                "role": message.isUser ? "user" : "assistant",
                "content": message.content
            ])
        }
        
        messages.append(["role": "user", "content": userMessage])
        
        client.sendChat(messages: messages, completion: completion)
    }
    
    private func analyzeConversationContext(chatHistory: [ChatMessage]) -> ConversationContext {
        let recentMessages = Array(chatHistory.suffix(5))
        var context = ConversationContext()
        
        // ローカライズされたキーワードを取得
        let emotionKeywords = promptManager.getEmotionKeywords()
        
        for message in recentMessages {
            let content = message.content.lowercased()
            
            // 各感情カテゴリーをチェック
            if let tiredKeywords = emotionKeywords["tired"],
               tiredKeywords.contains(where: { content.contains($0.lowercased().trimmingCharacters(in: .whitespaces)) }) {
                context.mood = .supportive
            } else if let happyKeywords = emotionKeywords["happy"],
                      happyKeywords.contains(where: { content.contains($0.lowercased().trimmingCharacters(in: .whitespaces)) }) {
                context.mood = .happy
            } else if let consultativeKeywords = emotionKeywords["consultative"],
                      consultativeKeywords.contains(where: { content.contains($0.lowercased().trimmingCharacters(in: .whitespaces)) }) {
                context.mood = .consultative
            }
        }
        
        // 会話の頻度をチェック
        let timeInterval = Date().timeIntervalSince1970 - (recentMessages.first?.timestamp ?? 0)
        if timeInterval < 3600 { // 1時間以内
            context.frequency = .frequent
        }
        
        return context
    }
    
    private func createContextAwarePrompt(oshi: Oshi, userMessage: String, context: ConversationContext) -> String {
        var basePrompt = createNaturalSystemPrompt(oshi: oshi)
        
        // 会話の雰囲気に応じて特別指示を追加
        let specialInstruction = promptManager.getSpecialInstruction(for: context.mood)
        if !specialInstruction.isEmpty {
            basePrompt += "\n\n【" + NSLocalizedString("special_instructions_header", comment: "Special Instructions") + "】" + specialInstruction
        }
        
        // 頻繁な会話の場合
        if context.frequency == .frequent {
            let frequentInstruction = promptManager.getFrequentChatInstruction()
            basePrompt += "\n\n【" + NSLocalizedString("special_instructions_header", comment: "Special Instructions") + "】" + frequentInstruction
        }
        
        return basePrompt
    }

    func generateResponse(for userMessage: String, oshi: Oshi, chatHistory: [ChatMessage], completion: @escaping (String?, Error?) -> Void) {
        guard let client = client else {
            let fallbackMessage = promptManager.getFallbackWelcome(for: oshi.name)
            completion(fallbackMessage, nil)
            return
        }

        let systemPrompt = createNaturalSystemPrompt(oshi: oshi)

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

    // より自然な会話を生成するシステムプロンプト（完全ローカライズ対応）
    private func createNaturalSystemPrompt(oshi: Oshi) -> String {
        var prompt = String(format: promptManager.getSystemPromptTemplate(), oshi.name)
        
        prompt += "\n\n" + promptManager.getConversationRules()

        // ユーザーの呼び方設定
        if let userNickname = oshi.user_nickname, !userNickname.isEmpty {
            let nicknameInstruction = String(format: NSLocalizedString("nickname_instruction", comment: "Please call your fan \"%@\""), userNickname)
            prompt += "\n• " + nicknameInstruction
        }

        // 性別に応じた話し方調整
        if let gender = oshi.gender {
            let otherPrefix = NSLocalizedString("gender_other_prefix", comment: "その他：")
            if gender.hasPrefix(otherPrefix) {
                let detail = String(gender.dropFirst(otherPrefix.count))
                let genderInstruction = String(format: NSLocalizedString("gender_other_instruction", comment: "You are %@, please speak in a way that matches those characteristics"), detail)
                prompt += "\n• " + genderInstruction
            } else {
                let genderInstruction = String(format: NSLocalizedString("gender_instruction", comment: "You are %@, please speak naturally"), gender)
                prompt += "\n• " + genderInstruction
            }
        }

        // 性格設定の詳細化
        if let personality = oshi.personality, !personality.isEmpty {
            let processedPersonality = promptManager.getPersonalityEnhancement(for: personality)
            let personalityInstruction = String(format: NSLocalizedString("personality_instruction", comment: "Your personality: %@"), processedPersonality)
            prompt += "\n• " + personalityInstruction
        }

        // 話し方の特徴を自然に反映
        if let speakingStyle = oshi.speaking_style, !speakingStyle.isEmpty {
            let processedStyle = promptManager.getSpeakingStyleEnhancement(for: speakingStyle)
            let styleInstruction = String(format: NSLocalizedString("speaking_style_instruction", comment: "Speaking style characteristics: %@"), processedStyle)
            prompt += "\n• " + styleInstruction
        }

        // その他の特徴を会話に活かす
        var personalDetails: [String] = []
        
        if let favoriteFood = oshi.favorite_food, !favoriteFood.isEmpty {
            let foodDetail = String(format: NSLocalizedString("favorite_food_detail", comment: "favorite food is %@"), favoriteFood)
            personalDetails.append(foodDetail)
        }
        if let interests = oshi.interests, !interests.isEmpty {
            let interestsDetail = String(format: NSLocalizedString("interests_detail", comment: "hobbies are %@"), interests.joined(separator: NSLocalizedString("list_separator", comment: "、")))
            personalDetails.append(interestsDetail)
        }
        if let birthday = oshi.birthday, !birthday.isEmpty {
            let birthdayDetail = String(format: NSLocalizedString("birthday_detail", comment: "birthday is %@"), birthday)
            personalDetails.append(birthdayDetail)
        }
        
        if !personalDetails.isEmpty {
            let aboutYou = String(format: NSLocalizedString("about_you_instruction", comment: "About you: %@"), personalDetails.joined(separator: NSLocalizedString("list_separator", comment: "、")))
            prompt += "\n• " + aboutYou
            prompt += "\n• " + NSLocalizedString("mention_info_naturally", comment: "Please naturally mention this information occasionally in conversation")
        }

        prompt += "\n\n" + promptManager.getConversationGuidelines()

        return prompt
    }

    // 初期メッセージ生成も自然に（完全ローカライズ対応）
    func generateInitialMessage(for oshi: Oshi, item: OshiItem, completion: @escaping (String?, Error?) -> Void) {
        guard let client = client else {
            let message = promptManager.getSimulatedResponse(
                for: item.itemType!,
                userName: oshi.user_nickname ?? "",
                itemTitle: item.title,
                eventName: item.eventName,
                location: item.locationAddress
            )
            completion(message, nil)
            return
        }

        let systemPrompt = createNaturalSystemPrompt(oshi: oshi)
        let userPrompt = promptManager.getInitialPrompt(
            for: item.itemType!,
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
        return LocalizedPromptManager.shared.getEmotionalFallback(
            mood: .neutral, // emotionから適切なmoodを推定する場合は別途ロジックを追加
            userName: oshi.user_nickname ?? ""
        )
    }
}
