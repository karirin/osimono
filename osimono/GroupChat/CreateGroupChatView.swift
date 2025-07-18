//
//  CreateGroupChatView.swift
//  osimono
//
//  グループチャット作成画面
//

import SwiftUI

struct CreateGroupChatView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var groupChatManager = GroupChatManager()
    
    let allOshiList: [Oshi]
    let onCreate: (GroupChatInfo) -> Void
    
    @State private var groupName: String = ""
    @State private var selectedMembers: [Oshi] = []
    @State private var isCreating: Bool = false
    
    let primaryColor = Color(.systemPink)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                headerView
                
                ScrollView {
                    VStack(spacing: 24) {
                        // グループ名入力
                        groupNameSection
                        
                        // メンバー選択
                        memberSelectionSection
                        
                        // 作成ボタン
                        createButtonSection
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .navigationBarHidden(true)
        .onAppear {
            // デフォルトで全ての推しを選択
            if allOshiList.count > 1 {
                selectedMembers = allOshiList
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Button("キャンセル") {
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.blue)
            
            Spacer()
            
            Text("グループ作成")
                .font(.headline)
                .fontWeight(.medium)
            
            Spacer()
            
            Button("作成") {
                createGroup()
            }
            .foregroundColor(canCreateGroup ? .blue : .gray)
            .disabled(!canCreateGroup || isCreating)
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 1, y: 1)
    }
    
    private var groupNameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("グループ名")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField("例：推し全員チャット", text: $groupName)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), lineWidth: 1)
                )
            
            Text("空白の場合は「グループチャット」になります")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var memberSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("メンバー")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("(\(selectedMembers.count)/\(allOshiList.count))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if allOshiList.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("推しが登録されていません")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("まず推しを登録してからグループチャットを作成してください")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            } else {
                VStack(spacing: 0) {
                    // 全選択/全解除ボタン
                    HStack {
                        Button(action: {
                            if selectedMembers.count == allOshiList.count {
                                selectedMembers = []
                            } else {
                                selectedMembers = allOshiList
                            }
                            generateHapticFeedback()
                        }) {
                            HStack {
                                Image(systemName: selectedMembers.count == allOshiList.count ? "checkmark.square.fill" : "square")
                                    .foregroundColor(selectedMembers.count == allOshiList.count ? primaryColor : .gray)
                                
                                Text(selectedMembers.count == allOshiList.count ? "全解除" : "全選択")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    // 推しリスト
                    ForEach(allOshiList, id: \.id) { oshi in
                        memberRowView(oshi: oshi)
                        
                        if oshi.id != allOshiList.last?.id {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            
            if selectedMembers.count < 2 {
                Text("グループチャットには2人以上のメンバーが必要です")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    private func memberRowView(oshi: Oshi) -> some View {
        Button(action: {
            toggleMemberSelection(oshi: oshi)
        }) {
            HStack(spacing: 12) {
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
                                defaultProfileImage(for: oshi)
                            }
                        }
                    } else {
                        defaultProfileImage(for: oshi)
                    }
                }
                .frame(width: 44, height: 44)
                
                // 推し情報
                VStack(alignment: .leading, spacing: 2) {
                    Text(oshi.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let personality = oshi.personality, !personality.isEmpty {
                        Text(personality)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // 選択状態
                Image(systemName: selectedMembers.contains(where: { $0.id == oshi.id }) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(selectedMembers.contains(where: { $0.id == oshi.id }) ? primaryColor : .gray)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func defaultProfileImage(for oshi: Oshi) -> some View {
        Circle()
            .fill(Color.gray.opacity(0.2))
            .overlay(
                Text(String(oshi.name.prefix(1)))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.gray)
            )
    }
    
    private var createButtonSection: some View {
        VStack(spacing: 16) {
            if selectedMembers.count >= 2 {
                // プレビュー
                VStack(alignment: .leading, spacing: 8) {
                    Text("作成されるグループ")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        // グループアイコンプレビュー
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 50, height: 50)
                            
                            if selectedMembers.count == 1 {
                                Text(String(selectedMembers[0].name.prefix(1)))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.gray)
                            } else {
                                ForEach(Array(selectedMembers.prefix(2).enumerated()), id: \.element.id) { index, oshi in
                                    Circle()
                                        .fill(primaryColor.opacity(0.3))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Text(String(oshi.name.prefix(1)))
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                        .offset(
                                            x: index == 0 ? -8 : 8,
                                            y: index == 0 ? -8 : 8
                                        )
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(groupName.isEmpty ? "グループチャット" : groupName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text(selectedMembers.map { $0.name }.joined(separator: "、"))
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
            
            // 作成ボタン
            Button(action: {
                createGroup()
            }) {
                HStack {
                    if isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                    }
                    
                    Text(isCreating ? "作成中..." : "グループを作成")
                        .font(.headline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: canCreateGroup ? [primaryColor, primaryColor.opacity(0.8)] : [Color.gray, Color.gray.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(15)
                .shadow(color: canCreateGroup ? primaryColor.opacity(0.3) : Color.clear, radius: 10, x: 0, y: 5)
            }
            .disabled(!canCreateGroup || isCreating)
        }
    }
    
    private var canCreateGroup: Bool {
        return selectedMembers.count >= 2
    }
    
    private func toggleMemberSelection(oshi: Oshi) {
        generateHapticFeedback()
        
        if selectedMembers.contains(where: { $0.id == oshi.id }) {
            selectedMembers.removeAll { $0.id == oshi.id }
        } else {
            selectedMembers.append(oshi)
        }
    }
    
    private func createGroup() {
        guard canCreateGroup, !isCreating else { return }
        
        isCreating = true
        
        let groupId = UUID().uuidString
        let finalGroupName = groupName.isEmpty ? "グループチャット" : groupName
        let memberIds = selectedMembers.map { $0.id }
        
        // グループ情報を作成
        groupChatManager.createOrUpdateGroup(
            groupId: groupId,
            name: finalGroupName,
            memberIds: memberIds
        ) { error in
            DispatchQueue.main.async {
                self.isCreating = false
                
                if let error = error {
                    print("グループ作成エラー: \(error.localizedDescription)")
                    // エラーアラートを表示
                } else {
                    print("グループ作成成功 - メンバー: \(memberIds)")
                    
                    // 作成成功
                    let groupInfo = GroupChatInfo(
                        id: groupId,
                        name: finalGroupName,
                        memberIds: memberIds,
                        createdAt: Date().timeIntervalSince1970,
                        lastMessageTime: 0,
                        lastMessage: nil
                    )
                    
                    self.onCreate(groupInfo)
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

#Preview {
    CreateGroupChatView(allOshiList: [], onCreate: { _ in })
}
