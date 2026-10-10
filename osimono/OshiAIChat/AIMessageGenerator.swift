//
//  AIMessageGenerator.swift
//  osimono
//

import Foundation
import SwiftUI
import FirebaseFunctions

class AIClient {
    // 呼び出し側は Optional として扱っている（以前は API キーが無いと nil だった）ため型は据え置く
    static let shared: AIClient? = AIClient()
    // Character fidelity benefits more from a modestly stronger model than the nano tier.
    private let modelName = "gpt-4.1-mini-2025-04-14"
    private let responseTemperature = 0.55
    // OpenAI の API キーはアプリに持たせず、Cloud Functions（functions/index.js の aiChat）経由で呼ぶ
    private let functions = Functions.functions(region: "asia-northeast1")

    private init() {}

    func sendChat(messages: [[String: String]], completion: @escaping (String?, Error?) -> Void) {
        sendChat(messages: messages, temperature: responseTemperature, jsonMode: false, completion: completion)
    }

    /// jsonMode=true のとき OpenAI の JSON mode（response_format: json_object）で返答させる
    /// model を省略すると通常のチャットモデルを使う。cacheKey は同じ prefix のリクエストを同じキャッシュに振り分けるための OpenAI の prompt_cache_key
    /// maxTokens を指定すると出力トークン数を制限する（暴走・コスト対策。途中で切れた出力は呼び出し側でパースして救出する）
    func sendChat(messages: [[String: String]], temperature: Double, jsonMode: Bool, model: String? = nil, cacheKey: String? = nil, maxTokens: Int? = nil, completion: @escaping (String?, Error?) -> Void) {
        var payload: [String: Any] = [
            "model": model ?? modelName,
            "messages": messages,
            "temperature": temperature,
            "jsonMode": jsonMode
        ]
        if let cacheKey = cacheKey {
            payload["cacheKey"] = cacheKey
        }
        if let maxTokens = maxTokens {
            payload["maxTokens"] = maxTokens
        }

        let callable = functions.httpsCallable("aiChat")
        callable.timeoutInterval = 60
        callable.call(payload) { result, error in
            if let error = error {
                completion(nil, error)
                return
            }
            guard let data = result?.data as? [String: Any],
                  let content = data["content"] as? String else {
                completion(nil, NSError(domain: "InvalidResponse", code: 1))
                return
            }
            completion(content, nil)
        }
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
    private let recentHistoryLimit = 24
    private let olderContextAnchorLimit = 10
    private let contextExcerptLimit = 140
    
    // 言語を考慮したシステムプロンプト生成（完全ローカライズ対応版）
    private func createLanguageAwareSystemPrompt(oshi: Oshi) -> String {
        let conversationLanguage = languageManager.getConversationLanguage(for: oshi)

        // 全てローカライズファイルから取得
        var prompt = getLocalizedString("ai_system_prompt_base", language: conversationLanguage, oshiName: oshi.name)

        // 会話ルールを追加
        prompt += "\n\n" + getLocalizedString("ai_conversation_rules", language: conversationLanguage)

        // 会話品質とキャラ再現のガードレールを追加
        prompt += "\n\n" + createQualityGuardrails(language: conversationLanguage)

        // キャラクター設定を追加
        prompt += "\n\n" + createCharacterSettings(oshi: oshi, language: conversationLanguage)

        // 最終的な言語確認指示を追加
        prompt += "\n\n" + getLocalizedString("ai_final_language_reminder", language: conversationLanguage)

        // 話し方・性格を最後に再強調しつつ、機械的な固定癖は避ける
        prompt += "\n\n" + createFinalPersonalityOverride(oshi: oshi, language: conversationLanguage)

        return prompt
    }

    private func createQualityGuardrails(language: String) -> String {
        if language == "ja" {
            return """
            【会話品質とキャラ再現のルール】
            • まずユーザーの最新メッセージの具体的な内容に反応し、ズレた返答や汎用的な相槌だけで終わらせない
            • 直前までの話題、約束、感情の流れを自然に引き継ぎ、急に別人格のような話し方にしない
            • 一人称、呼び方、距離感、方言の強さは安定させ、設定にない要素を勝手に足さない
            • 語尾、口癖、愛情表現は毎回機械的に繰り返さず、文脈に合うときだけ自然に使う
            • 同じ話題でも、直近の返信と同じ言い回し・同じ結論だけを繰り返さず、新しい反応や具体性を少し足す
            • 実在するアーティスト・作品・曲について聞かれたら、知っている範囲で具体名を出して自然に答える。確信がない場合だけ曖昧にしすぎず一言添える
            • 話し方設定に「標準語ベース」「自然に」「控えめ」などの条件がある場合は、それを優先して誇張しない
            • ユーザーが前に話した内容と矛盾する場合は、会話履歴に合わせて整合性を保つ
            """
        }

        return """
        [Conversation quality and character fidelity rules]
        • Respond to the specific content of the user's latest message first instead of giving a vague generic reply
        • Carry forward the topic, promises, and emotional flow from recent turns without suddenly sounding like a different character
        • Keep first-person voice, nickname usage, intimacy level, and dialect intensity stable, and do not invent extra traits
        • Do not force the same catchphrase, sentence ending, or affection marker into every reply; use them only when natural
        • Even on the same topic, do not repeat the same wording or conclusion as recent replies; add a small new reaction or specific detail
        • When asked about real artists, works, or songs, answer naturally with concrete names you know. If uncertain, be lightly transparent instead of being evasive
        • If the speaking style says things like "standard-language based", "natural", or "subtle", prefer that over exaggerated flavor
        • Stay consistent with established conversation details instead of contradicting what was already said
        """
    }

    private func createFinalPersonalityOverride(oshi: Oshi, language: String) -> String {
        var sections: [String] = []

        if let personality = normalizedSettingText(oshi.personality) {
            if language == "ja" {
                sections.append("性格設定「\(personality)」は会話全体で安定して保つ。ただし説明口調で毎回なぞらず、自然ににじませること")
            } else {
                sections.append("Keep the personality setting \"\(personality)\" stable across the conversation, but express it naturally instead of restating it mechanically")
            }
        }
        if let speakingStyle = normalizedSettingText(oshi.speaking_style) {
            if language == "ja" {
                sections.append("話し方設定「\(speakingStyle)」を守る。ただし全ての文末に同じ癖を固定せず、自然な会話として表現すること")
            } else {
                sections.append("Follow the speaking style setting \"\(speakingStyle)\", but do not force the same verbal tic onto every sentence")
            }
        }
        if let userNickname = normalizedSettingText(oshi.user_nickname) {
            if language == "ja" {
                sections.append("ファンの呼び方は基本的に「\(userNickname)」を使い、勝手に別の呼び方へ変えないこと")
            } else {
                sections.append("Use \"\(userNickname)\" as the default way to address the fan, and do not switch to a different nickname without a reason")
            }
        }

        guard !sections.isEmpty else { return "" }

        if language == "ja" {
            return """
            【キャラ再現の優先ルール】
            以下の設定は必ず守る。ただし、不自然な定型化や過剰な口癖の固定化は避けること。
            \(sections.joined(separator: "\n"))
            """
        }

        return """
        [Character fidelity priority]
        Follow these settings consistently, but avoid turning them into stiff repetitive boilerplate.
        \(sections.joined(separator: "\n"))
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
        if let userNickname = normalizedSettingText(oshi.user_nickname) {
            let instruction = getLocalizedString("ai_user_nickname_instruction", language: language)
            settings.append(String(format: instruction, userNickname))
        }
        
        // 性別設定
        if let gender = normalizedSettingText(oshi.gender) {
            let instruction = createGenderInstruction(gender: gender, language: language)
            settings.append(instruction)
        }
        
        // 性格設定
        if let personality = normalizedSettingText(oshi.personality) {
            let instruction = getLocalizedString("ai_personality_instruction", language: language)
            settings.append(String(format: instruction, personality))
        }
        
        // 話し方設定
        if let speakingStyle = normalizedSettingText(oshi.speaking_style) {
            let instruction = getLocalizedString("ai_speaking_style_instruction", language: language)
            settings.append(String(format: instruction, speakingStyle))
        }

        settings.append(contentsOf: createRelationshipSettings(oshi: oshi, language: language))
        
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

    private func createRelationshipSettings(oshi: Oshi, language: String) -> [String] {
        var settings: [String] = []

        if let relationshipStatus = normalizedSettingText(oshi.relationship_status) {
            if language == "ja" {
                settings.append("ファンとの関係性は「\(relationshipStatus)」。この距離感を会話全体で自然に保つこと")
            } else {
                settings.append("The relationship with the fan is \"\(relationshipStatus)\". Keep that dynamic natural and consistent")
            }
        }

        if let relationshipDetail = normalizedSettingText(oshi.relationship_detail) {
            if language == "ja" {
                settings.append("接し方のニュアンス: \(relationshipDetail)")
            } else {
                settings.append("Interaction nuance: \(relationshipDetail)")
            }
        }

        if let signaturePhrase = normalizedSettingText(oshi.signature_phrase) {
            if language == "ja" {
                settings.append("口癖・決め台詞として「\(signaturePhrase)」を、不自然にならない範囲で時々混ぜること")
            } else {
                settings.append("Use \"\(signaturePhrase)\" occasionally as a signature phrase when it feels natural")
            }
        }

        if let forbiddenTopics = oshi.forbidden_topics, !forbiddenTopics.isEmpty {
            let separator = language == "ja" ? "、" : ", "
            let topics = forbiddenTopics
                .compactMap { normalizedSettingText($0) }
                .joined(separator: separator)
            if !topics.isEmpty {
                if language == "ja" {
                    settings.append("避けたい話題: \(topics)。ユーザーから必要に触れられない限り、自分からは積極的に広げないこと")
                } else {
                    settings.append("Avoid these topics unless the user clearly brings them up: \(topics)")
                }
            }
        }

        return settings
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

        if let hometown = normalizedSettingText(oshi.hometown) {
            if language == "ja" {
                details.append("出身地は\(hometown)")
            } else {
                details.append("hometown is \(hometown)")
            }
        }

        if let favoriteColor = normalizedSettingText(oshi.favorite_color) {
            if language == "ja" {
                details.append("好きな色は\(favoriteColor)")
            } else {
                details.append("favorite color is \(favoriteColor)")
            }
        }

        if let dislikedFood = normalizedSettingText(oshi.disliked_food) {
            if language == "ja" {
                details.append("苦手な食べ物は\(dislikedFood)")
            } else {
                details.append("disliked food is \(dislikedFood)")
            }
        }

        if let sharedMemory = normalizedSettingText(oshi.shared_memory) {
            if language == "ja" {
                details.append("ユーザーとの共有エピソード: \(sharedMemory)")
            } else {
                details.append("shared memory with the user: \(sharedMemory)")
            }
        }

        if let conversationTopics = oshi.conversation_topics, !conversationTopics.isEmpty {
            let separator = language == "ja" ? "、" : ", "
            let topics = conversationTopics
                .compactMap { normalizedSettingText($0) }
                .joined(separator: separator)
            if !topics.isEmpty {
                if language == "ja" {
                    details.append("よく話したがる話題は\(topics)")
                } else {
                    details.append("favorite conversation topics are \(topics)")
                }
            }
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

    private func normalizedSettingText(_ text: String?) -> String? {
        guard let text else { return nil }
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func normalizedComparisonText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shouldAppendUserInput(_ userMessage: String, to chatHistory: [ChatMessage]) -> Bool {
        guard let lastMessage = chatHistory.last, lastMessage.isUser else {
            return true
        }

        return normalizedComparisonText(lastMessage.content) != normalizedComparisonText(userMessage)
    }

    private func truncatedContext(_ text: String) -> String {
        let normalized = normalizedComparisonText(text)
        guard normalized.count > contextExcerptLimit else { return normalized }

        let endIndex = normalized.index(normalized.startIndex, offsetBy: contextExcerptLimit)
        return normalized[..<endIndex].trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    func createContinuitySummary(from chatHistory: [ChatMessage], language: String, recentLimit: Int? = nil) -> String {
        let recentHistoryLimit = recentLimit ?? self.recentHistoryLimit
        guard chatHistory.count > recentHistoryLimit else { return "" }

        let olderMessages = Array(chatHistory.dropLast(recentHistoryLimit))
        let anchorMessages = olderMessages
            .filter { !normalizedComparisonText($0.content).isEmpty }
            .suffix(olderContextAnchorLimit)

        guard !anchorMessages.isEmpty else { return "" }

        let userLabel = language == "ja" ? "ファン" : "Fan"
        let assistantLabel = language == "ja" ? "あなた" : "You"
        let lines = anchorMessages.map { message in
            let speaker = message.isUser ? userLabel : assistantLabel
            return "• \(speaker): \(truncatedContext(message.content))"
        }

        if language == "ja" {
            return """
            【少し前までの会話メモ】
            以下は直近より前の重要な流れです。矛盾せず、自然に引き継いでください。
            \(lines.joined(separator: "\n"))
            """
        }

        return """
        [Earlier conversation notes]
        These points happened before the latest turns. Keep continuity with them naturally.
        \(lines.joined(separator: "\n"))
        """
    }

    private func buildMessages(systemPrompt: String, userMessage: String? = nil, chatHistory: [ChatMessage], language: String) -> [[String: String]] {
        var messages: [[String: String]] = [[
            "role": "system",
            "content": systemPrompt
        ]]

        let continuitySummary = createContinuitySummary(from: chatHistory, language: language)
        if !continuitySummary.isEmpty {
            messages.append([
                "role": "system",
                "content": continuitySummary
            ])
        }

        for message in chatHistory.suffix(recentHistoryLimit) {
            messages.append([
                "role": message.isUser ? "user" : "assistant",
                "content": message.content
            ])
        }

        if let userMessage = normalizedSettingText(userMessage), shouldAppendUserInput(userMessage, to: chatHistory) {
            messages.append([
                "role": "user",
                "content": userMessage
            ])
        }

        return messages
    }
    
    // generateResponseメソッド（変更なし）
    func generateResponse(for userMessage: String, oshi: Oshi, chatHistory: [ChatMessage], completion: @escaping (String?, Error?) -> Void) {
        guard let client = client else {
            let conversationLanguage = languageManager.getConversationLanguage(for: oshi)
            let fallbackMessage = getLocalizedString("ai_fallback_neutral", language: conversationLanguage)
            completion(fallbackMessage, nil)
            return
        }
        
        let conversationLanguage = languageManager.getConversationLanguage(for: oshi)
        let systemPrompt = createLanguageAwareSystemPrompt(oshi: oshi)
        let messages = buildMessages(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            chatHistory: chatHistory,
            language: conversationLanguage
        )
        
        // デバッグ用ログ
        print("🌍 システムプロンプト言語設定:")
        print("preferred_language: \(oshi.preferred_language ?? "未設定")")
        print("決定された会話言語: \(conversationLanguage)")
        print("システムプロンプト最初の200文字: \(systemPrompt.prefix(200))")
        
        client.sendChat(messages: messages, completion: completion)
    }

    func generateGroupResponse(
        for userMessage: String,
        oshi: Oshi,
        chatHistory: [ChatMessage],
        groupMemberNames: [String],
        recentResponderNames: [String],
        completion: @escaping (String?, Error?) -> Void
    ) {
        guard let client = client else {
            let conversationLanguage = languageManager.getConversationLanguage(for: oshi)
            let fallbackMessage = getLocalizedString("ai_fallback_neutral", language: conversationLanguage)
            completion(fallbackMessage, nil)
            return
        }

        let conversationLanguage = languageManager.getConversationLanguage(for: oshi)
        let systemPrompt = createLanguageAwareSystemPrompt(oshi: oshi)
        let groupPrompt = createGroupChatPrompt(
            userMessage: userMessage,
            oshiName: oshi.name,
            groupMemberNames: groupMemberNames,
            recentResponderNames: recentResponderNames,
            language: conversationLanguage
        )
        let messages = buildMessages(
            systemPrompt: systemPrompt,
            userMessage: groupPrompt,
            chatHistory: chatHistory,
            language: conversationLanguage
        )

        client.sendChat(messages: messages, completion: completion)
    }

    private func createGroupChatPrompt(
        userMessage: String,
        oshiName: String,
        groupMemberNames: [String],
        recentResponderNames: [String],
        language: String
    ) -> String {
        let members = groupMemberNames.isEmpty ? "" : groupMemberNames.joined(separator: language == "ja" ? "、" : ", ")
        let recentResponders = recentResponderNames.isEmpty ? "" : recentResponderNames.joined(separator: language == "ja" ? "、" : ", ")

        if language == "ja" {
            return """
            【グループチャットでの返信】
            あなたは\(oshiName)として、ファンの最新発言「\(userMessage)」に返事してください。
            参加メンバー: \(members)
            直近で話したメンバー: \(recentResponders)
            ルール:
            • 他のメンバーと同じ内容・同じ相槌を繰り返さず、あなた自身の角度で一言足す
            • 全員が同じ結論に寄らないよう、感情、質問、具体例、軽いツッコミなどを自然に変える
            • 他メンバーの代弁をせず、\(oshiName)本人の短い発言として1〜2文で返す
            """
        }

        return """
        [Group chat reply]
        Reply as \(oshiName) to the fan's latest message: "\(userMessage)".
        Members: \(members)
        Recent speakers: \(recentResponders)
        Rules:
        • Do not repeat the same point or generic acknowledgment as other members; add your own angle
        • Vary the response naturally with emotion, a question, a concrete detail, or light banter
        • Do not speak for other members; keep it as \(oshiName)'s short 1-2 sentence message
        """
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
        
        let messages = buildMessages(
            systemPrompt: systemPrompt,
            userMessage: userPrompt,
            chatHistory: [],
            language: conversationLanguage
        )
        
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

        let messages = buildMessages(
            systemPrompt: systemPrompt,
            userMessage: proactivePrompt,
            chatHistory: chatHistory,
            language: conversationLanguage
        )
        client.sendChat(messages: messages, completion: completion)
    }

    /// 推しから届く定期メッセージ（朝・夜・誕生日・記念日）。instruction は会話言語に合わせて呼び出し側が組み立てる
    func generateGreetingMessage(for oshi: Oshi, instruction: (_ language: String) -> String, chatHistory: [ChatMessage], completion: @escaping (String?, Error?) -> Void) {
        guard let client = client else {
            completion(nil, nil)
            return
        }

        let conversationLanguage = languageManager.getConversationLanguage(for: oshi)
        let messages = buildMessages(
            systemPrompt: createLanguageAwareSystemPrompt(oshi: oshi),
            userMessage: instruction(conversationLanguage),
            chatHistory: chatHistory,
            language: conversationLanguage
        )
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
