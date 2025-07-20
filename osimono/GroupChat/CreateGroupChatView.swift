//
//  CreateGroupChatView.swift
//  osimono
//
//  グループチャット作成画面 - Modern Design
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
    @State private var showingSteps: Bool = false
    
    // Modern color scheme
    private let accentColor = Color(.systemPink)
    private let gradientColors = [Color(.systemPink), Color(.systemPurple)]
    private let createGradient = [Color(.systemGreen), Color(.systemBlue)]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Modern background with subtle gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemGroupedBackground).opacity(0.5)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Modern header with glass effect
                    headerView
                    
                    ScrollView {
                        LazyVStack(spacing: 28) {
                            // Welcome section for new users
                            if showingSteps || allOshiList.isEmpty {
                                welcomeSection
                            }
                            
                            // Group name section with modern card design
                            if !allOshiList.isEmpty {
                                groupNameSection
                            }
                            
                            // Member selection with enhanced UI
                            if !allOshiList.isEmpty {
                                memberSelectionSection
                            }
                            
                            // Create button with modern styling
                            if !allOshiList.isEmpty {
                                createButtonSection
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupInitialData()
        }
    }
    
    private var headerView: some View {
        HStack {
            // 左側ボタンエリア（固定幅）
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .frame(width: 80, alignment: .leading) // 固定幅を設定
            
            // 中央タイトルエリア
            Spacer()
            
            VStack(spacing: 2) {
                Text("新しいグループ")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if !allOshiList.isEmpty {
                    Text("\(selectedMembers.count)人を選択中")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 右側ボタンエリア（固定幅）
            HStack {
                Button(action: {
                    createGroup()
                }) {
                    HStack(spacing: 6) {
                        Text("作成")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: canCreateGroup ? createGradient : [Color.gray]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: canCreateGroup ? Color.green.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                }
                .disabled(!canCreateGroup || isCreating)
                .scaleEffect(canCreateGroup ? 1.0 : 0.95)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: canCreateGroup)
            }
            .frame(width: 80, alignment: .trailing) // 固定幅を設定
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 0)
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    private var welcomeSection: some View {
        VStack(spacing: 20) {
            // Welcome illustration
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: createGradient),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.green.opacity(0.3), radius: 20, x: 0, y: 10)
                
                Image(systemName: "person.3.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
                    .symbolRenderingMode(.hierarchical)
            }
            
            VStack(spacing: 12) {
                Text(allOshiList.isEmpty ? "推しを登録しよう" : "グループを作成しよう")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if allOshiList.isEmpty {
                    Text("グループチャットを楽しむには、まず推しを登録する必要があります。推し管理画面から推しを追加してください。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                } else {
                    Text("複数の推しとのグループチャットを始めましょう。みんなでワイワイ会話を楽しめます！")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            if allOshiList.isEmpty {
                Button(action: {
                    // Navigate to oshi management
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16, weight: .medium))
                        Text("推しを追加する")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: gradientColors),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
                }
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 15, x: 0, y: 5)
        )
    }
    
    private var groupNameSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header with icon
            HStack(spacing: 8) {
                Image(systemName: "textformat.alt")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(accentColor)
                
                Text("グループ名")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            // Modern text field with suggestions
            VStack(alignment: .leading, spacing: 12) {
                TextField("例：推し全員チャット", text: $groupName)
                    .font(.system(size: 16))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                groupName.isEmpty ? Color(.separator) : accentColor,
                                lineWidth: groupName.isEmpty ? 1 : 2
                            )
                    )
                    .animation(.easeInOut(duration: 0.2), value: groupName.isEmpty)
                
                // Suggestion chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(nameSuggestions, id: \.self) { suggestion in
                            Button(action: {
                                groupName = suggestion
                                generateHapticFeedback()
                            }) {
                                Text(suggestion)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(accentColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(accentColor.opacity(0.1))
                                            .overlay(
                                                Capsule()
                                                    .stroke(accentColor.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                Text("空白の場合は「グループチャット」として表示されます")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
        }
//        .padding(20)
//        .background(
//            RoundedRectangle(cornerRadius: 20)
//                .fill(.ultraThinMaterial)
//                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
//        )
    }
    
    private var nameSuggestions: [String] {
        [
            "推し全員",
            "みんなでトーク",
            "お気に入りグループ",
            "最高のメンバー",
            "楽しいチャット"
        ]
    }
    
    private var memberSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header with counter
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(accentColor)
                    
                    Text("メンバー選択")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Modern counter badge
                Text("\(selectedMembers.count)/\(allOshiList.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: selectedMembers.count >= 2 ? createGradient : gradientColors),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            
            VStack(spacing: 12) {
                // Select all/none button with modern design
                selectAllButton
                
                // Member list with modern cards
                LazyVStack(spacing: 8) {
                    ForEach(allOshiList, id: \.id) { oshi in
                        memberCard(oshi: oshi)
                    }
                }
            }
            
            // Validation message with icon
            if selectedMembers.count < 2 {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text("グループチャットには2人以上のメンバーが必要です")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 4)
                .transition(.scale.combined(with: .opacity))
            }
        }
//        .padding(20)
//        .background(
//            RoundedRectangle(cornerRadius: 20)
//                .fill(.ultraThinMaterial)
//                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
//        )
    }
    
    private var selectAllButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                if selectedMembers.count == allOshiList.count {
                    selectedMembers = []
                } else {
                    selectedMembers = allOshiList
                }
            }
            generateHapticFeedback()
        }) {
            HStack(spacing: 12) {
                Image(systemName: selectedMembers.count == allOshiList.count ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(selectedMembers.count == allOshiList.count ? accentColor : .secondary)
                
                Text(selectedMembers.count == allOshiList.count ? "全て解除" : "全て選択")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(selectedMembers.count == allOshiList.count ? 90 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedMembers.count == allOshiList.count)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func memberCard(oshi: Oshi) -> some View {
        Button(action: {
            toggleMemberSelection(oshi: oshi)
        }) {
            HStack(spacing: 16) {
                // Modern profile image with border
                ZStack {
                    Group {
                        if let imageUrl = oshi.imageUrl, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure(_), .empty:
                                    defaultProfileImage(for: oshi)
                                @unknown default:
                                    defaultProfileImage(for: oshi)
                                }
                            }
                        } else {
                            defaultProfileImage(for: oshi)
                        }
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                selectedMembers.contains(where: { $0.id == oshi.id })
                                    ? accentColor : Color.clear,
                                lineWidth: 3
                            )
                    )
                    
                    // Selection indicator
                    if selectedMembers.contains(where: { $0.id == oshi.id }) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 18, y: -18)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                }
                
                // Member info with modern typography
                VStack(alignment: .leading, spacing: 4) {
                    Text(oshi.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let personality = oshi.personality, !personality.isEmpty {
                        Text(personality)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("性格未設定")
                            .font(.system(size: 15))
//                            .foregroundColor(.tertiary)
                            .italic()
                    }
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: selectedMembers.contains(where: { $0.id == oshi.id })
                            ? accentColor.opacity(0.2) : .black.opacity(0.05),
                        radius: selectedMembers.contains(where: { $0.id == oshi.id }) ? 8 : 4,
                        x: 0,
                        y: 2
                    )
            )
            .scaleEffect(selectedMembers.contains(where: { $0.id == oshi.id }) ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedMembers.contains(where: { $0.id == oshi.id }))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func defaultProfileImage(for oshi: Oshi) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        accentColor.opacity(0.3),
                        accentColor.opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(String(oshi.name.prefix(1)))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(accentColor)
            )
    }
    
    private var createButtonSection: some View {
        VStack(spacing: 20) {
            if selectedMembers.count >= 2 {
                // Modern preview card
                groupPreviewCard
            }
            
            // Modern create button with enhanced design
            Button(action: {
                createGroup()
            }) {
                HStack(spacing: 12) {
                    if isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22, weight: .medium))
                    }
                    
                    Text(isCreating ? "作成中..." : "グループを作成")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: canCreateGroup ? createGradient : [Color.gray]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(20)
                .shadow(
                    color: canCreateGroup ? Color.green.opacity(0.4) : .clear,
                    radius: 15,
                    x: 0,
                    y: 8
                )
                .scaleEffect(canCreateGroup ? 1.0 : 0.95)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: canCreateGroup)
            }
            .disabled(!canCreateGroup || isCreating)
        }
//        .padding(20)
//        .background(
//            RoundedRectangle(cornerRadius: 20)
//                .fill(.ultraThinMaterial)
//                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
//        )
    }
    
    private var groupPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(accentColor)
                
                Text("プレビュー")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                // Modern group icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: createGradient),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    if selectedMembers.count == 1 {
                        Text(String(selectedMembers[0].name.prefix(1)))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        HStack(spacing: -8) {
                            ForEach(Array(selectedMembers.prefix(3).enumerated()), id: \.element.id) { index, oshi in
                                Circle()
                                    .fill(.white)
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Text(String(oshi.name.prefix(1)))
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Color.green)
                                    )
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(groupName.isEmpty ? "グループチャット" : groupName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(selectedMembers.map { $0.name }.joined(separator: "、"))
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
        }
    }
    
    private var canCreateGroup: Bool {
        return selectedMembers.count >= 2
    }
    
    private func setupInitialData() {
        // デフォルトで全ての推しを選択（2人以上の場合）
        if allOshiList.count > 1 {
            selectedMembers = allOshiList
        }
        
        // ステップ表示の判定
        showingSteps = allOshiList.isEmpty
    }
    
    private func toggleMemberSelection(oshi: Oshi) {
        generateHapticFeedback()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if selectedMembers.contains(where: { $0.id == oshi.id }) {
                selectedMembers.removeAll { $0.id == oshi.id }
            } else {
                selectedMembers.append(oshi)
            }
        }
    }
    
    private func createGroup() {
        guard canCreateGroup, !isCreating else { return }
        
        isCreating = true
        generateHapticFeedback()
        
        let groupId = UUID().uuidString
        let finalGroupName = groupName.isEmpty ? "グループチャット" : groupName
        let memberIds = selectedMembers.map { $0.id }
        
        groupChatManager.createOrUpdateGroup(
            groupId: groupId,
            name: finalGroupName,
            memberIds: memberIds
        ) { error in
            DispatchQueue.main.async {
                self.isCreating = false
                
                if let error = error {
                    print("グループ作成エラー: \(error.localizedDescription)")
                    // Show error alert with modern design
                } else {
                    print("グループ作成成功 - メンバー: \(memberIds)")
                    
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
    CreateGroupChatView(
        allOshiList: [
            Oshi(id: "oshi1", name: "推し1", imageUrl: nil, backgroundImageUrl: nil, memo: nil, createdAt: nil),
            Oshi(id: "oshi2", name: "推し2", imageUrl: nil, backgroundImageUrl: nil, memo: nil, createdAt: nil),
            Oshi(id: "oshi3", name: "推し3", imageUrl: nil, backgroundImageUrl: nil, memo: nil, createdAt: nil)
        ],
        onCreate: { _ in }
    )
}
