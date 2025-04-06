//
//  MapPinView.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct MapPinView: View {
    var imageName: String
    var isSelected: Bool
    var pinType: PinType
    
    enum PinType {
        case live
        case ad
        case cafe
        case other
        
        var color: Color {
            switch self {
            case .live: return Color(hex: "6366F1") // Indigo
            case .ad: return Color(hex: "EC4899")   // Pink
            case .cafe: return Color(hex: "10B981") // Green
            case .other: return Color(hex: "6366F1") // Default Indigo
            }
        }
        
        var icon: String {
            switch self {
            case .live: return "music.note"
            case .ad: return "megaphone"
            case .cafe: return "cup.and.saucer"
            case .other: return "mappin"
            }
        }
        
        var label: String {
            switch self {
            case .live: return "ライブ"
            case .ad: return "広告"
            case .cafe: return "カフェ"
            case .other: return "その他"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: -8) {
            // Main Pin Circle
            ZStack {
                // White Background Circle
                Circle()
                    .fill(Color.white)
                    .frame(width: isSelected ? 100 : 70, height: isSelected ? 100 : 70)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                // Border Circle with Color
                Circle()
                    .stroke(pinType.color, lineWidth: 3)
                    .frame(width: isSelected ? 100 : 70, height: isSelected ? 100 : 70)
                
                // Image
                ZStack {
                    if let url = URL(string: imageName) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                Image(systemName: pinType.icon)
                                    .font(.system(size: isSelected ? 24 : 18))
                                    .foregroundColor(pinType.color)
                            }
//                            .shimmer(true)
                        }
                        .frame(width: isSelected ? 85 : 55, height: isSelected ? 85 : 55)
                        .clipShape(Circle())
                    } else {
                        ZStack {
                            Circle()
                                .fill(pinType.color.opacity(0.2))
                            Image(systemName: pinType.icon)
                                .font(.system(size: isSelected ? 24 : 18))
                                .foregroundColor(pinType.color)
                        }
                        .frame(width: isSelected ? 85 : 55, height: isSelected ? 85 : 55)
                    }
                }
                
                // Category Badge (Only for selected pins)
                if isSelected {
                    ZStack {
                        Circle()
                            .fill(pinType.color)
                            .frame(width: 30, height: 30)
                        
                        Image(systemName: pinType.icon)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .offset(x: 40, y: -40)
                }
            }
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
            .zIndex(1)
            
            // Triangle Pointer
            Triangle()
                .fill(pinType.color)
                .frame(width: isSelected ? 20 : 30, height: isSelected ? 20 : 20)
                .offset(y: 4)
                .opacity(isSelected ? 1.0 : 0.8)
        }
        .shadow(color: Color.black.opacity(0.2), radius: isSelected ? 8 : 4, x: 0, y: 4)
    }
}
