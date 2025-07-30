//
//  ManageOshiModal.swift
//  osimono
//
//  登録済みの推しを管理するためのモーダル
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseDatabase
import FirebaseStorage

struct ManageOshiModal: View {
    @Binding var isPresented: Bool
    @Binding var oshiList: [Oshi]
    let onOshiDeleted: () -> Void
    
    @State private var selectedOshiForDeletion: Oshi?
    @State private var showDeleteAlert = false
    @State private var isDeletingOshi = false
    
    let primaryColor = Color(.systemPink)
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture {
                    if !isDeletingOshi {
                        isPresented = false
                    }
                }
            
            VStack(spacing: 20) {
                // ヘッダー
                HStack {
                    Text("推しを管理")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                    .disabled(isDeletingOshi)
                }
                .padding(.horizontal)
                
                // 説明文
                VStack(spacing: 8) {
                    Text("新しい推しを登録するには、")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("既存の推しを削除する必要があります")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 推しリスト
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(oshiList, id: \.id) { oshi in
                            OshiRowForManagement(
                                oshi: oshi,
                                onDelete: {
                                    selectedOshiForDeletion = oshi
                                    showDeleteAlert = true
                                }
                            )
                            .disabled(isDeletingOshi)
                            .opacity(isDeletingOshi ? 0.6 : 1.0)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 300)
                
                // 制限情報
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("無料プランでは最大5人まで登録可能")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.1))
                )
                .padding(.horizontal)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 30)
            
            // 削除中のオーバーレイ
            if isDeletingOshi {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("推しを削除中...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                    )
            }
        }
        .alert("推しを削除", isPresented: $showDeleteAlert) {
            Button("削除", role: .destructive) {
                if let oshi = selectedOshiForDeletion {
                    deleteOshi(oshi)
                }
            }
            Button("キャンセル", role: .cancel) {
                selectedOshiForDeletion = nil
            }
        } message: {
            Text("\(selectedOshiForDeletion?.name ?? "")を削除しますか？この操作は元に戻せません。\n関連するチャット履歴やアイテム記録もすべて削除されます。")
        }
    }
    
    private func deleteOshi(_ oshi: Oshi) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isDeletingOshi = true
        
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
        
        // すべての削除処理が完了したら
        dispatchGroup.notify(queue: .main) {
            self.isDeletingOshi = false
            self.selectedOshiForDeletion = nil
            
            if let error = deletionError {
                print("削除処理でエラーが発生しました: \(error.localizedDescription)")
            } else {
                print("推し「\(oshi.name)」を削除しました")
                
                // ローカルの推しリストから削除
                if let index = self.oshiList.firstIndex(where: { $0.id == oshi.id }) {
                    self.oshiList.remove(at: index)
                }
                
                // 削除完了を通知
                self.onOshiDeleted()
                
                // 推しが削除されたらモーダルを閉じる
                if self.oshiList.count < 5 {
                    self.isPresented = false
                }
            }
        }
    }
}

struct OshiRowForManagement: View {
    let oshi: Oshi
    let onDelete: () -> Void
    
    var body: some View {
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
                            defaultProfileImage
                        }
                    }
                } else {
                    defaultProfileImage
                }
            }
            .frame(width: 50, height: 50)
            
            // 推し情報
            VStack(alignment: .leading, spacing: 4) {
                Text(oshi.name)
                    .font(.headline)
                    .fontWeight(.medium)
                
                if let createdAt = oshi.createdAt {
                    Text("登録日: \(formatDate(Date(timeIntervalSince1970: createdAt)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 削除ボタン
            Button(action: onDelete) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var defaultProfileImage: some View {
        Circle()
            .fill(Color.gray.opacity(0.2))
            .overlay(
                Text(String(oshi.name.prefix(1)))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.gray)
            )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

#Preview {
    ManageOshiModal(
        isPresented: .constant(true),
        oshiList: .constant([
            Oshi(id: "1", name: "推し1", imageUrl: nil, backgroundImageUrl: nil, memo: nil, createdAt: Date().timeIntervalSince1970),
            Oshi(id: "2", name: "推し2", imageUrl: nil, backgroundImageUrl: nil, memo: nil, createdAt: Date().timeIntervalSince1970)
        ]),
        onOshiDeleted: {}
    )
}
