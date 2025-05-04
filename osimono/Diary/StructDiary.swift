//
//  StructView.swift
//  osimono
//
//  Created by Apple on 2025/05/04.
//

import SwiftUI

enum DiaryFilter: Equatable {
    case all
    case mood(DiaryMood)
    case tag(String)
    
    var displayText: String {
        switch self {
        case .all:
            return "すべて"
        case .mood(let mood):
            return mood.icon
        case .tag(let tag):
            return "#\(tag)"
        }
    }
}

struct ImageDiaryPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onImagePicked: ((UIImage) -> Void)?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // 更新処理は不要
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImageDiaryPicker
        
        init(_ parent: ImageDiaryPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
                // 画像が選択された場合のみコールバックを呼び出す
                parent.onImagePicked?(uiImage)
            }
            
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

extension Color {
    static let customPink = Color(red: 255/255, green: 105/255, blue: 180/255)
    static let backgroundGray = Color(red: 245/255, green: 245/255, blue: 247/255)
    static let cardBackground = Color(red: 255/255, green: 255/255, blue: 255/255)
}

enum DiaryMood: Int, CaseIterable {
    case veryBad = 1
    case bad = 2
    case neutral = 3
    case good = 4
    case veryGood = 5
    
    var icon: String {
        switch self {
        case .veryBad: return "😢"
        case .bad: return "😕"
        case .neutral: return "😐"
        case .good: return "😊"
        case .veryGood: return "🥰"
        }
    }
    
    var color: Color {
        switch self {
        case .veryBad: return .red
        case .bad: return .orange
        case .neutral: return .yellow
        case .good: return .green
        case .veryGood: return .pink
        }
    }
}
