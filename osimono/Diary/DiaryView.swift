//
//  DiaryView.swift
//  osimono
//
//  Created by Apple on 2025/05/04.
//

import SwiftUI
import UIKit
import Firebase
import FirebaseAuth
import FirebaseStorage

struct DiaryView: View {
    @State private var diaryEntries: [DiaryEntry] = []
    @State private var showingNewEntrySheet = false
    @State private var isLoading = true
    @State private var selectedDate: Date = Date()
    @State private var showCalendar = false
    @State private var selectedEntry: DiaryEntry? = nil
    @State private var showFilters = false
    @State private var activeFilters: [DiaryFilter] = []
    @State private var appliedFilters: [DiaryFilter] = []
    let oshiId: String
    
    // Format dates
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.locale = Locale(identifier: "ja_JP")  // 日本のロケールを設定（オプション）
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.customPink.opacity(0.05),   // 情熱的だが控えめ
                        Color.brown.opacity(0.02)         // 革の質感
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                VStack(spacing: 0) {
                    // ヘッダー
                    HStack {
                        Button(action: {
                            generateHapticFeedback()
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                showCalendar.toggle()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(dateFormatter.string(from: selectedDate))
                                    .font(.system(size: 16, weight: .semibold))
                                Image(systemName: showCalendar ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.cardBackground)
                                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                            )
                        }
                        .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // フィルターボタン
                        Button(action: {
                            generateHapticFeedback()
                            withAnimation(.spring()) {
                                showFilters.toggle()
                            }
                        }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.customPink)
                                
                                if !appliedFilters.isEmpty {
                                    Text("\(appliedFilters.count)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 16, height: 16)
                                        .background(Circle().fill(Color.red))
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    
                    // フィルターパネル
                    if showFilters {
                        FilterPanelView(
                            availableTags: getAllTags(),
                            activeFilters: $activeFilters,
                            appliedFilters: $appliedFilters,
                            onClose: {
                                generateHapticFeedback()
                                withAnimation(.spring()) {
                                    showFilters = false
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                    }

                    if showCalendar {
                        DiaryCalendarView(
                            selectedDate: $selectedDate,
                            diaryEntries: diaryEntries,
                            onDateSelected: { date in
                                generateHapticFeedback()
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    showCalendar = false
                                }
                                loadEntriesForDate(date)
                            }
                        )
                        .frame(height: 220)
                        .padding(.top, 38)
                        .zIndex(1)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                    }
                    
                    // 日記エントリー
                    if isLoading {
                        VStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .customPink))
                                .scaleEffect(1.5)
                            Spacer()
                        }
                    } else if filteredEntries.isEmpty {
                        EmptyStateView {
                            generateHapticFeedback()
                            showingNewEntrySheet = true
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                ForEach(filteredEntries) { entry in
                                    DiaryEntryCard(entry: entry)
                                        .onTapGesture {
                                            selectedEntry = entry
                                        }
                                        .transition(.asymmetric(
                                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                                            removal: .opacity.combined(with: .move(edge: .top))
                                        ))
                                }
                            }
                            .padding(20)
                        }
                    }
                }
                
                // フローティングアクションボタン
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            generateHapticFeedback()
                            showingNewEntrySheet = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.customPink, Color.customPink.opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .shadow(color: Color.customPink.opacity(0.3), radius: 15, x: 0, y: 8)
                        }
                        .padding(.trailing, 18)
                        .padding(.bottom, 18)
                    }
                }
            }
            .navigationTitle("推し日記")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadDiaryEntries()
            }
            .onChange(of: selectedDate) { _ in
                loadEntriesForDate(selectedDate)
            }
            .fullScreenCover(isPresented: $showingNewEntrySheet) {
                NewDiaryEntryView(oshiId: oshiId) { newEntry in
                    withAnimation(.spring()) {
                        diaryEntries.append(newEntry)
                        if Calendar.current.isDate(Date(timeIntervalSince1970: newEntry.createdAt),
                                                  inSameDayAs: selectedDate) {
                            loadEntriesForDate(selectedDate)
                        }
                    }
                }
            }
            .fullScreenCover(item: $selectedEntry) { entry in
                DiaryEntryDetailView(entry: entry) { updatedEntry in
                    if let index = diaryEntries.firstIndex(where: { $0.id == updatedEntry.id }) {
                        withAnimation(.spring()) {
                            diaryEntries[index] = updatedEntry
                            loadEntriesForDate(selectedDate)
                        }
                    }
                }
            }
        }
    }
    
    // フィルターを適用したエントリー
    var filteredEntries: [DiaryEntry] {
        var entries = entriesForSelectedDate
        
        for filter in appliedFilters {
            switch filter {
            case .all:
                continue
            case .mood(let mood):
                entries = entries.filter { $0.mood == mood.rawValue }
            case .tag(let tag):
                entries = entries.filter { $0.tags?.contains(tag) ?? false }
            }
        }
        
        return entries
    }
    
    // Helper to get entries for the selected date
    var entriesForSelectedDate: [DiaryEntry] {
        return diaryEntries.filter { entry in
            let entryDate = Date(timeIntervalSince1970: entry.createdAt)
            return Calendar.current.isDate(entryDate, inSameDayAs: selectedDate)
        }.sorted { $0.createdAt > $1.createdAt }
    }
    
    // すべてのタグを取得
    func getAllTags() -> [String] {
        let allTags = diaryEntries.compactMap { $0.tags }
        return Array(Set(allTags.flatMap { $0 })).sorted()
    }
    
    // Load all diary entries
    func loadDiaryEntries() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        isLoading = true
        
        let ref = Database.database().reference().child("diaryEntries").child(userId).child(oshiId)
        
        ref.observeSingleEvent(of: .value) { snapshot in
            var newEntries: [DiaryEntry] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let value = childSnapshot.value as? [String: Any] {
                    
                    let id = childSnapshot.key
                    let oshiId = value["oshiId"] as? String ?? ""
                    let title = value["title"] as? String ?? ""
                    let content = value["content"] as? String ?? ""
                    let mood = value["mood"] as? Int ?? 3
                    let imageUrls = value["imageUrls"] as? [String]
                    let createdAt = value["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970
                    let updatedAt = value["updatedAt"] as? TimeInterval ?? Date().timeIntervalSince1970
                    let tags = value["tags"] as? [String]
                    
                    var entry = DiaryEntry(
                        id: id,
                        oshiId: oshiId,
                        title: title,
                        content: content,
                        mood: mood,
                        imageUrls: imageUrls,
                        tags: tags
                    )
                    
                    entry.createdAt = createdAt
                    entry.updatedAt = updatedAt
                    
                    newEntries.append(entry)
                }
            }
            
            DispatchQueue.main.async {
                self.diaryEntries = newEntries
                self.loadEntriesForDate(self.selectedDate)
                self.isLoading = false
            }
        }
    }
    
    // Load entries for a specific date
    func loadEntriesForDate(_ date: Date) {
        self.selectedDate = date
    }
}

#Preview{
//    DiaryView(oshiId: "")
    TopView()
}
