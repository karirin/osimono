//
//  EnhancedWeekTimelineView.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct EnhancedWeekTimelineView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var selectedDate: Date
    @Binding var selectedEventID: UUID?
    @State private var isFlag: Bool = false
    @State private var baseDate: Date
    @State private var hapticTriggered: Bool = false
    
    // Colors
    private let dotColors: [Color] = [
        Color(hex: "3B82F6"), // Blue
        Color(hex: "10B981"), // Green
        Color(hex: "F59E0B"), // Amber
        Color(hex: "EF4444"), // Red
    ]
    private let brandColor = Color(hex: "3B82F6") // Blue
    private let backgroundColor = Color(UIColor.systemBackground)
    private let cardBackgroundColor = Color(UIColor.secondarySystemBackground)
    private let textColor = Color(UIColor.label)
    private let secondaryTextColor = Color(UIColor.secondaryLabel)
    
    init(viewModel: TimelineViewModel, selectedDate: Binding<Date>, selectedEventID: Binding<UUID?>) {
        self.viewModel = viewModel
        self._selectedDate = selectedDate
        self._selectedEventID = selectedEventID
        _baseDate = State(initialValue: selectedDate.wrappedValue)
    }
    
    // Formatters
    private let dayOfWeekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "E"
        return f
    }()
    
    private let dayOfMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "d"
        return f
    }()
    
    // Date calculations
    private func eventCount(for date: Date) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return viewModel.events.filter { event in
            guard let eventDate = formatter.date(from: event.time) else { return false }
            return isSameDay(eventDate, date)
        }.count
    }
    
    private func findNextEventDate(from date: Date, direction: Int) -> Date {
        let calendar = Calendar.current
        for offset in 1...365 {
            if let newDate = calendar.date(byAdding: .day, value: direction * offset, to: date),
               eventCount(for: newDate) > 0 {
                return newDate
            }
        }
        return date
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar day selector with modern design
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(-365...365, id: \.self) { offset in
                            let date = Calendar.current.date(byAdding: .day, value: offset, to: baseDate)!
                            let weekday = dayOfWeekFormatter.string(from: date)
                            let day = dayOfMonthFormatter.string(from: date)
                            let count = eventCount(for: date)
                            let isSelected = isSameDay(date, selectedDate)
                            
                            VStack(spacing: 6) {
                                // Weekday
                                Text(weekday)
                                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                                    .foregroundColor(isSelected ? brandColor : secondaryTextColor)
                                
                                // Day number with elegant selection style
                                ZStack {
                                    if isSelected {
                                        Circle()
                                            .fill(brandColor)
                                            .frame(width: 36, height: 36)
                                    }
                                    
                                    Text(day)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(isSelected ? .white : textColor)
                                }
                                .frame(width: 36, height: 36)
                                
                                // Event indicators with modern dot design
                                if count > 0 {
                                    HStack(spacing: 3) {
                                        ForEach(0..<min(count, 3), id: \.self) { i in
                                            Circle()
                                                .fill(dotColors[i % dotColors.count])
                                                .frame(width: 5, height: 5)
                                        }
                                    }
                                    .frame(height: 6)
                                } else {
                                    Spacer()
                                        .frame(height: 6)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? brandColor.opacity(0.1) : Color.clear)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedDate = date
                                }
                            }
                            .id(offset)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
                .background(cardBackgroundColor.opacity(0.5))
                .onAppear {
                    let offset = Calendar.current.dateComponents([.day], from: baseDate, to: selectedDate).day ?? 0
                    proxy.scrollTo(offset, anchor: .center)
                }
                .onChange(of: selectedDate) { newValue in
                    let offset = Calendar.current.dateComponents([.day], from: baseDate, to: newValue).day ?? 0
                    withAnimation {
                        proxy.scrollTo(offset, anchor: .center)
                    }
                }
            }
            .frame(height: 100)
            // Timeline Events List with modern styling
            if isFlag {
                ForEach(eventsForSelectedDate, id: \.id) { event in}
                // Empty state with elegant design
                VStack(spacing: 20) {
                    Spacer()
                    
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
                    
                    Text("イベントを追加してタイムラインを作成しましょう")
                        .font(.system(size: 14))
                        .foregroundColor(secondaryTextColor.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                }
            } else {
                ScrollView {
                    ZStack {
                        VStack(spacing: 10) {
                            ForEach(Array(eventsForSelectedDate.enumerated()), id: \.element.id) { index, event in
                                EnhancedTimelineRow(
                                    event: event,
                                    selectedEventID: $selectedEventID
                                )
                                .padding(.bottom, 8)
                            }
                        }
                    }.padding(.bottom, 70)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !hapticTriggered {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        hapticTriggered = true
                    }
                }
                .onEnded { value in
                    hapticTriggered = false
                    let threshold: CGFloat = 50
                    if value.translation.width < -threshold {
                        // Left swipe → next day with events
                        let newDate = findNextEventDate(from: selectedDate, direction: 1)
                        withAnimation {
                            selectedDate = newDate
                        }
                    } else if value.translation.width > threshold {
                        // Right swipe → previous day with events
                        let newDate = findNextEventDate(from: selectedDate, direction: -1)
                        withAnimation {
                            selectedDate = newDate
                        }
                    }
                }
        )
    }
    
    // Get events for the selected date
    private var eventsForSelectedDate: [TimelineEvent] {
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

//struct EnhancedWeekTimelineView_Previews: PreviewProvider {
//    static var previews: some View {
//        TimelineView()
//    }
//}
