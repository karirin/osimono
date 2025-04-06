//
//  Untitled.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth

// User Profile View
struct UserProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                // User avatar and info
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Color(hex: "6366F1"))
                    
                    Text("ユーザー名")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("推し活中：10カ所訪問済み")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                // Stats
                HStack(spacing: 30) {
                    VStack {
                        Text("10")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("スポット")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    VStack {
                        Text("5")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("チェックイン")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    VStack {
                        Text("3")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("投稿")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 20)
                
                Divider()
                
                // Menu options
                List {
                    Button(action: {}) {
                        Label("保存したスポット", systemImage: "bookmark.fill")
                    }
                    
                    Button(action: {}) {
                        Label("投稿履歴", systemImage: "photo.on.rectangle")
                    }
                    
                    Button(action: {}) {
                        Label("設定", systemImage: "gear")
                    }
                    
                    Button(action: {}) {
                        Label("ヘルプ", systemImage: "questionmark.circle")
                    }
                    
                    // Logout button with warning color
                    Button(action: {}) {
                        Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("プロフィール")
            .navigationBarItems(
                trailing: Button("閉じる") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}
