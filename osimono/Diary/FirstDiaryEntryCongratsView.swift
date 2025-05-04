//
//  FirstDiaryEntryCongratsView.swift
//  osimono
//
//  Created by Apple on 2025/05/04.
//

import SwiftUI

struct FirstDiaryEntryCongratsView: View {
    @Binding var isShowing: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation {
                        isShowing = false
                    }
                }
            
            VStack(spacing: 20) {
                Text("🎉 おめでとう！ 🎉")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("初めての推し日記を記録しました！")
                    .font(.headline)
                
                Text("推しとの思い出をこれからも記録していきましょう。日記は後から見返すことができます。")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    withAnimation {
                        isShowing = false
                    }
                }) {
                    Text("OK")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color(.systemPink))
                        .cornerRadius(8)
                }
                .padding(.top, 10)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
            .padding(30)
        }
    }
}
