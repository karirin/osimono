//
//  CalendarView.swift
//  osimono
//
//  Created by Apple on 2025/05/04.
//

import SwiftUI

struct CalendarView: View {
    @Binding var selectedDate: Date
    let diaryEntries: [DiaryEntry]
    let onDateSelected: (Date) -> Void
    
    @State private var currentMonth: Date = Date()
    
    private let calendar = Calendar.current
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()
    
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 10) {
            // Month selector
            HStack {
                Button(action: {
                    generateHapticFeedback()
                    withAnimation {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14))  // フォントサイズを追加
                        .foregroundColor(Color(.systemPink))
                }
                
                Spacer()
                
                Text(monthFormatter.string(from: currentMonth))
                    .font(.subheadline)
                
                Spacer()
                
                Button(action: {
                    generateHapticFeedback()
                    withAnimation {
                        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(.systemPink))
                }
            }
            .padding(.horizontal, 8)
            
            // Day of week headers
            HStack {
                ForEach(getDaysOfWeek(), id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Color(.systemGray))
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(extractDates()) { dateItem in
                    CalendarCell(
                        date: dateItem.date,
                        isSelected: calendar.isDate(selectedDate, inSameDayAs: dateItem.date),
                        isCurrentMonth: dateItem.isCurrentMonth,
                        hasEntries: hasEntriesForDate(dateItem.date)
                    )
                    .onTapGesture {
                        generateHapticFeedback()
                        withAnimation {
                            selectedDate = dateItem.date
                            onDateSelected(dateItem.date)
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    // Get days of week (Sunday to Saturday)
    private func getDaysOfWeek() -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        
        var weekdays: [String] = []
        for index in 0..<7 {
            let date = calendar.date(from: DateComponents(weekday: index + 1))!
            weekdays.append(formatter.string(from: date))
        }
        return weekdays
    }
    
    // Extract dates for the current month view
    private func extractDates() -> [DateItem] {
        var days = [DateItem]()
        
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        let monthEnd = calendar.date(byAdding: .day, value: -1, to: nextMonth)!
        
        // Previous month dates
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        if firstWeekday > 1 {
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: monthStart)!
            let daysInPreviousMonth = calendar.range(of: .day, in: .month, for: previousMonth)!.count
            
            let startDay = daysInPreviousMonth - firstWeekday + 2
            
            for day in startDay...daysInPreviousMonth {
                if let date = calendar.date(byAdding: .day, value: day - daysInPreviousMonth, to: monthStart) {
                    days.append(DateItem(date: date, isCurrentMonth: false))
                }
            }
        }
        
        // Current month dates
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)!.count
        
        for day in 1...daysInMonth {
            if let date = calendar.date(bySetting: .day, value: day, of: monthStart) {
                days.append(DateItem(date: date, isCurrentMonth: true))
            }
        }
        
        // Next month dates
        let lastWeekday = calendar.component(.weekday, from: monthEnd)
        if lastWeekday < 7 {
            for day in 1...(7 - lastWeekday) {
                if let date = calendar.date(byAdding: .day, value: day, to: monthEnd) {
                    days.append(DateItem(date: date, isCurrentMonth: false))
                }
            }
        }
        
        return days
    }
    
    // Check if there are diary entries for a specific date
    private func hasEntriesForDate(_ date: Date) -> Bool {
        return diaryEntries.contains { entry in
            let entryDate = Date(timeIntervalSince1970: entry.createdAt)
            return calendar.isDate(entryDate, inSameDayAs: date)
        }
    }
    
    // Date item struct for calendar
    struct DateItem: Identifiable {
        var id = UUID()
        var date: Date
        var isCurrentMonth: Bool
    }
}

struct CalendarCell: View {
    let date: Date
    let isSelected: Bool
    let isCurrentMonth: Bool
    let hasEntries: Bool
    
    private let calendar = Calendar.current
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 3) {
            Text(dayFormatter.string(from: date))
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundColor(cellTextColor)
            
            if hasEntries {
                Circle()
                    .fill(Color.customPink)
                    .frame(width: 6, height: 6)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(height: 35)
        .padding(5)
        .background(isSelected ? Color.customPink.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.customPink : Color.clear, lineWidth: 2)
        )
    }
    
    var cellTextColor: Color {
        if !isCurrentMonth {
            return Color.gray.opacity(0.4)
        }
        
        if isSelected {
            return Color.customPink
        }
        
        if calendar.isDateInToday(date) {
            return Color.customPink
        }
        
        return Color.primary
    }
}

#Preview{
    CalendarCell(date: Date(), isSelected: true, isCurrentMonth: true, hasEntries: true)
}
