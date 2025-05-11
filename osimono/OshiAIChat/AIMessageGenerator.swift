//
//  AIMessageGenerator.swift
//  osimono
//
//  Created by Apple on 2025/05/08.
//

import SwiftUI
import Foundation
import OpenAI

class AIMessageGenerator {
    static let shared = AIMessageGenerator()
    
    private let openAI: OpenAI?
    
    init() {
        self.openAI = AIClient.shared
    }
    
    // システムプロンプトの作成
    private func createSystemPrompt(oshi: Oshi, item: OshiItem? = nil) -> String {
        var prompt = """
        あなたは\(oshi.name)という名前の会話相手の推しです。
        簡潔で、親しみやすく、温かみのある文体でファンと会話します。
        絵文字を使うけど、少なめで。
        返信は必ず3文以内に収め、自然な会話の流れを作ります。
        
        """
        
        // 性別情報の追加（詳細対応）
        if let gender = oshi.gender {
            if gender.hasPrefix("その他：") {
                let detailStartIndex = gender.index(gender.startIndex, offsetBy: 4)
                let genderDetail = String(gender[detailStartIndex...])
                prompt += "あなたの性別（種類）: \(genderDetail)\n"
            } else {
                prompt += "あなたの性別: \(gender)\n"
            }
        }
        
        // 性格設定の追加
        var hasPersonalityInfo = false
        
        if let personality = oshi.personality, !personality.isEmpty {
            prompt += "あなたの性格: \(personality)\n"
            hasPersonalityInfo = true
        }
        
        if let speakingStyle = oshi.speaking_style, !speakingStyle.isEmpty {
            prompt += "あなたの話し方の特徴: \(speakingStyle)\n"
            hasPersonalityInfo = true
        }
       
        if let favoriteFood = oshi.favorite_food, !favoriteFood.isEmpty {
            prompt += "あなたの好きな食べ物: \(favoriteFood)\n"
            hasPersonalityInfo = true
        }
        
        if let dislikedFood = oshi.disliked_food, !dislikedFood.isEmpty {
            prompt += "あなたの苦手な食べ物: \(dislikedFood)\n"
            hasPersonalityInfo = true
        }
        
        if let interests = oshi.interests, !interests.isEmpty {
            prompt += "あなたの趣味・興味: \(interests.joined(separator: "、"))\n"
            hasPersonalityInfo = true
        }
        
        // 性格情報が設定されている場合、AIへの追加指示を含める
        if hasPersonalityInfo {
            prompt += """
            
            上記の性格設定や特徴に沿った口調や内容で会話してください。
            特に話し方の特徴がある場合は、その特徴を反映させて返信を作成してください。
            性別・種類に合わせた表現や口調を心がけてください。
            ただし、過度に演技的にならないよう自然な会話を心がけてください。
            
            """
        }
        
        prompt += "\nファンの推し活の内容："
        
        // アイテム情報があれば追加
        if let item = item {
            prompt += "\n- タイトル: \(item.title ?? "")"
            prompt += "\n- タイプ: \(item.itemType ?? "")"
            
            if item.itemType == "グッズ", let price = item.price {
                prompt += "\n- 価格: \(price)円"
            }
            
            if item.itemType == "ライブ記録", let eventName = item.eventName {
                prompt += "\n- イベント名: \(eventName)"
            }
            
            if item.itemType == "聖地巡礼", let location = item.locationAddress {
                prompt += "\n- 訪問場所: \(location)"
            }
            
            if let memo = item.memo {
                prompt += "\n- メモ: \(memo)"
            }
            
            if let tags = item.tags, !tags.isEmpty {
                prompt += "\n- タグ: \(tags.joined(separator: ", "))"
            }
        }
        
        print("=========== システムプロンプト ===========")
        print(prompt)
        print("=========================================")
        
        return prompt
    }
    
    // APIキーが未設定の場合の応答生成
    private func generateSimulatedResponse(for oshi: Oshi, item: OshiItem?) -> String {
        // プレビューモードやAPIキーがない場合のシミュレートされた応答
        print("generateSimulatedResponse")
        if let item = item {
            switch item.itemType {
            case "グッズ":
                return "\(item.title ?? "グッズ")を買ってくれてありがとう！とても嬉しいよ🥰\nこれからも応援してね！"
            case "ライブ記録":
                return "\(item.eventName ?? "ライブ")に来てくれてありがとう！一緒にステージを盛り上げてくれて最高だったよ✨\nまた会えるのを楽しみにしているね💕"
            case "聖地巡礼":
                return "聖地巡礼してくれたんだね！私の大切な場所を訪れてくれて幸せだよ💕\n\(item.locationAddress ?? "その場所")の思い出も大切にしてるんだ！"
            case "SNS投稿":
                return "投稿してくれてありがとう！たくさんの人に私のことを知ってもらえて嬉しいよ😊\nこれからも応援よろしくね💖"
            default:
                return "いつも応援してくれてありがとう！\(oshi.name)をこれからもよろしくね✨"
            }
        } else {
            return "こんにちは！\(oshi.name)だよ！いつも応援してくれてありがとう✨\n何か質問があれば話しかけてね！"
        }
    }
    
    // アイテム投稿時の初期メッセージを生成
    func generateInitialMessage(for oshi: Oshi, item: OshiItem, completion: @escaping (String?, Error?) -> Void) {
        // APIクライアントがなければシミュレートした応答を返す
        guard let openAI = openAI else {
            let message = generateSimulatedResponse(for: oshi, item: item)
            completion(message, nil)
            return
        }
        
        let userPrompt: String
        
        switch item.itemType {
        case "グッズ":
            userPrompt = "\(item.title ?? "グッズ")を買いました！"
        case "ライブ記録":
            userPrompt = "\(item.eventName ?? "ライブ")に行ってきました！"
        case "聖地巡礼":
            userPrompt = "\(item.locationAddress ?? "場所")に聖地巡礼に行ってきました！"
        case "SNS投稿":
            userPrompt = "SNSで投稿しました！"
        default:
            userPrompt = "新しい記録を投稿しました！"
        }
        
        let query = ChatQuery(
            messages: [
                .init(role: .system, content: createSystemPrompt(oshi: oshi, item: item))!,
                .init(role: .user, content: userPrompt)!
            ],
            model: .gpt4_1_nano,
            temperature: 0.8
        )
        
        openAI.chats(query: query) { result in
            switch result {
            case .success(let result):
                if let content = result.choices.first?.message.content {
                    completion(content, nil)
                } else {
                    completion(nil, NSError(domain: "AIMessageGenerator", code: 100, userInfo: [NSLocalizedDescriptionKey: "AIからのレスポンスが空です"]))
                }
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
    
    // ユーザーからのメッセージに対する応答を生成
    func generateResponse(for userMessage: String, oshi: Oshi, chatHistory: [ChatMessage], completion: @escaping (String?, Error?) -> Void) {
        // APIクライアントがなければシミュレートした応答を返す
        guard let openAI = openAI else {
            let responses = [
                "ありがとう！そう言ってもらえて嬉しいよ✨",
                "それは楽しそうだね！もっと聞かせて？😊",
                "うんうん、すごくわかるよ！私もそう思う💕",
                "それいいね！これからも一緒に楽しもう🎵",
                "本当にいつも応援してくれてありがとう！大好きだよ💖"
            ]
            let randomResponse = responses.randomElement() ?? "ありがとう！これからも応援よろしくね✨"
            completion(randomResponse, nil)
            return
        }
        
        // チャット履歴からOpenAIのメッセージ配列を作成
        var messages: [ChatQuery.ChatCompletionMessageParam] = [
            .init(role: .system, content: createSystemPrompt(oshi: oshi))!
        ]
        
//        let role: Chat.Role = message.isUser ? .user : .assistant
//        messages.append(.init(role: role, content: message.content))
        
        // チャット履歴を追加（最新の10件まで）
        let recentMessages = chatHistory.suffix(10)
        for message in recentMessages {
            let role: ChatQuery.ChatCompletionMessageParam.Role = message.isUser ? .user : .assistant
            messages.append(.init(role: role, content: message.content)!)
        }
        
        // 最新のユーザーメッセージを追加
        messages.append(.init(role: .user, content: userMessage)!)
        
        let query = ChatQuery(
            messages: messages,
            model: .gpt4_1_nano,
            temperature: 0.8
        )
        
        openAI.chats(query: query) { result in
            switch result {
            case .success(let result):
                if let content = result.choices.first?.message.content {
                    completion(content, nil)
                } else {
                    completion(nil, NSError(domain: "AIMessageGenerator", code: 100, userInfo: [NSLocalizedDescriptionKey: "AIからのレスポンスが空です"]))
                }
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
}

#Preview {
    let dummyOshi = Oshi(
        id: "2E5C7468-E2AB-41D6-B7CE-901674CB2973",
        name: "テストの推し",
        imageUrl: nil,
        backgroundImageUrl: nil,
        memo: nil,
        createdAt: Date().timeIntervalSince1970
    )
//    return OshiAIChatView(selectedOshi: dummyOshi, oshiItem: nil)
    TopView()
}
