//
//  MapPinView.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth
import Shimmer

struct MapPinView: View {
    var imageName: String
    var isSelected: Bool
    var pinType: PinType
    
    // Add a cache key for AsyncImage
    @State private var imageLoadState: ImageLoadState = .loading
    
    enum ImageLoadState {
        case loading
        case success
        case failure
    }
    
    enum PinType {
        case live // ライブ会場
        case cafe // カフェ・飲食店
        case shop // グッズショップ
        case photo // 撮影スポット
        case sacred // 聖地
        case other // その他
        
        var color: Color {
            switch self {
            case .live: return Color(hex: "6366F1")     // インディゴ/青紫
            case .sacred: return Color(hex: "EF4444") // バイオレット/紫
            case .cafe: return Color(hex: "10B981")     // エメラルド/緑
            case .shop: return Color(hex: "F59E0B")     // アンバー/オレンジ
            case .photo: return Color(hex: "EC4899")    // ピンク
            case .other: return Color(hex: "6B7280")    // グレー
            }
        }
        
        var icon: String {
            switch self {
            case .live: return "music.note"
            case .cafe: return "cup.and.saucer"
            case .shop: return "bag"
            case .photo: return "camera"
            case .sacred: return "mappin"
            case .other: return "mappin"
            }
        }
        
        var label: String {
            switch self {
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
                
                // Image with improved loading
                ZStack {
                    if !imageName.isEmpty, let url = URL(string: imageName) {
                        CachedAsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                // Loading state
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                    Image(systemName: pinType.icon)
                                        .font(.system(size: isSelected ? 24 : 18))
                                        .foregroundColor(pinType.color)
                                }
                                .shimmering(active: true)
                                .accessibilityLabel(NSLocalizedString("loading", comment: "Loading..."))
                            case .success(let image):
                                // Success state
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .transition(.opacity)
                                    .accessibilityLabel(pinType.label)
                            case .failure:
                                // Failure state
                                ZStack {
                                    Circle()
                                        .fill(pinType.color.opacity(0.2))
                                    Image(systemName: pinType.icon)
                                        .font(.system(size: isSelected ? 24 : 18))
                                        .foregroundColor(pinType.color)
                                }
                                .accessibilityLabel(pinType.label)
                            @unknown default:
                                // Unknown state
                                ZStack {
                                    Circle()
                                        .fill(pinType.color.opacity(0.2))
                                    Image(systemName: pinType.icon)
                                        .font(.system(size: isSelected ? 24 : 18))
                                        .foregroundColor(pinType.color)
                                }
                                .accessibilityLabel(pinType.label)
                            }
                        }
                        .frame(width: isSelected ? 85 : 55, height: isSelected ? 85 : 55)
                        .clipShape(Circle())
                    } else {
                        // No image URL provided
                        ZStack {
                            Circle()
                                .fill(pinType.color.opacity(0.2))
                            Image(systemName: pinType.icon)
                                .font(.system(size: isSelected ? 24 : 18))
                                .foregroundColor(pinType.color)
                        }
                        .frame(width: isSelected ? 85 : 55, height: isSelected ? 85 : 55)
                        .accessibilityLabel(pinType.label)
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
                    .accessibilityLabel(pinType.label)
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
        .zIndex(isSelected ? 10 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pinType.label)
        .accessibilityHint(isSelected ?
                           NSLocalizedString("selected_pin_hint", comment: "Selected pin") :
                           NSLocalizedString("unselected_pin_hint", comment: "Tap to select"))
    }
}

struct CachedAsyncImage<Content>: View where Content: View {
    private let url: URL
    private let scale: CGFloat
    private let content: (AsyncImagePhase) -> Content
    
    init(
        url: URL,
        scale: CGFloat = 1.0,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.scale = scale
        self.content = content
    }
    
    var body: some View {
        if #available(iOS 15.0, *) {
            // Use AsyncImage for iOS 15+ with cache policy
            AsyncImage(
                url: url,
                scale: scale,
                content: content
            )
            .id(url.absoluteString) // Important: Keep stable ID for the image
        } else {
            // Fallback for older iOS versions (if needed)
            AsyncImageFallback(
                url: url,
                scale: scale,
                content: content
            )
        }
    }
}

struct AsyncImageFallback<Content>: View where Content: View {
    private let url: URL
    private let scale: CGFloat
    private let content: (AsyncImagePhase) -> Content
    @State private var phase: AsyncImagePhase = .empty
    
    init(
        url: URL,
        scale: CGFloat = 1.0,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.scale = scale
        self.content = content
    }
    
    var body: some View {
        content(phase)
            .onAppear {
                // Load the image when the view appears
                loadImage()
            }
            .onChange(of: url) { _ in
                // Reload when URL changes
                phase = .empty
                loadImage()
            }
    }
    
    private func loadImage() {
        // Simple image loader
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    phase = .success(Image(uiImage: uiImage))
                }
            } else {
                DispatchQueue.main.async {
                    phase = .failure(error ?? URLError(.badServerResponse))
                }
            }
        }.resume()
    }
}
