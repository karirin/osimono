//
//  Struct.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth
import MapKit

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // 下辺を頂点に、上辺を底辺にする
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))   // 三角形の頂点を下に
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY)) // 左上
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)) // 右上
        path.closeSubpath()
        return path
    }
}

struct MapAnnotationItem: Identifiable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
}

// Shimmer Effect
struct ShimmerModifier: ViewModifier {
    var isActive: Bool
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        if isActive {
            content
                .overlay(
                    GeometryReader { geometry in
                        ZStack {
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .clear,
                                    .white.opacity(0.5),
                                    .clear
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: geometry.size.width * 2)
                            .offset(x: -geometry.size.width + (phase * (geometry.size.width * 3)))
                        }
                        .mask(content)
                    }
                )
                .onAppear {
                    withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        self.phase = 1
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    func shimmer(_ active: Bool) -> some View {
        self.modifier(ShimmerModifier(isActive: active))
    }
}

func isSmallDevice() -> Bool {
    return UIScreen.main.bounds.height < 700
}
