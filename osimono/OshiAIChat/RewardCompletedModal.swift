//
//  RewardCompletedModal.swift
//  osimono
//
//  Created by Apple on 2025/05/25.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct RewardCompletedModal: View {
    @Binding var isPresented: Bool
    let rewardAmount: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).edgesIgnoringSafeArea(.all).onTapGesture { isPresented = false }
            VStack(spacing: 20) {
                Image(systemName: "gift.circle.fill").font(.system(size: 60)).foregroundColor(.green)
                Text("報酬獲得！").font(.title2).fontWeight(.bold)
                VStack(spacing: 8) {
                    Text("広告を最後まで視聴していただき").foregroundColor(.secondary)
                    Text("ありがとうございました！").foregroundColor(.secondary)
                    Text("\(rewardAmount)回分のメッセージが").font(.headline)
                    Text("追加されました ✨").font(.headline)
                }.multilineTextAlignment(.center)
                Button(action: { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); isPresented = false }) {
                    Text("OK")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient(gradient: Gradient(colors: [.purple, .pink]), startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(12)
                }.padding(.top, 10)
            }
            .padding(30)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(40)
        }
    }
}

#Preview {
    RewardCompletedModal(isPresented: .constant(true), rewardAmount: 20)
}
