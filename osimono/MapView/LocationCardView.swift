//
//  LocationCardView.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth
import MapKit

struct LocationCardView: View {
    var location: EventLocation
    var isSelected: Bool
    var pinType: MapPinView.PinType
    var userLocation: CLLocation?
    @ObservedObject private var viewModel = LocationViewModel()
    @State private var userRating: Int = 0
    @State private var showRatingModal: Bool = false
    var oshiId: String
    
    var distanceText: String {
        if let userLoc = userLocation {
            let eventLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)
            let distance = eventLoc.distance(from: userLoc)
            if distance >= 1000 {
                return String(format: "%.1f km", distance / 1000)
            } else {
                return String(format: "%.0f m", distance)
            }
        } else {
            return "--"
        }
    }
    
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
                            .shimmering(active: true)
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
                        .shimmering(active: true)
                }
                
                // Category badge
                Text(pinType.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(pinType.color.opacity(2.0))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(pinType.color.opacity(0.125))
                    .background(Color.white)
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
                    
                    Text(distanceText)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    // Rating display
                    Button(action: {
//                        generateHapticFeedback()
//                        showRatingModal = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(Color(hex: "EC4899"))
                                .font(.system(size: 12))
                            
                            Text("\(location.ratingSum)")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
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
        .sheet(isPresented: $showRatingModal) {
            RatingModalView(
                location: location,
                userRating: $userRating,
                onRate: { rating in
                    if let locationId = location.id {
                        // 既存の評価(userRating)も渡す必要があります
                        viewModel.updateRating(for: locationId, newRating: rating, oldRating: userRating, oshiId: oshiId)
                    }
                    showRatingModal = false
                },
                onCancel: {
                    showRatingModal = false
                }
            )
        }
        .onAppear {
            // ユーザーの既存評価をロード
            if let locationId = location.id {
                viewModel.getUserRating(for: locationId, oshiId: oshiId) { rating in
                    if let rating = rating {
                        userRating = rating
                    }
                }
            }
            print("location     :\(location)")
        }
    }
}

// Rating Modal View
struct RatingModalView: View {
    var location: EventLocation
    @Binding var userRating: Int
    var onRate: (Int) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("「\(location.title)」を評価")
                .font(.system(size: 18, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.top, 20)
            
            Divider()
            
            VStack(spacing: 10) {
                StarRatingView(rating: $userRating, size: 40)
                    .padding(.vertical, 10)
                
                Text(ratingDescriptionText)
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            .padding()
            
            Divider()
            
            HStack(spacing: 20) {
                Button(action: onCancel) {
                    Text("キャンセル")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
                
                Button(action: {
                    generateHapticFeedback()
                    onRate(userRating)
                }) {
                    Text("評価する")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(userRating > 0 ? Color(hex: "EC4899") : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(userRating == 0)
            }
            .padding(.bottom, 20)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .padding()
    }
    
    var ratingDescriptionText: String {
        switch userRating {
        case 0: return "タップして評価してください"
        case 1: return "イマイチ"
        case 2: return "まあまあ"
        case 3: return "普通"
        case 4: return "良い"
        case 5: return "最高の推しスポット！"
        default: return ""
        }
    }
}
