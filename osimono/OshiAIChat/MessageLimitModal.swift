//
//  MessageLimitModal.swift
//  osimono
//
//  Created by Apple on 2025/05/24.
//

import SwiftUI

struct MessageLimitModal: View {
    @Binding var isPresented: Bool
    let onWatchAd: () -> Void
    let remainingMessages: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { isPresented = false }
            VStack(spacing: 20) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 50)).foregroundColor(.pink)
                Text("本日の会話回数が上限に達しました")
                    .font(.title2).fontWeight(.bold).multilineTextAlignment(.center)
                VStack(spacing: 10) {
                    Text("1日10回まで推しと会話できます").foregroundColor(.gray)
                    Text("動画を視聴すると、さらに10回会話できるようになります！").multilineTextAlignment(.center)
                }
                VStack(spacing: 12) {
                    Button(action: { onWatchAd() }) {
                        HStack {
                            Image(systemName: "play.circle.fill").font(.system(size: 40))
                            Text("動画を見て\n会話を続ける").fontWeight(.semibold).font(.system(size: 20))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient(gradient: Gradient(colors: [.purple, .pink]), startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(25)
                    }
                    Button(action: { isPresented = false }) {
                        Text("また明日話そう").foregroundColor(.gray).padding()
                    }
                }.padding(.horizontal)
            }
            .padding(30)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 40)
        }
    }
}

struct MessageLimitModal_Previews: PreviewProvider {
    static var previews: some View {
        MessageLimitModal(isPresented: .constant(true),
                          onWatchAd: {},
                          remainingMessages: 1)
    }
}
