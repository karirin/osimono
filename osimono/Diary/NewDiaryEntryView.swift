//
//  NewDiaryEntryView.swift
//  osimono
//
//  Created by Apple on 2025/05/04.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import SwiftyCrop

struct NewDiaryEntryView: View {
    @Environment(\.presentationMode) var presentationMode
    let oshiId: String
    let onSave: (DiaryEntry) -> Void
    
    @State private var title = ""
    @State private var content = ""
    @State private var mood: Int = 3
    @State private var selectedTags: [String] = []
    @State private var isPrivate = false
    @State private var isShowingImagePicker = false
    @State private var images: [UIImage] = []
    @State private var imageUploadProgress = 0.0
    @State private var isUploading = false
    @State private var tagText = ""
    @State private var suggestedTags = ["ライブ", "握手会", "CD購入", "グッズ", "SNS更新", "イベント"]
    @State private var selectedImageForCropping: UIImage?
    @State private var croppingImage: UIImage?
    @State private var selectedImage: UIImage?
    
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

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                    HStack {
                        Button(action: {
                            generateHapticFeedback()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Text("日記登録")
                            .font(.system(size: 18, weight: .bold))
                        
                        Spacer()
                        
                        Button(action: {
                            generateHapticFeedback()
                            saveEntry()
                        }) {
                            Text("保存")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    Capsule()
                                        .fill(Color.customPink)
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            ScrollView {
                    VStack(spacing: 24) {
//                        // タイトル入力
                        VStack(alignment: .leading, spacing: 8) {
                            Text("タイトル")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            TextField("今日の推し活", text: $title)
                                .font(.system(size: 20, weight: .medium))
                                .padding()
                                .background(Color.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        }
//
//                        // コンテンツ入力
                        VStack(alignment: .leading, spacing: 8) {
                            Text("内容")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            ZStack(alignment: .topLeading) {
                                if content.isEmpty {
                                    Text("推しとの思い出や感想を記録しよう...")
                                        .foregroundColor(Color(.placeholderText))
                                        .padding(16)
                                        .padding(.top, 4)
                                }
                                
                                TextEditor(text: $content)
                                    .font(.system(size: 16))
                                    .frame(minHeight: 120)
                                    .padding(12)
                                    .background(Color.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                            }
                        }
//
//                        // 気分選択
                        VStack(alignment: .leading, spacing: 8) {
                            Text("気分")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            HStack {
                                ForEach(DiaryMood.allCases, id: \.rawValue) { moodOption in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            mood = moodOption.rawValue
                                        }
                                        generateHapticFeedback()
                                    }) {
                                        VStack(spacing: 8) {
                                            Text(moodOption.icon)
                                                .font(.system(size: 32))
                                            
                                            if mood == moodOption.rawValue {
                                                Circle()
                                                    .fill(moodOption.color)
                                                    .frame(width: 8, height: 8)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(mood == moodOption.rawValue ? moodOption.color.opacity(0.1) : Color.cardBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    }
                                }
                            }
                        }
//
//                        // 写真セクション
                        VStack(alignment: .leading, spacing: 8) {
                            Text("写真")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            // 写真ギャラリー
                            if !images.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(0..<images.count, id: \.self) { index in
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: images[index])
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 120, height: 120)
                                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                                
                                                Button(action: {
                                                    generateHapticFeedback()
                                                    images.remove(at: index)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 20))
                                                        .foregroundColor(.white)
                                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                                }
                                                .padding(6)
                                            }
                                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                        }
                                        
                                        // 追加ボタン
                                        Button(action: {
                                            generateHapticFeedback()
                                            isShowingImagePicker = true
                                        }) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(Color.gray.opacity(0.1))
                                                    .frame(width: 120, height: 120)
                                                
                                                Image(systemName: "plus")
                                                    .font(.system(size: 24, weight: .medium))
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                }
                            } else {
                                Button(action: {
                                    generateHapticFeedback()
                                    isShowingImagePicker = true
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 24))
                                        Text("写真を追加")
                                            .font(.system(size: 17))
                                    }
                                    .foregroundColor(.customPink)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.customPink.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            }
                        }
//
//                        // タグ管理
                        VStack(alignment: .leading, spacing: 8) {
                            Text("タグ")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            TagInputView(selectedTags: $selectedTags, suggestedTags: suggestedTags)
                        }
                    }
                    .padding(.horizontal, 20)
//
//                    // 保存ボタン
                    Button(action: saveEntry) {
                        Text("保存")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.customPink)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(20)
                }
            }
            .sheet(isPresented: $isShowingImagePicker) {
                ImageDiaryPicker(image: .constant(nil)) { pickedImage in
                    // 直接追加せずクロップへ
                    selectedImageForCropping = pickedImage
                }
            }
            .onChange(of: selectedImageForCropping) { img in
                guard let img else { return }
                croppingImage = img          // シートを開くトリガ
            }
//            .fullScreenCover(item: $croppingImage) { img in
//                NavigationView {
//                    SwiftyCropView(
//                        imageToCrop: img,
//                        maskShape: .square,        // ← マスク形状
//                        configuration: cropConfig  // ← 上で作った設定
//                    ) { cropped in
//                        if let cropped { selectedImage = cropped }
//                        croppingImage = nil
//                    }
//                }
//                .navigationBarHidden(true)        // 画面上部の「キャンセル」を消す
//            }
            .fullScreenCover(item: $croppingImage) { img in
                NavigationView {
                    SwiftyCropView(
                        imageToCrop: img,
                        maskShape: .square,        // ← マスク形状
                        configuration: cropConfig  // ← 上で作った設定
                    ) { cropped in
                        if let cropped {
                            images.append(cropped)  // クロップ後に追加
                        }
                        croppingImage = nil
                    }
                    .navigationBarHidden(true)
                }
            }
        }
    }
    
    // Add a tag to the selected tags
    private func addTag() {
        let newTag = tagText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newTag.isEmpty && !selectedTags.contains(newTag) {
            selectedTags.append(newTag)
            tagText = ""
        }
    }
    
    // Save the diary entry
    private func saveEntry() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        if images.isEmpty {
            // No images to upload, save entry directly
            saveDiaryEntryToFirebase(imageUrls: nil)
        } else {
            // Upload images first
            isUploading = true
            uploadImages { imageUrls in
                saveDiaryEntryToFirebase(imageUrls: imageUrls)
            }
        }
    }
    
    // Upload images to Firebase Storage
    private func uploadImages(completion: @escaping ([String]) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let imageGroup = DispatchGroup()
        var imageUrls: [String] = []
        
        // Total number of images for progress calculation
        let totalImages = Double(images.count)
        var completedUploads = 0.0
        
        for image in images {
            imageGroup.enter()
            
            let imageId = UUID().uuidString
            let storageRef = Storage.storage().reference().child("diary_images/\(userId)/\(oshiId)/\(imageId).jpg")
            
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                imageGroup.leave()
                continue
            }
            
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            storageRef.putData(imageData, metadata: metadata) { _, error in
                if let error = error {
                    print("画像アップロードエラー: \(error.localizedDescription)")
                    imageGroup.leave()
                } else {
                    storageRef.downloadURL { url, error in
                        if let url = url {
                            imageUrls.append(url.absoluteString)
                        }
                        
                        completedUploads += 1
                        DispatchQueue.main.async {
                            imageUploadProgress = completedUploads / totalImages
                        }
                        
                        imageGroup.leave()
                    }
                }
            }
        }
        
        imageGroup.notify(queue: .main) {
            isUploading = false
            completion(imageUrls)
        }
    }
    
    // Save the diary entry to Firebase Realtime Database
    private func saveDiaryEntryToFirebase(imageUrls: [String]?) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let entryRef = Database.database().reference().child("diaryEntries").child(userId).child(oshiId).childByAutoId()
        
        let newEntry = DiaryEntry(
            id: entryRef.key ?? UUID().uuidString,
            oshiId: oshiId,
            title: title,
            content: content,
            mood: mood,
            imageUrls: imageUrls,
            tags: selectedTags.isEmpty ? nil : selectedTags
        )
        
        // Convert to dictionary
        var entryDict: [String: Any] = [
            "oshiId": newEntry.oshiId,
            "title": newEntry.title,
            "content": newEntry.content,
            "mood": newEntry.mood,
            "createdAt": newEntry.createdAt,
            "updatedAt": newEntry.updatedAt
        ]
        
        if let imageUrls = newEntry.imageUrls {
            entryDict["imageUrls"] = imageUrls
        }
        
        if let tags = newEntry.tags {
            entryDict["tags"] = tags
        }
        
        // Save to Firebase
        entryRef.setValue(entryDict) { error, _ in
            if let error = error {
                print("日記保存エラー: \(error.localizedDescription)")
            } else {
                // Call the onSave callback with the new entry
                onSave(newEntry)
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    // Generate haptic feedback
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
