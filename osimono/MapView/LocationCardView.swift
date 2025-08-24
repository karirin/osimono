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
    @EnvironmentObject private var viewModel: LocationViewModel
    @State private var userRating: Int = 0
    @State private var showRatingModal: Bool = false
    var oshiId: String
    var onEditTapped: (() -> Void)? // Edit button tap callback
    
    var distanceText: String {
        if let userLoc = userLocation {
            let eventLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)
            let distance = eventLoc.distance(from: userLoc)
            if distance >= 1000 {
                return String(format: NSLocalizedString("km_away", comment: "Distance in kilometers"), distance / 1000)
            } else {
                return String(format: NSLocalizedString("m_away", comment: "Distance in meters"), distance)
            }
        } else {
            return NSLocalizedString("distance_unknown", comment: "Distance unknown")
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
                HStack{
                    Text(localizedPinTypeLabel(for: pinType))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(pinType.color.opacity(2.0))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(pinType.color.opacity(0.125))
                        .background(Color.white)
                        .cornerRadius(10)
                        .padding(8)
                    Spacer()
                    // Edit button (only shown when selected)
                    if isSelected {
                        Button(action: {
                            generateHapticFeedback()
                            onEditTapped?()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 30, height: 30)
                                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                                
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                                    .rotationEffect(.degrees(90))
                            }
                        }
                        .accessibilityLabel(NSLocalizedString("edit", comment: "Edit"))
                        .offset(x: -6, y: 0)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            
            // Info section
            VStack(alignment: .leading, spacing: 4) {
                Text(location.title)
                    .foregroundColor(.black)
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
            // Load user's existing rating
            if let locationId = location.id {
                viewModel.getUserRating(for: locationId, oshiId: oshiId) { rating in
                    if let rating = rating {
                        userRating = rating
                    }
                }
            }
        }
    }
    
    // Get localized pin type label
    private func localizedPinTypeLabel(for pinType: MapPinView.PinType) -> String {
        switch pinType {
        case .live:
            return NSLocalizedString("live_venue", comment: "Live Venue")
        case .cafe:
            return NSLocalizedString("cafe_restaurant", comment: "Cafe・Restaurant")
        case .shop:
            return NSLocalizedString("goods_shop", comment: "Goods Shop")
        case .photo:
            return NSLocalizedString("photo_spot", comment: "Photo Spot")
        case .sacred:
            return NSLocalizedString("sacred_place", comment: "Pilgrimage")
        case .other:
            return NSLocalizedString("other", comment: "Other")
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
            Text(String(format: NSLocalizedString("rate_location_title", comment: "Rate location"), location.title))
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
                    Text(NSLocalizedString("cancel", comment: "Cancel"))
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
                    Text(NSLocalizedString("rate_button", comment: "Rate"))
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
        case 0:
            return NSLocalizedString("tap_to_rate", comment: "Tap to rate")
        case 1:
            return NSLocalizedString("rating_poor", comment: "Poor")
        case 2:
            return NSLocalizedString("rating_fair", comment: "Fair")
        case 3:
            return NSLocalizedString("rating_good", comment: "Good")
        case 4:
            return NSLocalizedString("rating_very_good", comment: "Very Good")
        case 5:
            return NSLocalizedString("rating_excellent", comment: "Excellent oshi spot!")
        default:
            return ""
        }
    }
}

#Preview {
    // EventLocationの実際の初期化方法に合わせて調整してください
    // 例1: 基本的な初期化
    let sampleLocation = EventLocation(
        id: "sample-location-1",
        title: "推しカフェ",
        latitude: 35.6762,
        longitude: 139.6503,
        imageURL: "https://example.com/sample-image.jpg", category: "test",
        ratingSum: 42
    )
    
    // 例2: もしEventLocationが異なる初期化方法を持つ場合
    // let sampleLocation = EventLocation()
    // sampleLocation.id = "sample-location-1"
    // sampleLocation.title = "推しカフェ"
    // などの設定...
    
    // MapPinView.PinTypeの実際の値に合わせて調整してください
    // 例: .restaurant, .shop, .event, .other など
    let samplePinType = MapPinView.PinType.cafe
    
//    VStack(spacing: 20) {
//        // 選択されていない状態
//        LocationCardView(
//            location: sampleLocation,
//            isSelected: false,
//            pinType: samplePinType,
//            oshiId: "sample-oshi-id"
//        )
//        
//        // 選択されている状態
//        LocationCardView(
//            location: sampleLocation,
//            isSelected: true,
//            pinType: samplePinType,
//            oshiId: "sample-oshi-id"
//        )
//    }
//    .padding()
//    .background(Color(.systemGroupedBackground))
    TopView()
}
