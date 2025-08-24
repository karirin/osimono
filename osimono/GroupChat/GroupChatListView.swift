//
//  GroupChatRowView.swift
//  osimono
//
//  改善されたグループチャット行ビュー - 編集機能付き
//

import SwiftUI

struct GroupChatRowView: View {
    let group: GroupChatInfo
    let unreadCount: Int
    let allOshiList: [Oshi]
    var showEditButtons: Bool = false
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    var groupMembers: [Oshi] {
        return allOshiList.filter { group.memberIds.contains($0.id) }
    }
    
    private let primaryColor = Color(.systemPink)
    
    var body: some View {
        HStack(spacing: 12) {
            // グループアイコン
            groupIconView
                .frame(width: 56, height: 56)
            
            // グループ情報
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(group.name.isEmpty ? L10n.groupChat : group.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(formatTime(group.lastMessageTime))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text(group.lastMessage ?? L10n.noMessagesYet)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if unreadCount > 0 {
                        unreadBadge
                    }
                }
                
                // メンバー名表示
                Text(groupMembers.map { $0.name }.joined(separator: "、"))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            // 編集モード時のボタン
            if showEditButtons {
                VStack(spacing: 5) {
                    // グループ編集ボタン
                    Button(action: {
                        onEdit?()
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                            Text(L10n.edit)
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // グループ削除ボタン
                    Button(action: {
                        onDelete?()
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                            Text(L10n.delete)
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
    }
    
    private var groupIconView: some View {
        ZStack {
            // 背景サークル
            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [
                        primaryColor.opacity(0.1),
                        primaryColor.opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 56, height: 56)
                .overlay(
                    Circle()
                        .stroke(primaryColor.opacity(0.2), lineWidth: 1)
                )
            
            // アイコン内容
            if groupMembers.isEmpty {
                // メンバーがいない場合のデフォルトアイコン
                Image(systemName: "person.2.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(primaryColor.opacity(0.7))
            } else if groupMembers.count == 1 {
                // 1人の場合は通常のプロフィール画像
                singleMemberIcon(groupMembers[0])
            } else if groupMembers.count == 2 {
                // 2人の場合は左右に配置
                twoMembersIcon
            } else {
                // 3人以上の場合は三角形配置
                multipleMembersIcon
            }
        }
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // 1人のメンバーアイコン
    private func singleMemberIcon(_ oshi: Oshi) -> some View {
        Group {
            if let imageUrl = oshi.imageUrl,
               !imageUrl.isEmpty,
               let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                    case .failure(_):
                        fallbackIcon(for: oshi, size: 48)
                    case .empty:
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 48, height: 48)
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    @unknown default:
                        fallbackIcon(for: oshi, size: 48)
                    }
                }
            } else {
                fallbackIcon(for: oshi, size: 48)
            }
        }
    }
    
    // 2人のメンバーアイコン
    private var twoMembersIcon: some View {
        ZStack {
            // 左側のメンバー
            memberCircle(groupMembers[0], size: 32)
                .offset(x: -8, y: 0)
            
            // 右側のメンバー
            memberCircle(groupMembers[1], size: 32)
                .offset(x: 8, y: 0)
        }
    }
    
    // 3人以上のメンバーアイコン
    private var multipleMembersIcon: some View {
        ZStack {
            // 上部中央
            memberCircle(groupMembers[0], size: 24)
                .offset(x: 0, y: -10)
            
            // 左下
            memberCircle(groupMembers[1], size: 24)
                .offset(x: -10, y: 8)
            
            // 右下
            if groupMembers.count > 2 {
                memberCircle(groupMembers[2], size: 24)
                    .offset(x: 10, y: 8)
            }
            
            // 4人以上の場合は数字表示
            if groupMembers.count > 3 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("+\(groupMembers.count - 3)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(2)
                            .background(primaryColor)
                            .clipShape(Circle())
                            .offset(x: 8, y: 8)
                    }
                }
            }
        }
    }
    
    // 個別メンバーサークル
    private func memberCircle(_ oshi: Oshi, size: CGFloat) -> some View {
        Group {
            if let imageUrl = oshi.imageUrl,
               !imageUrl.isEmpty,
               let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1.5)
                            )
                    case .failure(_):
                        fallbackIcon(for: oshi, size: size)
                    case .empty:
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: size, height: size)
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                    @unknown default:
                        fallbackIcon(for: oshi, size: size)
                    }
                }
            } else {
                fallbackIcon(for: oshi, size: size)
            }
        }
    }
    
    // フォールバックアイコン
    private func fallbackIcon(for oshi: Oshi, size: CGFloat) -> some View {
        Circle()
            .fill(LinearGradient(
                gradient: Gradient(colors: [
                    generateColorFromString(oshi.id),
                    generateColorFromString(oshi.id).opacity(0.7)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: size, height: size)
            .overlay(
                Text(String(oshi.name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            )
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: size > 30 ? 1.5 : 1)
            )
    }
    
    // 文字列からカラーを生成
    private func generateColorFromString(_ string: String) -> Color {
        let colors: [Color] = [
            .red, .blue, .green, .orange, .purple, .pink,
            .teal, .indigo, .mint, .cyan, .yellow, .brown
        ]
        
        let hash = abs(string.hashValue)
        let index = hash % colors.count
        return colors[index]
    }
    
    private var unreadBadge: some View {
        Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, unreadCount > 9 ? 6 : 8)
            .padding(.vertical, 4)
            .background(Color.red)
            .clipShape(Capsule())
            .scaleEffect(0.9)
    }
    
    private func formatTime(_ timestamp: TimeInterval) -> String {
        if timestamp == 0 {
            return ""
        }
        
        let date = Date(timeIntervalSince1970: timestamp)
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return L10n.yesterdayLabel // 修正: ハードコーディングされた文字列を多言語対応
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) == true {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            formatter.locale = Locale.current // 修正: 日本語に固定されていたロケールを現在のロケールに変更
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
    }
}

// プレビュー用のサンプルデータ
#Preview {
    VStack(spacing: 0) {
        // 通常モード
//        GroupChatRowView(
//            group: GroupChatInfo(
//                id: "1",
//                name: "推し2人チーム",
//                memberIds: ["oshi1", "oshi2"],
//                createdAt: Date().timeIntervalSince1970,
//                lastMessageTime: Date().timeIntervalSince1970,
//                lastMessage: "今度一緒にお出かけしましょう！"
//            ),
//            unreadCount: 3,
//            allOshiList: [
//                Oshi(id: "oshi1", name: "田中さん", imageUrl: nil, backgroundImageUrl: nil, memo: nil, createdAt: nil),
//                Oshi(id: "oshi2", name: "佐藤くん", imageUrl: nil, backgroundImageUrl: nil, memo: nil, createdAt: nil)
//            ]
//        )
        
        Divider()
        
        // 編集モード
        GroupChatRowView(
            group: GroupChatInfo(
                id: "2",
                name: "編集中のグループ",
                memberIds: ["oshi1", "oshi2"],
                createdAt: Date().timeIntervalSince1970,
                lastMessageTime: Date().timeIntervalSince1970 - 3600,
                lastMessage: "楽しかったね〜！"
            ),
            unreadCount: 0,
            allOshiList: [
                Oshi(id: "oshi1", name: "田中さん", imageUrl: nil, backgroundImageUrl: nil, memo: nil, createdAt: nil),
                Oshi(id: "oshi2", name: "佐藤くん", imageUrl: nil, backgroundImageUrl: nil, memo: nil, createdAt: nil)
            ],
            showEditButtons: true,
            onEdit: { print("グループ編集") },
            onDelete: { print("グループ削除") }
        )
    }
    .background(Color(.systemGroupedBackground))
}
