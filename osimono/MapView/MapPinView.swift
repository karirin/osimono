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
        case live // ライブ会場
        case location // ロケ地
        case cafe // カフェ・飲食店
        case shop // グッズショップ
        case photo // 撮影スポット
        case sacred // 聖地
        case other // その他
        
        var color: Color {
            switch self {
            case .live: return Color(hex: "6366F1")     // インディゴ/青紫
            case .location: return Color(hex: "8B5CF6") // バイオレット/紫
            case .cafe: return Color(hex: "10B981")     // エメラルド/緑
            case .shop: return Color(hex: "F59E0B")     // アンバー/オレンジ
            case .photo: return Color(hex: "EC4899")    // ピンク
            case .sacred: return Color(hex: "EF4444")   // レッド/赤
            case .other: return Color(hex: "6B7280")    // グレー
            }
        }
        
        var icon: String {
            switch self {
            case .live: return "music.note"
            case .location: return "film"
            case .cafe: return "cup.and.saucer"
            case .shop: return "bag"
            case .photo: return "camera"
            case .sacred: return "star"
            case .other: return "mappin"
            }
        }
        
        var label: String {
            switch self {
            case .live: return "ライブ会場"
            case .location: return "ロケ地"
            case .cafe: return "カフェ・飲食店"
            case .shop: return "グッズショップ"
            case .photo: return "撮影スポット"
            case .sacred: return "聖地"
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
        .zIndex(isSelected ? 10 : 1)
    }
}
