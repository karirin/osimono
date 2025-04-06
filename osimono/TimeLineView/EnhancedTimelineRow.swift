//
//  EnhancedTimelineRow.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct EnhancedTimelineRow: View {
    let event: TimelineEvent
    @Binding var selectedEventID: UUID?
    
    // Colors
    private let cardBackgroundColor = Color(UIColor.secondarySystemBackground)
    
    var formattedTime: String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy/MM/dd HH:mm"
        
        if let date = inputFormatter.date(from: event.time) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "HH:mm"
            return outputFormatter.string(from: date)
        } else {
            return event.time
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Time column
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedTime)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }
            .frame(width: 46)
            
            // Timeline dot and line
            VStack(spacing: 0) {
                Circle()
                    .fill(event.color)
                    .frame(width: 12, height: 12)
                    .shadow(color: event.color.opacity(0.3), radius: 2, x: 0, y: 1)
                
                if selectedEventID == event.id {
                    Rectangle()
                        .fill(event.color.opacity(0.5))
                        .frame(width: 2)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                }
            }
            .frame(height: selectedEventID == event.id ? 200 : 80)
            
            // Event content
            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(UIColor.label))
                
                if selectedEventID == event.id, let imageURL = event.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 160)
//                                .shimmer(true)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure:
                            VStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color.gray.opacity(0.5))
                                Text("画像を読み込めませんでした")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.gray)
                            }
                            .frame(height: 160)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackgroundColor)
                    .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    if selectedEventID == event.id {
                        selectedEventID = nil
                    } else {
                        selectedEventID = event.id
                    }
                }
            }
        }
    }
}
