//
//  StarRatingView.swift
//  osimono
//
//  Created by Apple on 2025/04/12.
//

import SwiftUI

struct StarRatingView: View {
    @Binding var rating: Int
    var maxRating: Int = 5
    var size: CGFloat = 24
    var fillColor: Color = Color(hex: "EC4899")
    var emptyColor: Color = Color.gray.opacity(0.3)
    
    // Add state for animation
    @State private var animatingHeartIndex: Int? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Spacer()
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: star <= rating ? "heart.fill" : "heart")
                    .font(.system(size: size))
                    .foregroundColor(star <= rating ? fillColor : emptyColor)
                    .scaleEffect(animatingHeartIndex == star ? 1.5 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animatingHeartIndex)
                    .onTapGesture {
                        generateHapticFeedback()
                        // Haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        // Trigger animation
                        withAnimation {
                            animatingHeartIndex = star
                        }
                        
                        // Reset the animating index after animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            animatingHeartIndex = nil
                        }
                        
                        // Allow toggling off if tapping the current rating
                        if rating == star {
                            rating = 0
                        } else {
                            rating = star
                        }
                    }
            }
            Spacer()
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StarRatingView(rating: .constant(3))
        StarRatingView(rating: .constant(5), size: 32)
        StarRatingView(rating: .constant(0), size: 20)
    }
    .padding()
}
