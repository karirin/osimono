//
//  Struct.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Foundation

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
    var selectedOshiId: String?
}

struct NumberTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.keyboardType = .numberPad
        textField.inputAccessoryView = context.coordinator.toolbar
        textField.delegate = context.coordinator
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        var toolbar: UIToolbar
        
        init(text: Binding<String>) {
            _text = text
            toolbar = UIToolbar()
            super.init() // ここで super.init() を呼び出す
            toolbar.sizeToFit()
            let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let doneButton = UIBarButtonItem(title: "完了", style: .done, target: self, action: #selector(doneTapped))
            toolbar.items = [flexSpace, doneButton]
        }
        
        @objc func doneTapped() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            self.text = textField.text ?? ""
        }
    }
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
//            parent.presentationMode.wrappedValue.dismiss()
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

// KeyboardDismissExtensionの追加
struct KeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
    }
}

extension View {
    func dismissKeyboardOnTap() -> some View {
        self.modifier(KeyboardDismissModifier())
    }
}

extension LocalizedStringKey {
    // Helper for easier localization
    static func localized(_ key: String) -> LocalizedStringKey {
        return LocalizedStringKey(key)
    }
}

extension String {
    func localized(comment: String = "") -> String {
        return NSLocalizedString(self, comment: comment)
    }
}

struct L10n {
    // Profile Section
    static let profileTitle = NSLocalizedString("profile_title", comment: "Profile section title")
    static let selectOshi = NSLocalizedString("select_oshi", comment: "Select oshi button")
    static let pleaseSelectOshi = NSLocalizedString("please_select_oshi", comment: "Please select oshi message")
    static let searchText = NSLocalizedString("searchText", comment: "Search Text")
    
    static let addOshiPost = NSLocalizedString("add_oshi_post", comment: "Add Oshi Post")
    static let postType = NSLocalizedString("post_type", comment: "Post Type")
    // Navigation
    static let edit = NSLocalizedString("edit", comment: "Edit button")
    static let save = NSLocalizedString("save", comment: "Save button")
    static let cancel = NSLocalizedString("cancel", comment: "Cancel button")
    static let back = NSLocalizedString("back", comment: "Back button")
    static let delete = NSLocalizedString("delete", comment: "Delete button")
    static let confirm = NSLocalizedString("confirm", comment: "Confirm button")
    static let close = NSLocalizedString("close", comment: "Close button")
    
    // Item Types
    static let goods = NSLocalizedString("goods", comment: "Goods type")
    static let pilgrimage = NSLocalizedString("pilgrimage", comment: "Pilgrimage type")
    static let liveRecord = NSLocalizedString("live_record", comment: "Live record type")
    static let snsPost = NSLocalizedString("sns_post", comment: "SNS post type")
    static let other = NSLocalizedString("other", comment: "Other type")
    static let all = NSLocalizedString("all", comment: "All types")
    
    // Form Fields
    static let title = NSLocalizedString("title", comment: "Title field")
    static let category = NSLocalizedString("category", comment: "Category field")
    static let price = NSLocalizedString("price", comment: "Price field")
    static let eventName = NSLocalizedString("event_name", comment: "Event name field")
    static let location = NSLocalizedString("location", comment: "Location field")
    static let tags = NSLocalizedString("tags", comment: "Tags field")
    static let addNewTag = NSLocalizedString("add_new_tag", comment: "Add new tag")
    static let favoriteRating = NSLocalizedString("favorite_rating", comment: "Favorite rating")
    static let memo = NSLocalizedString("memo", comment: "Memo field")
    
    // Date Labels
    static let purchaseDate = NSLocalizedString("purchase_date", comment: "Purchase date")
    static let visitDate = NSLocalizedString("visit_date", comment: "Visit date")
    static let eventDate = NSLocalizedString("event_date", comment: "Event date")
    static let postDate = NSLocalizedString("post_date", comment: "Post date")
    static let recordDate = NSLocalizedString("record_date", comment: "Record date")
    
    // Placeholders
    static let titlePlaceholderGoods = NSLocalizedString("title_placeholder_goods", comment: "Goods title placeholder")
    static let titlePlaceholderPilgrimage = NSLocalizedString("title_placeholder_pilgrimage", comment: "Pilgrimage title placeholder")
    static let titlePlaceholderLive = NSLocalizedString("title_placeholder_live", comment: "Live title placeholder")
    static let titlePlaceholderSns = NSLocalizedString("title_placeholder_sns", comment: "SNS title placeholder")
    static let titlePlaceholderOther = NSLocalizedString("title_placeholder_other", comment: "Other title placeholder")
    static let pricePlaceholder = NSLocalizedString("price_placeholder", comment: "Price placeholder")
    static let eventNamePlaceholder = NSLocalizedString("event_name_placeholder", comment: "Event name placeholder")
    static let locationPlaceholder = NSLocalizedString("location_placeholder", comment: "Location placeholder")
    static let memoPlaceholder = NSLocalizedString("memo_placeholder", comment: "Memo placeholder")
    
    // Messages
    static let noRecords = NSLocalizedString("no_records", comment: "No records message")
    static let addItemsMessage = NSLocalizedString("add_items_message", comment: "Add items instruction message")
    static let addItem = NSLocalizedString("add_item", comment: "Add item button")
    static let postItem = NSLocalizedString("post_item", comment: "Post item button")
    static let saving = NSLocalizedString("saving", comment: "Saving message")
    static let loading = NSLocalizedString("loading", comment: "Loading message")
    
    // Alerts
    static let notification = NSLocalizedString("notification", comment: "Notification title")
    static let deleteConfirmationTitle = NSLocalizedString("delete_confirmation_title", comment: "Delete confirmation title")
    static let deleteConfirmationMessage = NSLocalizedString("delete_confirmation_message", comment: "Delete confirmation message")
    static let ok = NSLocalizedString("ok", comment: "OK button")
    
    // Categories
    static let cdDvd = NSLocalizedString("cd_dvd", comment: "CD/DVD category")
    static let magazine = NSLocalizedString("magazine", comment: "Magazine category")
    static let photoBook = NSLocalizedString("photo_book", comment: "Photo book category")
    static let acrylicStand = NSLocalizedString("acrylic_stand", comment: "Acrylic stand category")
    static let plushie = NSLocalizedString("plushie", comment: "Plushie category")
    static let tShirt = NSLocalizedString("t_shirt", comment: "T-shirt category")
    static let towel = NSLocalizedString("towel", comment: "Towel category")
    
    // Sorting
    static let sortNewest = NSLocalizedString("sort_newest", comment: "Sort newest first")
    static let sortOldest = NSLocalizedString("sort_oldest", comment: "Sort oldest first")
    static let sortPriceHigh = NSLocalizedString("sort_price_high", comment: "Sort price high to low")
    static let sortPriceLow = NSLocalizedString("sort_price_low", comment: "Sort price low to high")
    static let sortFavorite = NSLocalizedString("sort_favorite", comment: "Sort by favorite")
    
    // Registration
    static let registerOshiFirst = NSLocalizedString("register_oshi_first", comment: "Register oshi first title")
    static let registerOshiMessage = NSLocalizedString("register_oshi_message", comment: "Register oshi first message")
    static let registerOshiButton = NSLocalizedString("register_oshi_button", comment: "Register oshi button")
    
    // Image
    static let image = NSLocalizedString("image", comment: "Image field")
    static let tapToSelectImage = NSLocalizedString("tap_to_select_image", comment: "Tap to select image")
    static let changeImage = NSLocalizedString("change_image", comment: "Change image")
    
    // Location
    static let currentLocation = NSLocalizedString("current_location", comment: "Current location")
    
    // Apology Modal
    static let apologyTitle = NSLocalizedString("apology_title", comment: "Apology title")
    static let apologyMessage1 = NSLocalizedString("apology_message_1", comment: "Apology message 1")
    static let apologyMessage2 = NSLocalizedString("apology_message_2", comment: "Apology message 2")
    static let apologyMessage3 = NSLocalizedString("apology_message_3", comment: "Apology message 3")
    static let apologyMessage4 = NSLocalizedString("apology_message_4", comment: "Apology message 4")
    static let apologyMessage5 = NSLocalizedString("apology_message_5", comment: "Apology message 5")
    
    // Helper functions for dynamic content
    static func titlePlaceholder(for itemType: String) -> String {
        switch itemType {
        case "グッズ", "goods":
            return titlePlaceholderGoods
        case "聖地巡礼", "pilgrimage":
            return titlePlaceholderPilgrimage
        case "ライブ記録", "live_record":
            return titlePlaceholderLive
        case "SNS投稿", "sns_post":
            return titlePlaceholderSns
        case "その他", "other":
            return titlePlaceholderOther
        default:
            return NSLocalizedString("title", comment: "Title")
        }
    }
    
    static func dateLabel(for itemType: String) -> String {
        switch itemType {
        case "グッズ", "goods":
            return purchaseDate
        case "聖地巡礼", "pilgrimage":
            return visitDate
        case "ライブ記録", "live_record":
            return eventDate
        case "SNS投稿", "sns_post":
            return postDate
        case "その他", "other":
            return recordDate
        default:
            return NSLocalizedString("date", comment: "Date")
        }
    }
    
    static func memoLabel(for itemType: String) -> String {
        switch itemType {
        case "グッズ", "goods":
            return memo
        case "聖地巡礼", "pilgrimage", "ライブ記録", "live_record":
            return NSLocalizedString("memories_episodes", comment: "Memories & Episodes")
        case "SNS投稿", "sns_post":
            return memo
        case "その他", "other":
            return NSLocalizedString("details_memo", comment: "Details memo")
        default:
            return memo
        }
    }
}

func getCurrentLanguage() -> String {
    return Locale.current.languageCode ?? "en"
}

// Helper function to check if current language is Japanese
func isJapanese() -> Bool {
    return getCurrentLanguage() == "ja"
}
