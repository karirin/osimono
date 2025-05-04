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
            .padding(.horizontal, 12)  // 20 → 12に変更
            .padding(.vertical, 10)    // 16 → 10に変更
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))  // 24 → 16に変更
            .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 8)  // radiaを小さく
            .padding(.horizontal, 16)  // 20 → 16に変更
    }
}
