//
//  SettingsView.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct SettingsView: View {
    @State private var username: String = "推し活ユーザー"
    @State private var favoriteOshi: String = ""
    @State private var isShowingImagePicker = false
    @State private var isShowingLogoutAlert = false
    @ObservedObject var authManager = AuthManager()
    
    // 色の定義
    let primaryColor = Color(.systemPink) // 明るいピンク
    let accentColor = Color(.purple) // 紫系
    let backgroundColor = Color(.white) // 明るい背景色
    let cardColor = Color(.white) // カード背景色
    let textColor = Color(.black) // テキスト色
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // ヘッダー
                Text("設定")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(primaryColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)
                
                // プロフィール編集カード
                VStack(spacing: 15) {
                    Text("プロフィール編集")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // ユーザー名フィールド
                    VStack(alignment: .leading, spacing: 5) {
                        Text("ユーザー名")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        TextField("推し活ユーザー", text: $username)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }
                    
                    // 推し名フィールド
                    VStack(alignment: .leading, spacing: 5) {
                        Text("推しの名前")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        TextField("例：BTS、TWICE、King & Prince", text: $favoriteOshi)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }
                    
                    // 保存ボタン
                    Button(action: {
                        saveProfile()
                    }) {
                        Text("保存")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(primaryColor)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(cardColor)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
                
                // 一般設定カード
                VStack(spacing: 15) {
                    Text("アプリ設定")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    SettingRow(icon: "bell.fill", title: "通知設定", color: .orange)
                    
                    SettingRow(icon: "lock.fill", title: "プライバシー設定", color: .blue)
                    
                    SettingRow(icon: "square.and.arrow.up", title: "シェア設定", color: .green)
                }
                .padding()
                .background(cardColor)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
                
                // アカウント設定カード
                VStack(spacing: 15) {
                    Text("アカウント")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Button(action: {
                        isShowingLogoutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                                .foregroundColor(.red)
                                .font(.system(size: 20))
                            
                            Text("ログアウト")
                                .foregroundColor(.red)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.system(size: 14))
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding()
                .background(cardColor)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
                
                // バージョン情報
                Text("アプリバージョン: 1.0.0")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
            }
        }
        .background(backgroundColor.ignoresSafeArea())
        .alert(isPresented: $isShowingLogoutAlert) {
            Alert(
                title: Text("ログアウト"),
                message: Text("本当にログアウトしますか？"),
                primaryButton: .destructive(Text("ログアウト")) {
                    logout()
                },
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
    }
    
    // プロフィール保存
    func saveProfile() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let userData = [
            "username": username,
            "favoriteOshi": favoriteOshi
        ]
        
        let ref = Database.database().reference().child("users").child(userId)
        ref.updateChildValues(userData)
    }
    
    // ログアウト
    func logout() {
        do {
            try Auth.auth().signOut()
//            authManager.isLoggedIn = false
        } catch {
            print("ログアウトエラー: \(error.localizedDescription)")
        }
    }
}

// 設定行
struct SettingRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 20))
            
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.system(size: 14))
        }
        .padding(.vertical, 8)
    }
}
