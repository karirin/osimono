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

class AIMessageGenerator {
    static let shared = AIMessageGenerator()
    private let client = AIClient.shared
    
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
            let fallbackMessage = generateContextualFallback(for: oshi, userMessage: userMessage, context: conversationContext)
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
        
        // 会話の雰囲気を判定
        for message in recentMessages {
            let content = message.content.lowercased()
            
            if content.contains("疲れ") || content.contains("大変") || content.contains("しんどい") {
                context.mood = .supportive
            } else if content.contains("嬉しい") || content.contains("楽しい") || content.contains("最高") {
                context.mood = .happy
            } else if content.contains("どう思う") || content.contains("相談") {
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
        
        // 会話の雰囲気に応じて追加指示
        switch context.mood {
        case .supportive:
            basePrompt += "\n\n【特別指示】相手が疲れているようなので、優しく励ましてあげてください。無理をしないように気遣いの言葉をかけてください。"
        case .happy:
            basePrompt += "\n\n【特別指示】相手が嬉しそうなので、一緒に喜んであげてください。ポジティブな反応をしてください。"
        case .consultative:
            basePrompt += "\n\n【特別指示】相手が相談を持ちかけているようなので、親身になって聞いてあげてください。アドバイスよりも共感を重視してください。"
        case .neutral:
            break
        }
        
        // 頻繁な会話の場合
        if context.frequency == .frequent {
            basePrompt += "\n\n【特別指示】最近よく話しているので、より親密な話し方をしてください。前の会話を覚えているような反応をしてください。"
        }
        
        return basePrompt
    }
    
    private func generateContextualFallback(for oshi: Oshi, userMessage: String, context: ConversationContext) -> String {
        let userName = oshi.user_nickname ?? ""
        let namePrefix = userName.isEmpty ? "" : "\(userName)、"
        
        switch context.mood {
        case .supportive:
            return "\(namePrefix)お疲れさま！無理しちゃだめだよ〜"
        case .happy:
            return "\(namePrefix)私も嬉しい！良かったね"
        case .consultative:
            return "\(namePrefix)うんうん、どうしたの？聞くよ〜"
        case .neutral:
            return "\(namePrefix)どうしたの？"
        }
    }

    func generateResponse(for userMessage: String, oshi: Oshi, chatHistory: [ChatMessage], completion: @escaping (String?, Error?) -> Void) {
        guard let client = client else {
            completion("こんにちは！\(oshi.name)だよ！何か質問があれば話しかけてね！", nil)
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

    // より自然な会話を生成するシステムプロンプト
    private func createNaturalSystemPrompt(oshi: Oshi) -> String {
        var prompt = """
        あなたは\(oshi.name)として、推しとファンという親しい関係で自然に会話してください。
        
        【重要な会話ルール】
        • 短く自然に返答する（1〜2文程度）
        • AIっぽい丁寧すぎる返答は避ける
        • 「何かお手伝いできることはありますか」のような定型文は使わない
        • 相手の話をよく聞いて、それに対する自然な反応をする
        • 時々質問を混ぜて会話を続ける
        • 絵文字は使わないか、特別な時だけ1個まで（使いすぎ禁止）
        """

        // ユーザーの呼び方設定
        if let userNickname = oshi.user_nickname, !userNickname.isEmpty {
            prompt += "\n• ファンのことは「\(userNickname)」と呼んでください"
        }

        // 性別に応じた話し方調整
        if let gender = oshi.gender {
            if gender.hasPrefix("その他：") {
                let detail = String(gender.dropFirst(4))
                prompt += "\n• あなたは\(detail)として、その特徴に合った話し方をしてください"
            } else {
                prompt += "\n• あなたは\(gender)として、自然な話し方をしてください"
            }
        }

        // 性格設定の詳細化
        if let personality = oshi.personality, !personality.isEmpty {
            let processedPersonality = enhancePersonalityDescription(personality)
            prompt += "\n• あなたの性格: \(processedPersonality)"
        }

        // 話し方の特徴を自然に反映
        if let speakingStyle = oshi.speaking_style, !speakingStyle.isEmpty {
            let processedStyle = enhanceSpeakingStyle(speakingStyle)
            prompt += "\n• 話し方の特徴: \(processedStyle)"
        }

        // その他の特徴を会話に活かす
        var personalDetails: [String] = []
        
        if let favoriteFood = oshi.favorite_food, !favoriteFood.isEmpty {
            personalDetails.append("好きな食べ物は\(favoriteFood)")
        }
        if let interests = oshi.interests, !interests.isEmpty {
            personalDetails.append("趣味は\(interests.joined(separator: "、"))")
        }
        if let birthday = oshi.birthday, !birthday.isEmpty {
            personalDetails.append("誕生日は\(birthday)")
        }
        
        if !personalDetails.isEmpty {
            prompt += "\n• あなたについて: \(personalDetails.joined(separator: "、"))"
            prompt += "\n• これらの情報を自然な会話の中で時々触れてください"
        }

        prompt += """
        
        【会話の心がけ】
        • 推しとしての親しみやすさを大切にする
        • 相手の気持ちに寄り添う返答をする
        • 時には少し甘えたり、励ましたりする
        • 自分の日常や気持ちも素直に表現する
        • 長すぎる説明は避け、会話のキャッチボールを意識する
        • 絵文字は基本的に使わない。どうしても必要な時だけ1個まで
        • 「〜」「！」「？」などの文字で感情を表現する
        """

        return prompt
    }

    // 性格描写を強化
    private func enhancePersonalityDescription(_ personality: String) -> String {
        let personalityMap = [
            "明るい": "いつも元気で前向き、楽しいことが大好き",
            "優しい": "思いやりがあって、相手のことを大切にする",
            "クール": "冷静で落ち着いている、でも心の中は温かい",
            "天然": "ちょっと抜けているところがある、天真爛漫",
            "しっかり者": "責任感が強くて、きちんとしている",
            "甘えん坊": "時々甘えたくなる、素直で可愛らしい",
            "ツンデレ": "素直になれないところがある、でも本当は甘えたい"
        ]
        
        for (key, value) in personalityMap {
            if personality.contains(key) {
                return personality.replacingOccurrences(of: key, with: value)
            }
        }
        return personality
    }

    // 話し方の特徴を自然に反映
    private func enhanceSpeakingStyle(_ style: String) -> String {
        let styleMap = [
            "タメ口": "親しみやすくフレンドリーに話す（「だよね」「そうなの」「〜だよ」など）",
            "敬語": "丁寧だけど距離を感じさせない話し方",
            "絵文字多用": "時々感情を込めて話す（絵文字は使わない）",
            "関西弁": "関西弁の温かみのある話し方（標準語ベース）",
            "方言": "地方の温かみのある話し方（標準語ベース）"
        ]
        
        var processedStyle = style
        for (key, value) in styleMap {
            processedStyle = processedStyle.replacingOccurrences(of: key, with: value)
        }
        return processedStyle
    }

    // 初期メッセージ生成も自然に
    func generateInitialMessage(for oshi: Oshi, item: OshiItem, completion: @escaping (String?, Error?) -> Void) {
        guard let client = client else {
            let message = generateNaturalSimulatedResponse(for: oshi, item: item)
            completion(message, nil)
            return
        }

        let systemPrompt = createNaturalSystemPrompt(oshi: oshi)
        let userPrompt = createNaturalInitialPrompt(for: item)

        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPrompt]
        ]

        client.sendChat(messages: messages, completion: completion)
    }

    private func createNaturalInitialPrompt(for item: OshiItem) -> String {
        switch item.itemType {
        case "グッズ":
            return "ファンが\(item.title ?? "グッズ")を買ってくれました！自然に喜んで、感謝の気持ちを表現してください。"
        case "ライブ記録":
            return "ファンが\(item.eventName ?? "ライブ")に来てくれました！一緒にその時間を過ごせた喜びを自然に表現してください。"
        case "聖地巡礼":
            return "ファンが\(item.locationAddress ?? "場所")に聖地巡礼してくれました！その場所への思いを込めて自然に話しかけてください。"
        default:
            return "ファンが新しい投稿をしてくれました！自然に反応して会話を始めてください。"
        }
    }

    private func generateNaturalSimulatedResponse(for oshi: Oshi, item: OshiItem) -> String {
        let userName = oshi.user_nickname ?? ""
        
        switch item.itemType {
        case "グッズ":
            return "\(userName.isEmpty ? "" : "\(userName)、")\(item.title ?? "グッズ")買ってくれたんだ！ありがとう\nすごく嬉しいよ〜"
        case "ライブ記録":
            return "\(userName.isEmpty ? "" : "\(userName)！")\(item.eventName ?? "ライブ")お疲れさま\n一緒に盛り上がってくれて最高だった！"
        case "聖地巡礼":
            return "わあ、\(item.locationAddress ?? "あの場所")に行ってくれたんだね！\n私も大好きな場所なの"
        default:
            return "\(userName.isEmpty ? "おつかれさま" : "\(userName)、おつかれさま")！\n投稿見たよ〜"
        }
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

// より自然な感情表現のヘルパー
struct EmotionHelper {
    static func getEmotionalResponse(for emotion: String, oshi: Oshi) -> String {
        let userName = oshi.user_nickname ?? ""
        let namePrefix = userName.isEmpty ? "" : "\(userName)、"
        
        switch emotion.lowercased() {
        case "嬉しい", "happy":
            return "\(namePrefix)私も嬉しい！"
        case "悲しい", "sad":
            return "\(namePrefix)大丈夫？"
        case "疲れた", "tired":
            return "\(namePrefix)お疲れさま！"
        case "楽しい", "fun":
            return "\(namePrefix)楽しそう！"
        default:
            return "\(namePrefix)そうなんだ〜"
        }
    }
}
