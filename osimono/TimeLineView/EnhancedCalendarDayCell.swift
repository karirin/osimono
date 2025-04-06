//
//  EnhancedCalendarDayCell.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct EnhancedCalendarDayCell: View {
    let date: Date
    @Binding var selectedDate: Date
    let events: [TimelineEvent]
    let dotColors: [Color]
    let brandColor: Color
    let onTap: (Date) -> Void
    
    // Colors
    private let cardBackgroundColor = Color(UIColor.secondarySystemBackground)
    private let textColor = Color(UIColor.label)
    private let secondaryTextColor = Color(UIColor.secondaryLabel)
    
    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }
    
    private var weekday: Int {
        Calendar.current.component(.weekday, from: date)
    }
    
    // Text color based on weekday and selection
    private var dayTextColor: Color {
        if isSameDay(date, selectedDate) {
            return .white
        } else {
            return weekday == 1 ? Color(hex: "EF4444") :
                  (weekday == 7 ? Color(hex: "3B82F6") : textColor)
        }
    }
    
    // Event colors for this day
    private var eventColors: [Color] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        
        return events.filter { event in
            guard let eDate = formatter.date(from: event.time) else { return false }
            return isSameDay(eDate, date)
        }.map { $0.color }
    }
    
    // Event count for this day
    private var eventCount: Int {
        eventColors.count
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Day number with selection indicator
            ZStack {
                if isSameDay(date, selectedDate) {
                    Circle()
                        .fill(brandColor)
                        .frame(width: 32, height: 32)
                        .shadow(color: brandColor.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                
                Text("\(dayNumber)")
                    .font(.system(size: 15, weight: isSameDay(date, selectedDate) ? .semibold : .regular))
                    .foregroundColor(dayTextColor)
            }
            
            // Event indicators with colored dots
            if eventCount > 0 {
                HStack(spacing: 2) {
                    ForEach(0..<min(eventCount, 3), id: \.self) { i in
                        Circle()
                            .fill(eventColors.count > i ? eventColors[i] : dotColors[i % dotColors.count])
                            .frame(width: 4, height: 4)
                    }
                }
            } else {
                Spacer().frame(height: 4)
            }
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSameDay(date, selectedDate) ? brandColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap(date)
        }
    }
    
    private func isSameDay(_ d1: Date, _ d2: Date) -> Bool {
        let cal = Calendar.current
        return cal.component(.year, from: d1) == cal.component(.year, from: d2)
            && cal.component(.month, from: d1) == cal.component(.month, from: d2)
            && cal.component(.day, from: d1) == cal.component(.day, from: d2)
    }
}
