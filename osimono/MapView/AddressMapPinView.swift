//
//  AddressMapPinView.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct AddressMapPinView: View {
    var image: UIImage?
    var isSelected: Bool

    var body: some View {
        VStack(spacing: -20) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: isSmallDevice() ? 80 : 100, height: isSmallDevice() ? 80 : 100)
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 5
                    )
                    .frame(width: isSmallDevice() ? 80 : 100, height: isSmallDevice() ? 80 : 100)
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: isSmallDevice() ? 65 : 85, height: isSmallDevice() ? 65 : 85)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .frame(width: isSmallDevice() ? 65 : 85, height: isSmallDevice() ? 65 : 85)
//                        .shimmer(true)
                        .clipShape(Circle())
                }
            }
            .zIndex(1)
            Triangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: isSelected ? 10 : 60, height: isSelected ? 10 : 40)
        }
    }
}
