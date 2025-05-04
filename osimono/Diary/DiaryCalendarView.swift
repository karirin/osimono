//
//  DiaryCalendarView.swift
//  osimono
//
//  Created by Apple on 2025/05/04.
//

import SwiftUI

struct DiaryCalendarView: View {
    @Binding var selectedDate: Date
    let diaryEntries: [DiaryEntry]
    let onDateSelected: (Date) -> Void
    
    var body: some View {
        CalendarView(selectedDate: $selectedDate,
                     diaryEntries: diaryEntries,
                     onDateSelected: onDateSelected)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 20)
    }
}
