//
//  EmptyStateView 2.swift
//  osimono
//
//  Created by Apple on 2025/05/04.
//

import SwiftUI

struct EmptyStateView: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // アイラストレーション
            ZStack {
                Circle()
                    .fill(Color.customPink.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "book.pages")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(.customPink)
            }
            
            VStack(spacing: 12) {
                Text("まだ日記がありません")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("今日の推し活を記録して、\n特別な思い出を残しましょう")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Button(action: action) {
                Text("新しい日記を書く")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.customPink)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 30)
    }
}
