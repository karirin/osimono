//
//  LocationCardView.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct LocationCardView: View {
    var location: EventLocation
    var isSelected: Bool
    var pinType: MapPinView.PinType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image section
            ZStack(alignment: .topTrailing) {
                if let imageURL = location.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: isSelected ? 100 : 80)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(pinType.color.opacity(0.3))
                            .overlay(
                                Image(systemName: pinType.icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(pinType.color)
                            )
                            .frame(height: isSelected ? 100 : 80)
//                            .shimmer(true)
                    }
                } else {
                    Rectangle()
                        .fill(pinType.color.opacity(0.3))
                        .overlay(
                            Image(systemName: pinType.icon)
                                .font(.system(size: 24))
                                .foregroundColor(pinType.color)
                        )
                        .frame(height: isSelected ? 100 : 80)
                }
                
                // Category badge
                Text(pinType.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(pinType.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(pinType.color.opacity(0.15))
                    .cornerRadius(10)
                    .padding(8)
            }
            
            // Info section
            VStack(alignment: .leading, spacing: 4) {
                Text(location.title)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(pinType.color)
                        .font(.system(size: 12))
                    
                    // Simulate distance (would need actual calculation)
                    Text("約100m")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    // Like count or other metric
                    Image(systemName: "heart.fill")
                        .foregroundColor(Color(hex: "EC4899"))
                        .font(.system(size: 12))
                    
                    Text("10")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .padding(10)
        }
        .frame(width: isSelected ? 220 : 180)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(isSelected ? 0.15 : 0.1), radius: isSelected ? 8 : 4, x: 0, y: isSelected ? 4 : 2)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}
