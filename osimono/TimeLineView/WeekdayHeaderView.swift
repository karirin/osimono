//
//  WeekdayHeaderView.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct WeekdayHeaderView: View {
    // 曜日に応じた色を返す関数
    func headerColor(for wday: String) -> Color {
        if wday == "日" {
            return Color(hex: "EF4444")
        } else if wday == "土" {
            return Color(hex: "3B82F6")
        } else {
            return Color(UIColor.secondaryLabel)
        }
    }
    
    var body: some View {
        HStack {
            ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { wday in
                Text(wday)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(headerColor(for: wday))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
    }
}
