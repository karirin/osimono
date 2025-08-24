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
            Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                .onTapGesture { isPresented = false }
            
            VStack(spacing: 20) {
                Image(systemName: "gift.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text(NSLocalizedString("reward_obtained", comment: "Reward Obtained!"))
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 8) {
                    Text(NSLocalizedString("thank_you_for_watching", comment: "Thank you for watching the ad"))
                        .foregroundColor(.secondary)
                    
                    Text(NSLocalizedString("to_the_end", comment: "to the end!"))
                        .foregroundColor(.secondary)
                    
                    Text(String(format: NSLocalizedString("messages_added_format", comment: "%d messages"), rewardAmount))
                        .font(.headline)
                    
                    Text(NSLocalizedString("have_been_added", comment: "have been added ✨"))
                        .font(.headline)
                }
                .multilineTextAlignment(.center)
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    isPresented = false
                }) {
                    Text(NSLocalizedString("ok", comment: "OK"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.purple, .pink]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                .padding(.top, 10)
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
