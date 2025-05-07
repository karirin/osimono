//
//  TestChatView.swift
//  osimono
//
//  Created by Apple on 2025/05/06.
//

import SwiftUI

struct ChatTestView: View {
    @State private var input = ""
    @State private var logs: [String] = ["🧑‍💻: こんにちは"]
    @State private var isSending = false

    var body: some View {
        VStack {
            ScrollView {
                ForEach(logs, id: \.self) { line in
                    Text(line)
                        .frame(
                            maxWidth: .infinity,
                            alignment: line.hasPrefix("🧑‍💻") ? .trailing : .leading
                        )
                        .padding(.vertical, 4)
                }
            }
            .padding()

            HStack {
                TextField("メッセージを入力", text: $input)
                    .textFieldStyle(.roundedBorder)
                Button("送信") { send() }
                    .disabled(input.isEmpty || isSending)
            }
            .padding()
        }
    }

    private func send() {
        let userText = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty else { return }

        logs.append("🧑‍💻: " + userText)
        input = ""

        // 🔑 API キー確認
        guard !apiKey.isEmpty else {
            logs.append("⚠️ API キーが設定されていません（Info.plist の OPENAI_API_KEY を確認）")
            return
        }

        isSending = true

        // --- OpenAI API 呼び出し ---
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "あなたは親しみやすい日本語の AI です。"],
                ["role": "user",   "content": userText]
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data, response, error in
            defer { isSending = false }

            // --- ステータスコードと通信エラーのログ ---
            if let http = response as? HTTPURLResponse {
                print("HTTP Status:", http.statusCode)
            }
            if let error {
                print("URLSession error:", error)
            }

            guard let data else { return }

            // --- OpenAI 側のエラー JSON をキャッチ ---
            if
                let errJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let err = errJson["error"] as? [String: Any],
                let msg = err["message"] as? String
            {
                DispatchQueue.main.async {
                    logs.append("⚠️ \(msg)")          // 401 や 429 などを UI に反映
                    print("msg      :\(msg)")
                }
                return
            }

            // --- 通常レスポンス ---
            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let content = ((choices.first?["message"] as? [String: Any])?["content"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            else { return }

            DispatchQueue.main.async {
                logs.append("🤖: " + content)
            }
        }.resume()
    }

    /// Info.plist に `OPENAI_API_KEY` を追加しておく
    private var apiKey: String {
        Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String ?? ""
    }
}

#Preview {
    ChatTestView()
}
