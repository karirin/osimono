//
//  Struct.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI

// アップロード画像タイプ
enum UploadImageType: Identifiable {
    case profile
    case background

    var id: String {
        switch self {
        case .profile: return "profile"
        case .background: return "background"
        }
    }
}

// ユーザープロフィール
struct UserProfile: Codable {
    var id: String
    var username: String?
    var favoriteOshi: String?
    var profileImageUrl: String?
    var backgroundImageUrl: String?
    var bio: String?
}

struct ImageTimeLinePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImageTimeLinePicker
        init(_ parent: ImageTimeLinePicker) {
            self.parent = parent
        }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// シェアシート
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// 角丸カスタマイズ拡張
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// カテゴリーボタン
struct CategoryButton: View {
    let category: OshiCategory
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    // 色の定義
    let primaryColor = Color(.systemPink) // 明るいピンク
    let accentColor = Color(.purple) // 紫系
    let backgroundColor = Color(.white) // 明るい背景色
    let cardColor = Color(.black) // カード背景色
    let textColor = Color(.black) // テキスト色
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 16))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.system(size: 14, weight: .medium))
                    
                    Text("\(count)アイテム")
                        .font(.system(size: 12))
                        .opacity(0.7)
                }
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.leading, 4)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .foregroundColor(isSelected ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? primaryColor : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}
