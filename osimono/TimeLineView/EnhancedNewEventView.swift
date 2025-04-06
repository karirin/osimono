//
//  EnhancedNewEventView.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct EnhancedNewEventView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: TimelineViewModel
    
    @State private var eventDate: Date
    @State private var title: String = ""
    @State private var isOshiActivity: Bool = true
    @State private var selectedImage: UIImage?
    @State private var isShowingImagePicker = false
    @State private var isShowingPreview = false
    @FocusState private var isTitleFocused: Bool
    
    // Colors
    private let brandColor = Color(hex: "3B82F6") // Blue
    private let backgroundColor = Color(UIColor.systemBackground)
    private let cardBackgroundColor = Color(UIColor.secondarySystemBackground)
    private let textColor = Color(UIColor.label)
    private let secondaryTextColor = Color(UIColor.secondaryLabel)
    
    init(viewModel: TimelineViewModel, initialDate: Date) {
        self.viewModel = viewModel
        _eventDate = State(initialValue: initialDate)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // カスタムナビゲーションバー
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(textColor)
                                .frame(width: 36, height: 36)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Text("タイムライン作成")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(textColor)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                isShowingPreview.toggle()
                            }
                        }) {
                            Text(isShowingPreview ? "編集" : "プレビュー")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(brandColor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    
                    // Modern scrollable content
                    ScrollView {
                        VStack(spacing: 24) {
                            // Image picker with modern design
                            imagePickerSection
                                .padding(.top, 16)
                            
                            // Title input with character count
                            titleSection
                            
                            // Date picker
                            datePickerSection
                            
                            // Activity toggle
                            activityToggleSection
                            
                            // Preview section
                            if isShowingPreview {
                                eventPreviewSection
                            }
                            
                            Spacer(minLength: 60)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Bottom action bar with save button
                    bottomActionBar
                }
            }
            .navigationBarHidden(true) // ナビゲーションバーを非表示にする
        }
        .sheet(isPresented: $isShowingImagePicker) {
//            ImagePicker(selectedImage: $selectedImage)
        }
        .onAppear {
            isTitleFocused = true
        }
    }
    
    // MARK: - UI Components
    
    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("イベント画像")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(textColor)
            
            Button(action: {
                isShowingImagePicker = true
            }) {
                ZStack {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                VStack {
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            selectedImage = nil
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundColor(.white)
                                                .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                                                .padding(12)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    HStack {
                                        Spacer()
                                        Text("タップして変更")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 16)
                                            .background(Color.black.opacity(0.6))
                                            .cornerRadius(20)
                                            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                                            .padding(12)
                                    }
                                }
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(cardBackgroundColor)
                            .frame(height: 220)
                            .overlay(
                                VStack(spacing: 16) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 42))
                                        .foregroundColor(secondaryTextColor)
                                    
                                    Text("タップして画像を追加")
                                        .font(.system(size: 16))
                                        .foregroundColor(secondaryTextColor)
                                        .multilineTextAlignment(.center)
                                }
                            )
                    }
                }
            }
        }
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("タイトル")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textColor)
                
                Spacer()
                
                Text("\(title.count)/48")
                    .font(.system(size: 14))
                    .foregroundColor(title.count >= 40 ? (title.count > 48 ? .red : .orange) : secondaryTextColor)
            }
            
            TextField("ライブ、イベント名など", text: $title)
                .font(.system(size: 16))
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBackgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(title.isEmpty ? Color.clear : brandColor.opacity(0.3), lineWidth: 1.5)
                        )
                )
                .focused($isTitleFocused)
        }
    }
    
    private var datePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("日付と時間")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(textColor)
            
            DatePicker("", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBackgroundColor)
                )
        }
    }
    
    private var activityToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("活動タイプ")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(textColor)
            
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isOshiActivity ? "推しの活動" : "自分の活動")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textColor)
                        
                        Text(isOshiActivity ? "推し活のイベントとして表示されます" : "あなた自身の活動として表示されます")
                            .font(.system(size: 14))
                            .foregroundColor(secondaryTextColor)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $isOshiActivity)
                        .toggleStyle(SwitchToggleStyle(tint: brandColor))
                        .labelsHidden()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBackgroundColor)
                )
            }
        }
    }
    
    private var eventPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("プレビュー")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(textColor)
            
            VStack(spacing: 16) {
                // Date display
                HStack {
                    Text(formatDate(eventDate))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(textColor)
                    
                    Spacer()
                }
                
                // Timeline preview
                HStack(alignment: .top, spacing: 16) {
                    // Time column
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatTime(eventDate))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                    .frame(width: 46)
                    
                    // Timeline dot and line
                    VStack(spacing: 0) {
                        Circle()
                            .fill(isOshiActivity ? Color.gray : brandColor)
                            .frame(width: 12, height: 12)
                            .shadow(color: (isOshiActivity ? Color.gray : brandColor).opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                    
                    // Event content
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title.isEmpty ? "ライブ、イベント名など" : title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(title.isEmpty ? secondaryTextColor : textColor)
                        
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(cardBackgroundColor)
                            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.tertiarySystemBackground))
            )
        }
    }
    
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                Spacer()
                
                Button(action: {
                    saveEvent()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("タイムラインに追加")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 20)
                        .background(
                            Capsule()
                                .fill(title.isEmpty ? Color.gray : brandColor)
                        )
                        .opacity(title.isEmpty ? 0.5 : 1.0)
                }
                .disabled(title.isEmpty)
                
                Spacer()
            }
            .padding(.vertical, 12)
            .background(backgroundColor)
        }
    }
    
    // MARK: - Helper Functions
    
    private func saveEvent() {
        let color: Color = isOshiActivity ? .gray : Color(hex: "3B82F6")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
        let timeString = dateFormatter.string(from: eventDate)
        
        let newEvent = TimelineEvent(
            id: UUID(),
            time: timeString,
            title: title,
            color: color,
            image: selectedImage,
            imageURL: nil
        )
        
        viewModel.addEvent(event: newEvent)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
