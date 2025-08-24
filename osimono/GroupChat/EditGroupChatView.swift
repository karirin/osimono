//
//  EditGroupChatView.swift
//  osimono
//
//  グループチャット編集画面 - Modern Design
//

import SwiftUI

struct EditGroupChatView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var groupChatManager = GroupChatManager()
    
    let group: GroupChatInfo
    let allOshiList: [Oshi]
    let onUpdate: (GroupChatInfo) -> Void
    
    @State private var groupName: String = ""
    @State private var selectedMembers: [Oshi] = []
    @State private var isUpdating: Bool = false
    @State private var showDeleteAlert: Bool = false
    
    // Modern color scheme
    private let accentColor = Color(.systemPink)
    private let gradientColors = [Color(.systemPink), Color(.systemPurple)]
    
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
                            // Group name section with modern card design
                            groupNameSection
                            
                            // Member selection with enhanced UI
                            memberSelectionSection
                            
                            // Update button with modern styling
                            updateButtonSection
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
        .alert("グループを削除", isPresented: $showDeleteAlert) {
            Button("削除", role: .destructive) {
                // Delete group logic here
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("このグループを削除しますか？この操作は取り消せません。")
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
                Text(L10n.editGroup)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(L10n.membersCount(selectedMembers.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 右側ボタンエリア（固定幅）
            HStack {
                Button(action: {
                    updateGroup()
                }) {
                    HStack(spacing: 6) {
                        Text(L10n.save)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: canUpdateGroup ? gradientColors : [Color.gray]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: canUpdateGroup ? accentColor.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                }
                .disabled(!canUpdateGroup || isUpdating)
                .scaleEffect(canUpdateGroup ? 1.0 : 0.95)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: canUpdateGroup)
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
    
    private var groupNameSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header with icon
            HStack(spacing: 8) {
                Image(systemName: "textformat")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(accentColor)
                
                Text(L10n.groupName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            // Modern text field
            VStack(alignment: .leading, spacing: 8) {
                TextField(L10n.groupNamePlaceholder, text: $groupName)
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
                
                Text(L10n.groupNameEmptyDefault)
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
    
    private var memberSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header with counter
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(accentColor)
                    
                    Text(L10n.memberSelection)
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
                                    gradient: Gradient(colors: gradientColors),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            
            if allOshiList.isEmpty {
                emptyStateView
            } else {
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
            }
            
            // Validation message
            if selectedMembers.count < 1 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(L10n.validationMinMembers)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
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
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 4) {
                Text(L10n.registerOshiFirst) // 修正: ハードコーディングされた文字列を多言語対応
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(L10n.registerOshiMessage) // 修正: ハードコーディングされた文字列を多言語対応
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .background(Color(.systemBackground))
        .cornerRadius(16)
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
                
                Text(selectedMembers.count == allOshiList.count ? L10n.deselectAll : L10n.selectAll)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
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
                        Text(L10n.noName)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
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
    
    private var updateButtonSection: some View {
        VStack(spacing: 20) {
            if selectedMembers.count >= 1 {
                // Modern preview card
                groupPreviewCard
            }
            
            // Modern update button
            Button(action: {
                updateGroup()
            }) {
                HStack(spacing: 12) {
                    if isUpdating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22, weight: .medium))
                    }
                    
                    Text(isUpdating ? L10n.updating : L10n.update)
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: canUpdateGroup ? gradientColors : [Color.gray]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(20)
                .shadow(
                    color: canUpdateGroup ? accentColor.opacity(0.4) : .clear,
                    radius: 15,
                    x: 0,
                    y: 8
                )
                .scaleEffect(canUpdateGroup ? 1.0 : 0.95)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: canUpdateGroup)
            }
            .disabled(!canUpdateGroup || isUpdating)
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
                
                Text(L10n.preview)
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
                                gradient: Gradient(colors: gradientColors),
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
                                            .foregroundColor(accentColor)
                                    )
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(groupName.isEmpty ? L10n.groupChat : groupName)
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
    
    private var canUpdateGroup: Bool {
        return selectedMembers.count >= 1
    }
    
    private func setupInitialData() {
        groupName = group.name
        selectedMembers = allOshiList.filter { group.memberIds.contains($0.id) }
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
    
    private func updateGroup() {
        guard canUpdateGroup, !isUpdating else { return }
        
        isUpdating = true
        generateHapticFeedback()
        
        let finalGroupName = groupName.isEmpty ? L10n.groupChat : groupName
        let memberIds = selectedMembers.map { $0.id }
        
        groupChatManager.createOrUpdateGroup(
            groupId: group.id,
            name: finalGroupName,
            memberIds: memberIds
        ) { error in
            DispatchQueue.main.async {
                self.isUpdating = false
                
                if let error = error {
                    print("グループ更新エラー: \(error.localizedDescription)")
                    // Show error alert with modern design
                } else {
                    print("グループ更新成功 - メンバー: \(memberIds)")
                    
                    let updatedGroupInfo = GroupChatInfo(
                        id: self.group.id,
                        name: finalGroupName,
                        memberIds: memberIds,
                        createdAt: self.group.createdAt,
                        lastMessageTime: self.group.lastMessageTime,
                        lastMessage: self.group.lastMessage
                    )
                    
                    self.onUpdate(updatedGroupInfo)
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
    EditGroupChatView(
        group: GroupChatInfo(
            id: "sample-group",
            name: "サンプルグループ",
            memberIds: ["oshi1", "oshi2"],
            createdAt: Date().timeIntervalSince1970,
            lastMessageTime: 0,
            lastMessage: nil
        ),
        allOshiList: [
            Oshi(id: "oshi1", name: "推し1", imageUrl: nil, backgroundImageUrl: nil, memo: nil, createdAt: nil),
            Oshi(id: "oshi2", name: "推し2", imageUrl: nil, backgroundImageUrl: nil, memo: nil, createdAt: nil),
            Oshi(id: "oshi3", name: "推し3", imageUrl: nil, backgroundImageUrl: nil, memo: nil, createdAt: nil)
        ],
        onUpdate: { _ in }
    )
}
