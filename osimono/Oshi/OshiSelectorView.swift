//
//  OshiSelectorView.swift
//  osimono
//
//  削除機能付きの共通推しセレクターコンポーネント
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseDatabase
import FirebaseStorage

struct OshiSelectorView: View {
    @Binding var isPresented: Bool
    @Binding var oshiList: [Oshi]
    let selectedOshi: Oshi?
    let onOshiSelected: (Oshi) -> Void
    let onAddOshi: () -> Void
    let onOshiDeleted: () -> Void
    
    @State private var showDeleteAlert = false
    @State private var oshiToDelete: Oshi?
    @State private var isDeletingOshi = false
    @State private var isEditMode = false
    
    let primaryColor = Color(.systemPink)
    
    @State private var showOshiLimitModal = false
    @StateObject private var subscriptionManager = SubscriptionManager()
    
    var body: some View {
        ZStack {
            // 半透明の背景
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    if !isDeletingOshi {
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    }
                }
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    HStack {
                        Text(isEditMode ? L10n.deleteOshiMode : L10n.changeOshi)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        // 編集ボタン（推しが2つ以上ある場合のみ表示）
                        if oshiList.count > 1 {
                            Button(action: {
                                generateHapticFeedback()
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    isEditMode.toggle()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: isEditMode ? "checkmark.circle.fill" : "pencil.circle.fill")
                                        .font(.system(size: 16))
                                    Text(isEditMode ? L10n.complete : L10n.edit)
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(isEditMode ? .green : .blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.2))
                                        .overlay(
                                            Capsule()
                                                .stroke(isEditMode ? Color.green : Color.blue, lineWidth: 1)
                                        )
                                )
                            }
                            .scaleEffect(isEditMode ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: isEditMode)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            generateHapticFeedback()
                            withAnimation(.spring()) {
                                isPresented = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    // 編集モード時の説明テキスト
                    if isEditMode {
                        HStack {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.yellow)
                            Text(L10n.deleteInstructions)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                                )
                        )
                        .transition(.slide.combined(with: .opacity))
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                ScrollView {
                    // 推しリスト - グリッドレイアウト
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                        // 新規追加ボタン
                        Button(action: {
                            generateHapticFeedback()
                            onAddOshi()
                            isPresented = false
                            
                            if !subscriptionManager.isSubscribed &&
                               !OshiLimitManager.shared.canAddNewOshi(currentOshiCount: oshiList.count, isSubscribed: false) {
                                showOshiLimitModal = true
                                return
                            }
                        }) {
                            VStack {
                                ZStack {
                                    Circle()
                                        .fill(primaryColor.opacity(0.2))
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: "plus")
                                        .font(.system(size: 30))
                                        .foregroundColor(primaryColor)
                                }
                                
                                Text(L10n.addNew)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                        }
                        .disabled(isDeletingOshi)
                        
                        // 推しリスト
                        ForEach(oshiList) { oshi in
                            ZStack {
                                // 推し選択ボタン
                                Button(action: {
                                    if !isEditMode && !isDeletingOshi {
                                        generateHapticFeedback()
                                        onOshiSelected(oshi)
                                        withAnimation(.spring()) {
                                            isPresented = false
                                        }
                                    }
                                }) {
                                    VStack {
                                        ZStack {
                                            // プロフィール画像またはプレースホルダー
                                            if let imageUrl = oshi.imageUrl, let url = URL(string: imageUrl) {
                                                AsyncImage(url: url) { phase in
                                                    switch phase {
                                                    case .success(let image):
                                                        image
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(width: 80, height: 80)
                                                            .clipShape(Circle())
                                                            .overlay(
                                                                Circle()
                                                                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                                            )
                                                    default:
                                                        defaultProfileImage(for: oshi)
                                                    }
                                                }
                                            } else {
                                                defaultProfileImage(for: oshi)
                                            }
                                            
                                            // 選択インジケーター
                                            if let selected = selectedOshi, oshi.id == selected.id {
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            gradient: Gradient(colors: [primaryColor, Color.purple]),
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 4
                                                    )
                                                    .frame(width: 88, height: 88)
                                                    .overlay(
                                                        // 選択済みバッジ
                                                        VStack {
                                                            Spacer()
                                                            HStack {
                                                                Spacer()
                                                                Image(systemName: "checkmark.circle.fill")
                                                                    .font(.system(size: 20))
                                                                    .foregroundColor(.white)
                                                                    .background(
                                                                        Circle()
                                                                            .fill(primaryColor)
                                                                            .frame(width: 24, height: 24)
                                                                    )
                                                                    .offset(x: 8, y: 8)
                                                            }
                                                        }
                                                    )
                                            }
                                            
                                            // 削除中のオーバーレイ
                                            if isDeletingOshi && oshiToDelete?.id == oshi.id {
                                                Circle()
                                                    .fill(Color.black.opacity(0.7))
                                                    .frame(width: 80, height: 80)
                                                    .overlay(
                                                        VStack(spacing: 4) {
                                                            ProgressView()
                                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                                .scaleEffect(0.8)
                                                            Text(L10n.deletingOshi)
                                                                .font(.system(size: 10))
                                                                .foregroundColor(.white)
                                                        }
                                                    )
                                            }
                                            
                                            // 編集モード時の暗くするオーバーレイ
                                            if isEditMode && !isDeletingOshi {
                                                Circle()
                                                    .fill(Color.black.opacity(0.3))
                                                    .frame(width: 80, height: 80)
                                            }
                                        }
                                        
                                        Text(oshi.name)
                                            .font(.subheadline)
                                            .fontWeight(selectedOshi?.id == oshi.id ? .semibold : .medium)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .opacity(isEditMode ? 0.7 : 1.0)
                                    }
                                }
                                .disabled(isEditMode || isDeletingOshi)
                                .scaleEffect(isEditMode ? 0.9 : 1.0)
                                .animation(.easeInOut(duration: 0.3), value: isEditMode)
                                
                                // 編集モード時の削除ボタン（改良版）
                                if isEditMode && !isDeletingOshi {
                                    Button(action: {
                                        generateHapticFeedback()
                                        oshiToDelete = oshi
                                        showDeleteAlert = true
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 28, height: 28)
                                                .shadow(color: .red.opacity(0.4), radius: 4, x: 0, y: 2)
                                            
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2)
                                                .frame(width: 28, height: 28)
                                            
                                            Image(systemName: "minus")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .offset(x: 30, y: -30)
                                    .scaleEffect(1.2)
                                    .transition(.scale.combined(with: .opacity))
                                    .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.1), value: isEditMode)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .opacity(isDeletingOshi ? 0.6 : 1.0)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(1))
            )
            .padding()
            
            // 削除中のオーバーレイ（改良版）
            if isDeletingOshi {
                ZStack {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        // アニメーション付きのローディングアイコン
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 4)
                                .frame(width: 60, height: 60)
                            
                            Circle()
                                .trim(from: 0, to: 0.8)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [primaryColor, Color.purple]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .frame(width: 60, height: 60)
                                .rotationEffect(.degrees(isDeletingOshi ? 360 : 0))
                                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isDeletingOshi)
                        }
                        
                        VStack(spacing: 8) {
                            Text(L10n.deletingOshi)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if let deletingOshi = oshiToDelete {
                                Text(L10n.deleteOshiAndAllData(deletingOshi.name))
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [primaryColor.opacity(0.5), Color.purple.opacity(0.5)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .padding(.horizontal, 40)
                }
                .transition(.opacity.combined(with: .scale))
            }
            
            if showOshiLimitModal {
                OshiLimitModal(
                    isPresented: $showOshiLimitModal,
                    currentOshiCount: oshiList.count,
                    onUpgrade: {
                        showOshiLimitModal = false
                        // サブスクリプション画面を表示する処理
                        // 親ビューで処理するか、ここで直接表示
                    }
                )
                .zIndex(1001)
            }
        }
        .alert(L10n.deleteOshiTitle, isPresented: $showDeleteAlert) {
            Button(L10n.delete, role: .destructive) {
                if let oshi = oshiToDelete {
                    deleteOshi(oshi)
                }
            }
            Button(L10n.cancel, role: .cancel) {
                oshiToDelete = nil
            }
        } message: {
            Text(L10n.deleteOshiAllDataMessage(oshiToDelete?.name ?? ""))
        }
    }
    
    // デフォルトプロフィール画像（改良版）
    private func defaultProfileImage(for oshi: Oshi) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.gray.opacity(0.4),
                        Color.gray.opacity(0.2)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 80, height: 80)
            .overlay(
                Text(String(oshi.name.prefix(1)))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
            )
    }
    
    // 推し削除処理
    private func deleteOshi(_ oshi: Oshi) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // 最後の推しを削除しようとした場合の確認
        if oshiList.count <= 1 {
            // エラーアラートまたは警告を表示
            return
        }
        
        isDeletingOshi = true
        oshiToDelete = oshi
        
        let dispatchGroup = DispatchGroup()
        var deletionError: Error? = nil
        
        // 1. 推しデータを削除
        dispatchGroup.enter()
        let oshiRef = Database.database().reference().child("oshis").child(userId).child(oshi.id)
        oshiRef.removeValue { error, _ in
            if let error = error {
                deletionError = error
                print("推しデータ削除エラー: \(error.localizedDescription)")
            }
            dispatchGroup.leave()
        }
        
        // 2. チャット履歴を削除
        dispatchGroup.enter()
        let chatRef = Database.database().reference().child("oshiChats").child(userId).child(oshi.id)
        chatRef.removeValue { error, _ in
            if let error = error {
                deletionError = error
                print("チャット履歴削除エラー: \(error.localizedDescription)")
            }
            dispatchGroup.leave()
        }
        
        // 3. アイテム記録を削除
        dispatchGroup.enter()
        let itemsRef = Database.database().reference().child("oshiItems").child(userId).child(oshi.id)
        itemsRef.removeValue { error, _ in
            if let error = error {
                deletionError = error
                print("アイテム記録削除エラー: \(error.localizedDescription)")
            }
            dispatchGroup.leave()
        }
        
        // 4. ストレージの画像を削除
        dispatchGroup.enter()
        let storageRef = Storage.storage().reference().child("oshis").child(userId).child(oshi.id)
        storageRef.delete { error in
            // 画像が存在しない場合のエラーは無視
            if let error = error, (error as NSError).code != StorageErrorCode.objectNotFound.rawValue {
                print("ストレージ削除エラー: \(error.localizedDescription)")
            }
            dispatchGroup.leave()
        }
        
        // 5. 最後に読んだタイムスタンプを削除
        dispatchGroup.enter()
        let userRef = Database.database().reference().child("users").child(userId)
        userRef.child("lastReadTimestamps").child(oshi.id).removeValue { error, _ in
            if let error = error {
                print("タイムスタンプ削除エラー: \(error.localizedDescription)")
            }
            dispatchGroup.leave()
        }
        
        // 6. 選択中の推しIDを更新（削除する推しが選択中の場合）
        dispatchGroup.enter()
        userRef.child("selectedOshiId").observeSingleEvent(of: .value) { snapshot in
            if let selectedOshiId = snapshot.value as? String, selectedOshiId == oshi.id {
                // 削除する推しが選択中の場合、他の推しに変更
                let remainingOshis = oshiList.filter { $0.id != oshi.id }
                let newSelectedId = remainingOshis.first?.id ?? "default"
                
                userRef.updateChildValues(["selectedOshiId": newSelectedId]) { error, _ in
                    if let error = error {
                        print("選択中推しID更新エラー: \(error.localizedDescription)")
                    }
                    dispatchGroup.leave()
                }
            } else {
                dispatchGroup.leave()
            }
        }
        
        // すべての削除処理が完了したら
        dispatchGroup.notify(queue: .main) {
            self.isDeletingOshi = false
            self.oshiToDelete = nil
            
            if let error = deletionError {
                print("削除処理でエラーが発生しました: \(error.localizedDescription)")
            } else {
                print("推し「\(oshi.name)」を削除しました")
                
                // ローカルの推しリストから削除
                if let index = self.oshiList.firstIndex(where: { $0.id == oshi.id }) {
                    self.oshiList.remove(at: index)
                }
                
                // 編集モードを終了
                withAnimation(.spring()) {
                    self.isEditMode = false
                }
                
                // 削除完了を通知
                self.onOshiDeleted()
            }
        }
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isPresented = true
        @State private var oshiList: [Oshi] = [
            Oshi(id: "1", name: "推し1", imageUrl: nil, backgroundImageUrl: nil, memo: nil, createdAt: Date().timeIntervalSince1970),
            Oshi(id: "2", name: "推し2", imageUrl: nil, backgroundImageUrl: nil, memo: nil, createdAt: Date().timeIntervalSince1970)
        ]
        
        var body: some View {
            ZStack {
                Color.blue.ignoresSafeArea()
                
                if isPresented {
                    OshiSelectorView(
                        isPresented: $isPresented,
                        oshiList: $oshiList,
                        selectedOshi: oshiList.first,
                        onOshiSelected: { oshi in
                            print("選択: \(oshi.name)")
                        },
                        onAddOshi: {
                            print("新規追加")
                        },
                        onOshiDeleted: {
                            print("削除完了")
                        }
                    )
                }
            }
        }
    }
    
    return PreviewWrapper()
}
