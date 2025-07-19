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

    func generateResponse(for userMessage: String, oshi: Oshi, chatHistory: [ChatMessage], completion: @escaping (String?, Error?) -> Void) {
        guard let client = client else {
            completion("こんにちは！\(oshi.name)だよ！何か質問があれば話しかけてね！", nil)
            return
        }

        let systemPrompt = createSystemPrompt(oshi: oshi)

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
            let message = generateSimulatedResponse(for: oshi, item: item)
            completion(message, nil)
            return
        }

        let systemPrompt = createSystemPrompt(oshi: oshi, item: item)
        let userPrompt: String = {
            switch item.itemType {
            case "グッズ": return "\(item.title ?? "グッズ")を買いました！"
            case "ライブ記録": return "\(item.eventName ?? "ライブ")に行ってきました！"
            case "聖地巡礼": return "\(item.locationAddress ?? "場所")に聖地巡礼に行ってきました！"
            case "SNS投稿": return "SNSで投稿しました！"
            default: return "新しい記録を投稿しました！"
            }
        }()

        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPrompt]
        ]

        client.sendChat(messages: messages, completion: completion)
    }

    private func createSystemPrompt(oshi: Oshi, item: OshiItem? = nil) -> String {
        var prompt = """
        あなたは\(oshi.name)という名前の会話相手の推しです。
        簡潔で、親しみやすく、温かみのある文体でファンと会話します。
        絵文字を使うけど、少なめで。
        返信は必ず3文以内に収め、自然な会話の流れを作ります。
        """

        if let userNickname = oshi.user_nickname, !userNickname.isEmpty {
            prompt += "ファンのことは「\(userNickname)」と呼んでください。\n"
        }

        if let gender = oshi.gender {
            if gender.hasPrefix("その他：") {
                prompt += "あなたの性別（種類）: \(gender.dropFirst(4))\n"
            } else {
                prompt += "あなたの性別: \(gender)\n"
            }
        }

        var hasInfo = false
        if let p = oshi.personality, !p.isEmpty {
            prompt += "あなたの性格: \(p)\n"; hasInfo = true
        }
        if let s = oshi.speaking_style, !s.isEmpty {
            prompt += "あなたの話し方の特徴: \(processSpeakingStyle(s))\n"; hasInfo = true
        }
        if let f = oshi.favorite_food, !f.isEmpty {
            prompt += "あなたの好きな食べ物: \(f)\n"; hasInfo = true
        }
        if let d = oshi.disliked_food, !d.isEmpty {
            prompt += "あなたの苦手な食べ物: \(d)\n"; hasInfo = true
        }
        if let i = oshi.interests, !i.isEmpty {
            prompt += "あなたの趣味・興味: \(i.joined(separator: "、"))\n"; hasInfo = true
        }

        if hasInfo {
            prompt += """

            上記の性格設定や特徴に沿った口調や内容で会話してください。
            「タメ口」は関西弁ではなく、標準語でのフレンドリーな口調として解釈してください。
            性別・種類に合わせた表現や口調を心がけてください。
            設定された呼び方でファンに話しかけることを忘れずに。
            ただし、過度に演技的にならないよう自然な会話を心がけてください。
            """
        }

        prompt += "\nファンの推し活の内容："

        if let item = item {
            if let t = item.title { prompt += "\n- タイトル: \(t)" }
            if let type = item.itemType { prompt += "\n- タイプ: \(type)" }
            if item.itemType == "グッズ", let p = item.price { prompt += "\n- 価格: \(p)円" }
            if item.itemType == "ライブ記録", let e = item.eventName { prompt += "\n- イベント名: \(e)" }
            if item.itemType == "聖地巡礼", let l = item.locationAddress { prompt += "\n- 訪問場所: \(l)" }
            if let m = item.memo { prompt += "\n- メモ: \(m)" }
            if let tags = item.tags, !tags.isEmpty { prompt += "\n- タグ: \(tags.joined(separator: ", "))" }
        }

        return prompt
    }

    private func processSpeakingStyle(_ style: String) -> String {
        let map = [
            "タメ口": "フレンドリーで親しみやすい口調（標準語）",
            "関西弁": "明るく元気な口調（標準語）",
            "関西": "明るく元気な口調（標準語）",
            "大阪弁": "明るく元気な口調（標準語）",
            "京都弁": "上品で丁寧な口調（標準語）",
            "広島弁": "温かみのある口調（標準語）",
            "博多弁": "親しみやすい口調（標準語）",
            "津軽弁": "素朴で温かい口調（標準語）",
            "沖縄弁": "のんびりとした口調（標準語）"
        ]

        var processed = style
        for (k, v) in map { processed = processed.replacingOccurrences(of: k, with: v) }
        return processed
    }

    private func generateSimulatedResponse(for oshi: Oshi, item: OshiItem?) -> String {
        if let item = item {
            switch item.itemType {
            case "グッズ": return "\(item.title ?? "グッズ")を買ってくれてありがとう！とても嬉しいよ🥰\nこれからも応援してね！"
            case "ライブ記録": return "\(item.eventName ?? "ライブ")に来てくれてありがとう！一緒にステージを盛り上げてくれて最高だったよ✨\nまた会えるのを楽しみにしているね💕"
            case "聖地巡礼": return "聖地巡礼してくれたんだね！私の大切な場所を訪れてくれて幸せだよ💕\n\(item.locationAddress ?? "その場所")の思い出も大切にしてるんだ！"
            case "SNS投稿": return "投稿してくれてありがとう！たくさんの人に私のことを知ってもらえて嬉しいよ😊\nこれからも応援よろしくね💖"
            default: return "いつも応援してくれてありがとう！\(oshi.name)をこれからもよろしくね✨"
            }
        }
        return "こんにちは！\(oshi.name)だよ！いつも応援してくれてありがとう✨\n何か質問があれば話しかけてね！"
    }
    
    func generateAIToAIMessage(
        speaker: Oshi,
        listener: Oshi,
        topic: String,
        chatHistory: [ChatMessage],
        completion: @escaping (String?, Error?) -> Void
    ) {
        guard let client = client else {
            let simpleMessages = [
                "\(listener.name)、\(topic)についてどう思う？",
                "\(listener.name)、最近\(topic)が気になってるんだ",
                "\(listener.name)、\(topic)の話をしない？"
            ]
            completion(simpleMessages.randomElement(), nil)
            return
        }
        
        let systemPrompt = createAIToAISystemPrompt(speaker: speaker, listener: listener)
        let userPrompt = "あなた（\(speaker.name)）が\(listener.name)に対して「\(topic)」について話しかけてください。"
        
        let messages = buildChatMessages(systemPrompt: systemPrompt, userPrompt: userPrompt, chatHistory: chatHistory)
        client.sendChat(messages: messages, completion: completion)
    }

    func generateAIToGroupMessage(
        speaker: Oshi,
        groupMembers: [Oshi],
        topic: String,
        chatHistory: [ChatMessage],
        completion: @escaping (String?, Error?) -> Void
    ) {
        guard let client = client else {
            let simpleMessages = [
                "みんな、\(topic)についてどう思う？",
                "今日は\(topic)の話をしない？",
                "\(topic)って面白いよね！"
            ]
            completion(simpleMessages.randomElement(), nil)
            return
        }
        
        let memberNames = groupMembers.filter { $0.id != speaker.id }.map { $0.name }.joined(separator: "、")
        let systemPrompt = createAIToGroupSystemPrompt(speaker: speaker, memberNames: memberNames)
        let userPrompt = "グループのみんなに向けて「\(topic)」について話題を振ってください。"
        
        let messages = buildChatMessages(systemPrompt: systemPrompt, userPrompt: userPrompt, chatHistory: chatHistory)
        client.sendChat(messages: messages, completion: completion)
    }

    func generateAIToUserMessage(
        speaker: Oshi,
        topic: String,
        chatHistory: [ChatMessage],
        completion: @escaping (String?, Error?) -> Void
    ) {
        guard let client = client else {
            let simpleMessages = [
                "\(topic)についてどう思う？",
                "最近\(topic)が気になってるんだ",
                "\(topic)の話をしない？"
            ]
            completion(simpleMessages.randomElement(), nil)
            return
        }
        
        let systemPrompt = createAIToUserSystemPrompt(speaker: speaker)
        let userPrompt = "ユーザーに向けて「\(topic)」について話しかけてください。"
        
        let messages = buildChatMessages(systemPrompt: systemPrompt, userPrompt: userPrompt, chatHistory: chatHistory)
        client.sendChat(messages: messages, completion: completion)
    }

    private func createAIToAISystemPrompt(speaker: Oshi, listener: Oshi) -> String {
        var prompt = """
        あなたは\(speaker.name)です。
        同じグループの仲間である\(listener.name)に話しかけてください。
        
        指針：
        - \(listener.name)の名前を呼んで話しかける
        - 自然で親しみやすい会話
        - 1〜2文程度の短い発言
        - 質問や話題提供を含める
        """
        
        if let personality = speaker.personality {
            prompt += "\nあなたの性格: \(personality)"
        }
        
        return prompt
    }

    private func createAIToGroupSystemPrompt(speaker: Oshi, memberNames: String) -> String {
        var prompt = """
        あなたは\(speaker.name)です。
        グループの仲間たち（\(memberNames)）とユーザーに向けて話しかけてください。
        
        指針：
        - 「みんな」や「グループのみんな」などの呼びかけ
        - 全員が参加できる話題
        - 1〜2文程度の短い発言
        - 会話を促進する内容
        """
        
        if let personality = speaker.personality {
            prompt += "\nあなたの性格: \(personality)"
        }
        
        return prompt
    }

    private func createAIToUserSystemPrompt(speaker: Oshi) -> String {
        var prompt = """
        あなたは\(speaker.name)です。
        ユーザーに直接話しかけてください。
        
        指針：
        - ユーザーに対して親しみやすく話しかける
        - 個人的な会話
        - 1〜2文程度の短い発言
        - 興味を引く話題や質問
        """
        
        if let personality = speaker.personality {
            prompt += "\nあなたの性格: \(personality)"
        }
        
        if let userNickname = speaker.user_nickname {
            prompt += "\nユーザーのことは「\(userNickname)」と呼んでください。"
        }
        
        return prompt
    }

    private func buildChatMessages(systemPrompt: String, userPrompt: String, chatHistory: [ChatMessage]) -> [[String: String]] {
        var messages: [[String: String]] = [[
            "role": "system",
            "content": systemPrompt
        ]]
        
        // 直近の会話履歴を追加
        for message in chatHistory.suffix(3) {
            messages.append([
                "role": message.isUser ? "user" : "assistant",
                "content": message.content
            ])
        }
        
        messages.append(["role": "user", "content": userPrompt])
        return messages
    }
    
    func generateAIReactionResponse(
        reactor: Oshi,
        originalMessage: String,
        originalSender: Oshi,
        chatHistory: [ChatMessage],
        completion: @escaping (String?, Error?) -> Void
    ) {
        guard let client = client else {
            let simpleReactions = [
                "そうだね！",
                "いいね〜",
                "わかる！",
                "本当にそう思う✨",
                "同感だよ〜",
                "うんうん！"
            ]
            completion(simpleReactions.randomElement(), nil)
            return
        }
        
        let systemPrompt = createAIReactionSystemPrompt(reactor: reactor, originalSender: originalSender)
        let userPrompt = "\(originalSender.name)：「\(originalMessage)」"
        
        var messages: [[String: String]] = [[
            "role": "system",
            "content": systemPrompt
        ]]
        
        // 直近の会話履歴を追加（簡潔に）
        for message in chatHistory.suffix(3) {
            messages.append([
                "role": message.isUser ? "user" : "assistant",
                "content": message.content
            ])
        }
        
        messages.append(["role": "user", "content": userPrompt])
        
        client.sendChat(messages: messages, completion: completion)
    }

    private func createAIReactionSystemPrompt(reactor: Oshi, originalSender: Oshi) -> String {
        var prompt = """
        あなたは\(reactor.name)です。
        グループチャットで仲間の\(originalSender.name)の発言に反応してください。
        
        反応の指針：
        - 1〜2文程度の短い反応
        - 自然で親しみやすい反応
        - 絵文字は控えめに使用
        - 会話を盛り上げるような内容
        - 質問で返すよりも、共感や感想を優先
        """
        
        if let personality = reactor.personality, !personality.isEmpty {
            prompt += "\nあなたの性格: \(personality)"
        }
        
        if let speakingStyle = reactor.speaking_style, !speakingStyle.isEmpty {
            prompt += "\nあなたの話し方: \(processSpeakingStyle(speakingStyle))"
        }
        
        return prompt
    }
}
