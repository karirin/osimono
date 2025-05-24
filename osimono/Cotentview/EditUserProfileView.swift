//
//  Untitled.swift
//  osimono
//
//  Created by Apple on 2025/04/07.
//

import SwiftUI
import FirebaseAuth
import FirebaseDatabase

struct EditUserProfileView: View {
    @Binding var userProfile: UserProfile
    @Environment(\.presentationMode) var presentationMode
    @State private var username: String
    @State private var favoriteOshi: String
    @State private var isLoading = false
    
    // テーマカラー
    let primaryColor = Color(.systemPink)
    
    init(userProfile: Binding<UserProfile>) {
        self._userProfile = userProfile
        self._username = State(initialValue: userProfile.wrappedValue.username ?? "")
        self._favoriteOshi = State(initialValue: userProfile.wrappedValue.favoriteOshi ?? "")
    }
    
    var body: some View {
        Form {
            Section(header: Text("プロフィール情報")) {
                TextField("ユーザー名", text: $username)
                    .padding(.vertical, 8)
                
                TextField("推しの名前", text: $favoriteOshi)
                    .padding(.vertical, 8)
            }
            
            Section {
                Button(action: saveProfile) {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("保存")
                                .fontWeight(.bold)
                        }
                        Spacer()
                    }
                }
                .disabled(isLoading)
                .padding(.vertical, 4)
                .foregroundColor(.white)
                .background(primaryColor)
                .cornerRadius(8)
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("プロフィール編集")
        .navigationBarItems(
            leading: Button("キャンセル") {
                generateHapticFeedback()
                presentationMode.wrappedValue.dismiss()
            }
        )
    }
    
    func saveProfile() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isLoading = true
        
        let updatedProfileData: [String: Any] = [
            "username": username,
            "favoriteOshi": favoriteOshi
        ]
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.updateChildValues(updatedProfileData) { error, _ in
            DispatchQueue.main.async {
                isLoading = false
                generateHapticFeedback()
                if error == nil {
                    // 成功したら、親ビューのuserProfileを更新
                    userProfile.username = username
                    userProfile.favoriteOshi = favoriteOshi
                    
                    // ビューを閉じる
                    presentationMode.wrappedValue.dismiss()
                    
                    // 触覚フィードバックを生成
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                } else {
                    print("プロフィール更新エラー: \(error?.localizedDescription ?? "不明なエラー")")
                }
            }
        }
    }
}
