//
//  EnhancedMonthCalendarView.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct EnhancedMonthCalendarView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var selectedDate: Date
    @Binding var selectedEventID: UUID?
    @State var isFlag: Bool = false
    
    // Colors
    private let dotColors: [Color] = [
        Color(hex: "3B82F6"), // Blue
        Color(hex: "10B981"), // Green
        Color(hex: "F59E0B"), // Amber
        Color(hex: "EF4444"), // Red
    ]
    private let brandColor = Color(hex: "3B82F6") // Blue
    private let cardBackgroundColor = Color(UIColor.secondarySystemBackground)
    private let textColor = Color(UIColor.label)
    private let secondaryTextColor = Color(UIColor.secondaryLabel)
    
    // Date calculations
    private var displayYear: Int {
        Calendar.current.component(.year, from: selectedDate)
    }
    
    private var displayMonth: Int {
        Calendar.current.component(.month, from: selectedDate)
    }
    
    private var firstOfMonth: Date {
        let components = DateComponents(year: displayYear, month: displayMonth, day: 1)
        return Calendar.current.date(from: components) ?? Date()
    }
    
    private var lastOfMonth: Date {
        var comps = DateComponents()
        comps.month = 1
        comps.day = -1
        return Calendar.current.date(byAdding: comps, to: firstOfMonth) ?? Date()
    }
    
    private var daysInMonth: Int {
        Calendar.current.component(.day, from: lastOfMonth)
    }
    
    private var firstWeekday: Int {
        Calendar.current.component(.weekday, from: firstOfMonth) - 1
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern weekday header
            WeekdayHeaderView()
            
            // Modern calendar grid
            calendarGridView
            
            Divider()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
            // Events for selected date
            eventListView
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    handleSwipeGesture(value)
                }
        )
    }
    
    private var calendarGridView: some View {
        let totalCells = firstWeekday + daysInMonth
        let rows = Int(ceil(Double(totalCells) / 7.0))
        
        return VStack(spacing: 12) {
            ForEach(0..<rows, id: \.self) { rowIndex in
                calendarRowView(rowIndex: rowIndex)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func calendarRowView(rowIndex: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { colIndex in
                let cellIndex = rowIndex * 7 + colIndex
                if cellIndex < firstWeekday || cellIndex >= firstWeekday + daysInMonth {
                    Spacer()
                        .frame(maxWidth: .infinity)
                } else {
                    let day = cellIndex - firstWeekday + 1
                    let cellDate = makeDate(year: displayYear, month: displayMonth, day: day)
                    
                    EnhancedCalendarDayCell(
                        date: cellDate,
                        selectedDate: $selectedDate,
                        events: viewModel.events,
                        dotColors: dotColors,
                        brandColor: brandColor,
                        onTap: { tappedDate in
                            withAnimation(.spring(response: 0.3)) {
                                selectedDate = tappedDate
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var eventListView: some View {
        Group {
            if isFlag {
                emptyStateView
            } else {
                eventScrollView
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 10) {
                ForEach(Array(eventsForSelectedDate.enumerated()), id: \.element.id) { index, event in
                }
                Circle()
                    .fill(cardBackgroundColor)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 32))
                            .foregroundColor(brandColor.opacity(0.7))
                    )
                
                Text("タイムラインがありません")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(secondaryTextColor)
                
                Text("この日はまだ登録されていません")
                    .font(.system(size: 14))
                    .foregroundColor(secondaryTextColor.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            Spacer()
            }
        .padding(.top, 30)
    }
    
    private var eventScrollView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(eventsForSelectedDate.enumerated()), id: \.element.id) { index, event in
                    EnhancedTimelineRow(
                        event: event,
                        selectedEventID: $selectedEventID
                    )
                    .padding(.bottom, 8)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .padding(.bottom, 70)
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleSwipeGesture(_ value: DragGesture.Value) {
        if abs(value.translation.width) > abs(value.translation.height) {
            if value.translation.width < 0 {
                // Left swipe: next month
                if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) {
                    withAnimation(.spring(response: 0.4)) {
                        selectedDate = nextMonth
                    }
                }
            } else {
                // Right swipe: previous month
                if let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) {
                    withAnimation(.spring(response: 0.4)) {
                        selectedDate = prevMonth
                    }
                }
            }
        }
    }
    
    // Get events for the selected date
    private var eventsForSelectedDate: [TimelineEvent] {
        print("viewModel.events     :\(viewModel.events)")
        let events = viewModel.events.filter { event in
            guard let date = dateFromString(event.time) else { return false }
            return isSameDay(date, selectedDate)
        }
        
        DispatchQueue.main.async {
            self.isFlag = events.isEmpty
        }
        
        return events.sorted { event1, event2 in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd HH:mm"
            if let date1 = formatter.date(from: event1.time),
               let date2 = formatter.date(from: event2.time) {
                return date1 < date2
            }
            return false
        }
    }
    
    // Helper functions
    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        let comps = DateComponents(year: year, month: month, day: day)
        return Calendar.current.date(from: comps) ?? Date()
    }
    
    private func dateFromString(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.date(from: str)
    }
    
    private func isSameDay(_ d1: Date, _ d2: Date) -> Bool {
        let cal = Calendar.current
        return cal.component(.year, from: d1) == cal.component(.year, from: d2)
            && cal.component(.month, from: d1) == cal.component(.month, from: d2)
            && cal.component(.day, from: d1) == cal.component(.day, from: d2)
    }
}

#Preview {
    TimelineView(oshiId: "CDD84D85-B207-4DDE-B3F0-603461E64AA5")
//    TopView()
}
