//
//  GroupChatMessage.swift
//  osimono
//
//  Created by Apple on 2025/07/18.
//

import Foundation
import SwiftUI

// グループチャットメッセージのデータモデル
struct GroupChatMessage: Identifiable, Codable {
    let id: String
    let content: String
    let isUser: Bool
    let timestamp: TimeInterval
    let groupId: String
    let senderId: String // "user" または 推しのID
    let senderName: String? // 推しの名前（ユーザーの場合はnil）
    let senderImageUrl: String? // 推しの画像URL（ユーザーの場合はnil）
    
    init(id: String, content: String, isUser: Bool, timestamp: TimeInterval, groupId: String, senderId: String, senderName: String? = nil, senderImageUrl: String? = nil) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.groupId = groupId
        self.senderId = senderId
        self.senderName = senderName
        self.senderImageUrl = senderImageUrl
    }
    
    // Dictionary変換用
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "content": content,
            "isUser": isUser,
            "timestamp": timestamp,
            "groupId": groupId,
            "senderId": senderId
        ]
        
        if let senderName = senderName {
            dict["senderName"] = senderName
        }
        
        if let senderImageUrl = senderImageUrl {
            dict["senderImageUrl"] = senderImageUrl
        }
        
        return dict
    }
    
    // Dictionary -> GroupChatMessage変換用
    static func fromDictionary(_ dict: [String: Any]) -> GroupChatMessage? {
        guard let id = dict["id"] as? String,
              let content = dict["content"] as? String,
              let isUser = dict["isUser"] as? Bool,
              let timestamp = dict["timestamp"] as? TimeInterval,
              let groupId = dict["groupId"] as? String,
              let senderId = dict["senderId"] as? String else {
            return nil
        }
        
        let senderName = dict["senderName"] as? String
        let senderImageUrl = dict["senderImageUrl"] as? String
        
        return GroupChatMessage(
            id: id,
            content: content,
            isUser: isUser,
            timestamp: timestamp,
            groupId: groupId,
            senderId: senderId,
            senderName: senderName,
            senderImageUrl: senderImageUrl
        )
    }
}

// グループチャット情報のデータモデル
struct GroupChatInfo: Identifiable, Codable {
    let id: String
    let name: String
    let memberIds: [String] // 推しのIDリスト
    let createdAt: TimeInterval
    let lastMessageTime: TimeInterval
    let lastMessage: String?
    
    // Dictionary変換用
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "name": name,
            "memberIds": memberIds,
            "createdAt": createdAt,
            "lastMessageTime": lastMessageTime,
            "lastMessage": lastMessage ?? ""
        ]
    }
    
    // Dictionary -> GroupChatInfo変換用
    static func fromDictionary(_ dict: [String: Any]) -> GroupChatInfo? {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String,
              let memberIds = dict["memberIds"] as? [String],
              let createdAt = dict["createdAt"] as? TimeInterval,
              let lastMessageTime = dict["lastMessageTime"] as? TimeInterval else {
            return nil
        }
        
        let lastMessage = dict["lastMessage"] as? String
        
        return GroupChatInfo(
            id: id,
            name: name,
            memberIds: memberIds,
            createdAt: createdAt,
            lastMessageTime: lastMessageTime,
            lastMessage: lastMessage
        )
    }
}

// グループチャット用のチャットバブル
struct GroupChatBubble: View {
    let message: GroupChatMessage
    let selectedMembers: [Oshi]
    let primaryColor = Color(.systemPink)
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 4) {
                // 相手のメッセージの場合、アイコンを表示
                if !message.isUser {
                    profileImageView
                        .frame(width: 30, height: 30)
                        .padding(.top, 5)
                }
                
                if message.isUser {
                    Spacer()
                }
                
                VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                    // 送信者名（推しの場合のみ）
                    if !message.isUser, let senderName = message.senderName {
                        Text(senderName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                    }
                    
                    // メッセージ本文
                    Text(message.content)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            message.isUser
                                ? AnyShapeStyle(primaryColor.opacity(0.8))
                                : AnyShapeStyle(Color.white)
                        )
                        .foregroundColor(message.isUser ? .white : .black)
                        .cornerRadius(18)
                }
                
                if !message.isUser {
                    Spacer()
                }
            }
            
            // タイムスタンプ
            Text(formatDate(timestamp: message.timestamp))
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .padding(.horizontal, message.isUser ? 0 : 38)
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 2)
    }
    
    private var profileImageView: some View {
        Group {
            if let imageUrl = message.senderImageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                    default:
                        defaultProfileImage
                    }
                }
            } else {
                defaultProfileImage
            }
        }
    }
    
    private var defaultProfileImage: some View {
        Circle()
            .fill(Color.gray.opacity(0.2))
            .overlay(
                Text(String(message.senderName?.prefix(1) ?? "?"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            )
    }
    
    private func formatDate(timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "MM/dd HH:mm"
        }
        
        return formatter.string(from: date)
    }
}

// グループメンバー選択画面
struct GroupMemberSelectionView: View {
    @Binding var isPresented: Bool
    let allOshiList: [Oshi]
    @Binding var selectedMembers: [Oshi]
    let onSave: () -> Void
    
    @State private var tempSelectedMembers: [Oshi] = []
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: 20) {
                // ヘッダー
                HStack {
                    Text("グループメンバー")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("完了") {
                        selectedMembers = tempSelectedMembers
                        onSave()
                        isPresented = false
                    }
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                
                // 推しリスト
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(allOshiList, id: \.id) { oshi in
                            HStack {
                                // プロフィール画像
                                Group {
                                    if let imageUrl = oshi.imageUrl, let url = URL(string: imageUrl) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .clipShape(Circle())
                                            default:
                                                Circle()
                                                    .fill(Color.gray.opacity(0.2))
                                                    .overlay(
                                                        Text(String(oshi.name.prefix(1)))
                                                            .font(.system(size: 16, weight: .medium))
                                                            .foregroundColor(.gray)
                                                    )
                                            }
                                        }
                                    } else {
                                        Circle()
                                            .fill(Color.gray.opacity(0.2))
                                            .overlay(
                                                Text(String(oshi.name.prefix(1)))
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.gray)
                                            )
                                    }
                                }
                                .frame(width: 44, height: 44)
                                
                                // 名前
                                Text(oshi.name)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                // 選択チェックボックス
                                Button(action: {
                                    if tempSelectedMembers.contains(where: { $0.id == oshi.id }) {
                                        tempSelectedMembers.removeAll { $0.id == oshi.id }
                                    } else {
                                        tempSelectedMembers.append(oshi)
                                    }
                                }) {
                                    Image(systemName: tempSelectedMembers.contains(where: { $0.id == oshi.id }) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(tempSelectedMembers.contains(where: { $0.id == oshi.id }) ? .blue : .gray)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 説明テキスト
                Text("グループチャットに参加させたい推しを選択してください")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 40)
        }
        .onAppear {
            tempSelectedMembers = selectedMembers
        }
    }
}
