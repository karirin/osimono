//
//  EnhancedEditEventView.swift
//  osimono
//
//  Created by Apple on 2025/05/27.
//

import SwiftUI
import Firebase
import FirebaseAuth
import SwiftyCrop

struct EnhancedEditEventView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: TimelineViewModel
    let eventToEdit: TimelineEvent
    @Environment(\.presentationMode) var presentationMode
    
    @State private var eventDate: Date
    @State private var title: String
    @State private var isOshiActivity: Bool
    @State private var selectedImage: UIImage?
    @State private var isShowingImagePicker = false
    @State private var isShowingDeleteAlert = false
    @State private var isSaving = false
    @State private var isDeleting = false
    @FocusState private var isTitleFocused: Bool
    
    // Colors
    private let brandColor = Color(hex: "3B82F6")
    private let backgroundColor = Color(UIColor.systemBackground)
    private let cardBackgroundColor = Color(UIColor.secondarySystemBackground)
    private let textColor = Color(UIColor.label)
    private let secondaryTextColor = Color(UIColor.secondaryLabel)
    
    @State private var selectedImageForCropping: UIImage?
    @State private var croppingImage: UIImage?
    let primaryColor = Color(.systemBlue)
    
    private var cropConfig: SwiftyCropConfiguration {
        var cfg = SwiftyCropConfiguration(
            texts: .init(
                cancelButton: "キャンセル",
                interactionInstructions: "",
                saveButton: "適用"
            )
        )
        return cfg
    }
    
    init(isPresented: Binding<Bool>, viewModel: TimelineViewModel, eventToEdit: TimelineEvent) {
        self._isPresented = isPresented
        self.viewModel = viewModel
        self.eventToEdit = eventToEdit
        
        // 既存のイベントデータで初期化
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        let initialDate = formatter.date(from: eventToEdit.time) ?? Date()
        
        _eventDate = State(initialValue: initialDate)
        _title = State(initialValue: eventToEdit.title)
        _isOshiActivity = State(initialValue: eventToEdit.color == Color(hex: "3B82F6"))
        _selectedImage = State(initialValue: eventToEdit.image)
    }
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            VStack {
                // カスタムナビゲーションバー
                HStack {
                    Button(action: {
                        generateHapticFeedback()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(textColor)
                            .frame(width: 36, height: 36)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .disabled(isSaving || isDeleting)
                    
                    Spacer()
                    
                    Text("タイムライン編集")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(textColor)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        // 削除ボタン
//                        Button(action: {
//                            generateHapticFeedback()
//                            isShowingDeleteAlert = true
//                        }) {
//                            Image(systemName: "trash")
//                                .font(.system(size: 16, weight: .semibold))
//                                .foregroundColor(.red)
//                                .frame(width: 36, height: 36)
//                                .background(Color.red.opacity(0.1))
//                                .clipShape(Circle())
//                        }
//                        .disabled(isSaving || isDeleting)
                        
                        // 保存ボタン
                        Button(action: {
                            generateHapticFeedback()
                            startUpdateProcess()
                        }) {
                            Text("更新")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    Capsule()
                                        .fill(title.isEmpty || isSaving || isDeleting ? Color.gray : brandColor)
                                )
                                .opacity(title.isEmpty || isSaving || isDeleting ? 0.5 : 1.0)
                        }
                        .disabled(title.isEmpty || isSaving || isDeleting)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
                
                // コンテンツ
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 統合された画像セクション
                        imageSection
                            .padding(.top, 16)
                        
                        // タイトル入力
                        titleSection
                        
                        // 日付選択
                        datePickerSection
                        
                        // 活動タイプ切り替え
                        activityToggleSection
                        
                        Button(action: {
                                 generateHapticFeedback()
                                 startUpdateProcess()
                             }) {
                                 ZStack {
                                     Text("更新する")
                                         .fontWeight(.bold)
                                 }
                                 .frame(maxWidth: .infinity)
                                 .foregroundColor(.white)
                                 .padding()
                                 .background(
                                     LinearGradient(
                                         gradient: Gradient(colors: [primaryColor, primaryColor.opacity(0.8)]),
                                         startPoint: .leading,
                                         endPoint: .trailing
                                     )
                                 )
                                 .cornerRadius(15)
                                 .shadow(color: primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)
                             }
                        
                    
                    Button(action: {
                            generateHapticFeedback()
                            isShowingDeleteAlert = true
                        }) {
                            Text("削除する")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.red)
                                .padding()
                                .background(
                                    Color.red.opacity(0.1)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1.5)
                                )
                                .cornerRadius(15)
                        }
                        .disabled(isSaving || isDeleting)
                         }
                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 20)
                    .opacity(isSaving || isDeleting ? 0.5 : 1.0)
                    .disabled(isSaving || isDeleting)
                }
            
            // 保存中・削除中のオーバーレイ
            if isSaving || isDeleting {
                savingOverlay
            }
        }
        .dismissKeyboardOnTap()
        .alert("削除の確認", isPresented: $isShowingDeleteAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                generateHapticFeedback()
                startDeleteProcess()
            }
        } message: {
            Text("このタイムラインを削除しますか？この操作は取り消せません。")
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePickerView { pickedImage in
                self.selectedImageForCropping = pickedImage
            }
        }
        .onChange(of: selectedImageForCropping) { img in
            guard let img else { return }
            croppingImage = img
        }
        .fullScreenCover(item: $croppingImage) { img in
            NavigationView {
                SwiftyCropView(
                    imageToCrop: img,
                    maskShape: .rectangle,
                    configuration: cropConfig
                ) { cropped in
                    if let cropped { selectedImage = cropped }
                    croppingImage = nil
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // 統合された画像セクション
    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("画像")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(textColor)
            
            ZStack {
                // 現在の画像または新しく選択した画像を表示
                if let selectedImage = selectedImage {
                    // 新しく選択した画像
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else if let imageURL = eventToEdit.imageURL, let url = URL(string: imageURL) {
                    // 既存の画像
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 200)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        case .failure:
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 200)
                                .overlay(
                                    Text("画像を読み込めませんでした")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    // 画像がない場合
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardBackgroundColor)
                        .frame(height: 200)
                        .overlay(
                            VStack(spacing: 16) {
                                Image(systemName: "photo")
                                    .font(.system(size: 42))
                                    .foregroundColor(secondaryTextColor)
                                
                                Text("画像を選択")
                                    .font(.system(size: 16))
                                    .foregroundColor(secondaryTextColor)
                            }
                        )
                }
                
                // 画像変更/削除ボタン（画像がある場合のみ表示）
                if selectedImage != nil || eventToEdit.imageURL != nil {
                    VStack {
                        HStack {
                            Spacer()
                            // 削除ボタン
                            Button(action: {
                                generateHapticFeedback()
                                selectedImage = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                            }
                            .padding(12)
                        }
                        
                        Spacer()
                        
                        HStack {
                            Spacer()
                            // 画像変更ボタン
                            Button(action: {
                                generateHapticFeedback()
                                isShowingImagePicker = true
                            }) {
                                Text("画像を変更")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(20)
                                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .padding(12)
                        }
                    }
                } else {
                    // 画像がない場合は全体をタップ可能にする
                    Button(action: {
                        generateHapticFeedback()
                        isShowingImagePicker = true
                    }) {
                        Color.clear
                    }
                }
            }
            .frame(height: 200)
        }
    }
    
    // 保存中・削除中のオーバーレイ
    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text(isSaving ? "更新中..." : "削除中...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.7))
            )
        }
    }

    
    // タイトルセクション
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
    
    // 日付選択セクション
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
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBackgroundColor)
                )
        }
    }
    
    // 活動タイプセクション
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
    
    // MARK: - Helper Functions
    
    // 更新プロセスを開始
    private func startUpdateProcess() {
        isSaving = true
        
        let color: Color = isOshiActivity ? Color(hex: "3B82F6") : .gray
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
        let timeString = dateFormatter.string(from: eventDate)
        
        let updatedEvent = TimelineEvent(
            id: eventToEdit.id, // 既存のIDを保持
            time: timeString,
            title: title,
            color: color,
            image: selectedImage,
            imageURL: selectedImage == nil ? eventToEdit.imageURL : nil, // 新しい画像がない場合は既存のURLを保持
            oshiId: eventToEdit.oshiId
        )
        
        viewModel.updateEvent(event: updatedEvent) { success in
            DispatchQueue.main.async {
                self.presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    // 削除プロセスを開始
    private func startDeleteProcess() {
        isDeleting = true
        
        viewModel.deleteEvent(event: eventToEdit) { success in
            DispatchQueue.main.async {
                self.presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

#Preview {
    TopView()
}
