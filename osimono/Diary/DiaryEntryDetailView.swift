//
//  DiaryEntryDetailView.swift
//  osimono
//
//  Created by Apple on 2025/05/04.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage

struct DiaryEntryDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    let entry: DiaryEntry
    let onUpdate: (DiaryEntry) -> Void
    
    @State private var isEditing = false
    @State private var editedTitle: String
    @State private var editedContent: String
    @State private var editedMood: Int
    @State private var editedTags: [String]
    @State private var showDeleteConfirmation = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP") 
        return formatter
    }()
    
    init(entry: DiaryEntry, onUpdate: @escaping (DiaryEntry) -> Void) {
        self.entry = entry
        self.onUpdate = onUpdate
        
        // Initialize editing state with entry values
        _editedTitle = State(initialValue: entry.title)
        _editedContent = State(initialValue: entry.content)
        _editedMood = State(initialValue: entry.mood)
        _editedTags = State(initialValue: entry.tags ?? [])
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    if isEditing {
                        TextField("タイトル", text: $editedTitle)
                            .font(.title2.bold())
                            .padding(.horizontal)
                    } else {
                        Text(entry.title)
                            .font(.title2.bold())
                            .padding(.horizontal)
                    }
                    
                    // Date and mood
                    HStack {
                        Text(dateFormatter.string(from: Date(timeIntervalSince1970: entry.createdAt)))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        if isEditing {
                            Picker("気分", selection: $editedMood) {
                                ForEach(DiaryMood.allCases, id: \.rawValue) { moodOption in
                                    Text(moodOption.icon).tag(moodOption.rawValue)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 200)
                        } else {
                            Text(DiaryMood(rawValue: entry.mood)?.icon ?? "😐")
                                .font(.title)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Content
                    if isEditing {
                        ZStack(alignment: .topLeading) {
                            if editedContent.isEmpty {
                                Text("内容を入力...")
                                    .foregroundColor(Color(.placeholderText))
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                            
                            TextEditor(text: $editedContent)
                                .padding(4)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                                .frame(minHeight: 200)
                        }
                        .padding(.horizontal)
                    } else {
                        Text(entry.content)
                            .padding(.horizontal)
                    }
                    
                    // Images
                    if let imageUrls = entry.imageUrls, !imageUrls.isEmpty {
                        VStack(alignment: .leading) {
                            Text("写真")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(imageUrls, id: \.self) { urlString in
                                        if let url = URL(string: urlString) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 250, height: 250)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                                default:
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 250, height: 250)
                                                        .overlay(
                                                            Image(systemName: "photo")
                                                                .foregroundColor(.gray)
                                                        )
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical, 10)
                        }
                    }
                    
                    // Tags
                    VStack(alignment: .leading) {
                        Text("タグ")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if isEditing {
                            // Editable tags
                            TagEditorView(tags: $editedTags)
                                .padding(.horizontal)
                        } else if let tags = entry.tags, !tags.isEmpty {
                            // Display tags
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                            .padding(.vertical, 5)
                                            .padding(.horizontal, 10)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(15)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        } else {
                            Text("タグなし")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                        }
                    }
                    
                    // Delete button (only in edit mode)
                    if isEditing {
                        Button(action: {
                            generateHapticFeedback()
                            showDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("日記を削除")
                            }
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("日記詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        generateHapticFeedback()
                        if isEditing {
                            // Discard changes
                            editedTitle = entry.title
                            editedContent = entry.content
                            editedMood = entry.mood
                            editedTags = entry.tags ?? []
                            isEditing = false
                        } else {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        Text(isEditing ? "キャンセル" : "閉じる")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        generateHapticFeedback()
                        if isEditing {
                            // Save changes
                            saveChanges()
                        } else {
                            // Start editing
                            isEditing = true
                        }
                    }) {
                        Text(isEditing ? "保存" : "編集")
                    }
                }
            }
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("この日記を削除しますか？"),
                    message: Text("この操作は取り消せません。"),
                    primaryButton: .destructive(Text("削除")) {
                        generateHapticFeedback()
                        deleteEntry()
                    },
                    secondaryButton: .cancel(Text("キャンセル"))
                )
            }
        }
    }
    
    // Save edited entry
    private func saveChanges() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Create updated entry
        var updatedEntry = entry
        updatedEntry.title = editedTitle
        updatedEntry.content = editedContent
        updatedEntry.mood = editedMood
        updatedEntry.tags = editedTags.isEmpty ? nil : editedTags
        updatedEntry.updatedAt = Date().timeIntervalSince1970
        
        // Update in Firebase
        let dbRef = Database.database().reference().child("diaryEntries").child(userId).child(entry.oshiId).child(entry.id)
        
        var entryDict: [String: Any] = [
            "oshiId": updatedEntry.oshiId,
            "title": updatedEntry.title,
            "content": updatedEntry.content,
            "mood": updatedEntry.mood,
            "createdAt": updatedEntry.createdAt,
            "updatedAt": updatedEntry.updatedAt
        ]
        
        if let imageUrls = updatedEntry.imageUrls {
            entryDict["imageUrls"] = imageUrls
        }
        
        if let tags = updatedEntry.tags {
            entryDict["tags"] = tags
        }
        
        dbRef.updateChildValues(entryDict) { error, _ in
            if error == nil {
                // Call onUpdate callback with updated entry
                onUpdate(updatedEntry)
                isEditing = false
            }
        }
    }
    
    // Delete entry
    private func deleteEntry() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Delete from Firebase
        let dbRef = Database.database().reference().child("diaryEntries").child(userId).child(entry.oshiId).child(entry.id)
        
        dbRef.removeValue { error, _ in
            if error == nil {
                // Close view
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
