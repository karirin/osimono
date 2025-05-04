//
//  ShimmeringViewModifier.swift
//  osimono
//
//  Created by Apple on 2025/05/04.
//

import SwiftUI

extension View {
    func shimmering() -> some View {
        self.modifier(ShimmeringViewModifier())
    }
}

struct ShimmeringViewModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    Color.white
                        .opacity(0.3)
                        .mask(
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.clear, .white.opacity(0.5), .clear]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: geo.size.width * 3)
                                .offset(x: -2 * geo.size.width + (geo.size.width * 3) * phase)
                        )
                }
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}
