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
                    
                    Text(L10n.itemCount(count))
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
    
    static let oshiSelection = NSLocalizedString("oshiSelection", comment: "Oshi Selection")
    static let username = NSLocalizedString("username", comment: "User Name")
    static let favoriteOshi = NSLocalizedString("favoriteOshi", comment: "Favorite Oshi")
    
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
    
    static let yesterdayLabel = NSLocalizedString("yesterday", comment: "Yesterday label")
    static let groupChatListTitle = NSLocalizedString("group_chat_list_title", comment: "Group Chat List Title")
    static let update = NSLocalizedString("update", comment: "Update")
    
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
    
    static let userNickname = NSLocalizedString("user_nickname", comment: "User nickname")
    static let profileInfo = NSLocalizedString("profile_info", comment: "Profile information")
    static let profileEdit = NSLocalizedString("profile_edit", comment: "Profile edit")
    static let register = NSLocalizedString("register", comment: "Register")
    static let oshiFanUser = NSLocalizedString("oshi_fan_user", comment: "Oshi fan user")
    static let selectYourOshi = NSLocalizedString("select_your_oshi", comment: "Select your oshi")
    static let addNew = NSLocalizedString("add_new", comment: "Add new")
    static let addOshiItem = NSLocalizedString("add_oshi_item", comment: "Add oshi item")
    static let unknownError = NSLocalizedString("unknown_error", comment: "Unknown error")
    
    // Additional Item and Categories
    static let untitled = NSLocalizedString("untitled", comment: "Untitled")
    static let noName = NSLocalizedString("no_name", comment: "No name")
    static let purchaseLocation = NSLocalizedString("purchase_location", comment: "Purchase location")
    
    // Date and Time
    static let justNow = NSLocalizedString("just_now", comment: "Just now")
    
    // Collection and Items
    static let collection = NSLocalizedString("collection", comment: "Collection")
    static let myCollection = NSLocalizedString("my_collection", comment: "My collection")
    static let itemDetails = NSLocalizedString("item_details", comment: "Item details")
    static let itemEdit = NSLocalizedString("item_edit", comment: "Item edit")
    static let share = NSLocalizedString("share", comment: "Share")
    static let oshiItem = NSLocalizedString("oshi_item", comment: "Oshi item")
    
    // Errors and Validation
    static let error = NSLocalizedString("error", comment: "Error")
    static let validationError = NSLocalizedString("validation_error", comment: "Validation error")
    static let requiredField = NSLocalizedString("required_field", comment: "Required field")
    static let invalidInput = NSLocalizedString("invalid_input", comment: "Invalid input")
    static let networkError = NSLocalizedString("network_error", comment: "Network error")
    static let uploadError = NSLocalizedString("upload_error", comment: "Upload error")
    static let saveError = NSLocalizedString("save_error", comment: "Save error")
    static let deleteError = NSLocalizedString("delete_error", comment: "Delete error")
    
    // Success Messages
    static let success = NSLocalizedString("success", comment: "Success")
    static let savedSuccessfully = NSLocalizedString("saved_successfully", comment: "Saved successfully")
    static let deletedSuccessfully = NSLocalizedString("deleted_successfully", comment: "Deleted successfully")
    static let uploadedSuccessfully = NSLocalizedString("uploaded_successfully", comment: "Uploaded successfully")
    
    // Locations and Address
    static let addressFetchFailed = NSLocalizedString("address_fetch_failed", comment: "Address fetch failed")
    static let locationFetchFailed = NSLocalizedString("location_fetch_failed", comment: "Location fetch failed")
    static let addressFetchError = NSLocalizedString("address_fetch_error", comment: "Address fetch error")
    
    // Oshi Management
    static let oshiList = NSLocalizedString("oshi_list", comment: "Oshi list")
    static let oshiDetails = NSLocalizedString("oshi_details", comment: "Oshi details")
    static let oshiAnniversary = NSLocalizedString("oshi_anniversary", comment: "Oshi anniversary")
    static let congratulations = NSLocalizedString("congratulations", comment: "Congratulations")
    
    // Chat and AI
    static let chat = NSLocalizedString("chat", comment: "Chat")
    static let aiChat = NSLocalizedString("ai_chat", comment: "AI chat")
    static let message = NSLocalizedString("message", comment: "Message")
    static let sendMessage = NSLocalizedString("send_message", comment: "Send message")
    static let typing = NSLocalizedString("typing", comment: "Typing")
    
    // Settings and Preferences
    static let settings = NSLocalizedString("settings", comment: "Settings")
    static let language = NSLocalizedString("language", comment: "Language")
    static let theme = NSLocalizedString("theme", comment: "Theme")
    static let notifications = NSLocalizedString("notifications", comment: "Notifications")
    static let privacy = NSLocalizedString("privacy", comment: "Privacy")
    static let about = NSLocalizedString("about", comment: "About")
    static let version = NSLocalizedString("version", comment: "Version")
    
    // Permissions and Access
    static let cameraPermission = NSLocalizedString("camera_permission", comment: "Camera permission")
    static let photoLibraryPermission = NSLocalizedString("photo_library_permission", comment: "Photo library permission")
    static let locationPermission = NSLocalizedString("location_permission", comment: "Location permission")
    static let permissionDenied = NSLocalizedString("permission_denied", comment: "Permission denied")
    static let permissionRequired = NSLocalizedString("permission_required", comment: "Permission required")
    
    // Loading and Status
    static let pleaseWait = NSLocalizedString("please_wait", comment: "Please wait")
    static let processing = NSLocalizedString("processing", comment: "Processing")
    static let updating = NSLocalizedString("updating", comment: "Updating")
    static let uploading = NSLocalizedString("uploading", comment: "Uploading")
    static let downloading = NSLocalizedString("downloading", comment: "Downloading")
    
    // Help and Support
    static let help = NSLocalizedString("help", comment: "Help")
    static let support = NSLocalizedString("support", comment: "Support")
    static let faq = NSLocalizedString("faq", comment: "FAQ")
    static let contactUs = NSLocalizedString("contact_us", comment: "Contact us")
    static let tutorial = NSLocalizedString("tutorial", comment: "Tutorial")
    
    static func itemCount(_ count: Int) -> String {
        return String.localizedStringWithFormat(NSLocalizedString("item_count", comment: "Item count"), count)
    }
    
    static func yearsAgo(_ years: Int) -> String {
        return String.localizedStringWithFormat(NSLocalizedString("years_ago", comment: "Years ago"), years)
    }
    
    static func monthsAgo(_ months: Int) -> String {
        return String.localizedStringWithFormat(NSLocalizedString("months_ago", comment: "Months ago"), months)
    }
    
    static func daysAgo(_ days: Int) -> String {
        return String.localizedStringWithFormat(NSLocalizedString("days_ago", comment: "Days ago"), days)
    }
    
    static func hoursAgo(_ hours: Int) -> String {
        return String.localizedStringWithFormat(NSLocalizedString("hours_ago", comment: "Hours ago"), hours)
    }
    
    static func minutesAgo(_ minutes: Int) -> String {
        return String.localizedStringWithFormat(NSLocalizedString("minutes_ago", comment: "Minutes ago"), minutes)
    }
    
    static func daysWithOshi(_ days: Int) -> String {
        return String.localizedStringWithFormat(NSLocalizedString("days_with_oshi", comment: "Days with oshi"), days)
    }
    
    static func anniversaryMessage(_ days: Int) -> String {
        return String.localizedStringWithFormat(NSLocalizedString("anniversary_message", comment: "Anniversary message"), days)
    }
    
    static func addressFetchFailedMessage(_ error: String) -> String {
        return String.localizedStringWithFormat(NSLocalizedString("address_fetch_failed", comment: "Address fetch failed message"), error)
    }
    
    static func aiMessageErrorMessage(_ error: String) -> String {
        return String.localizedStringWithFormat(NSLocalizedString("ai_message_error", comment: "AI message error"), error)
    }
    
    static func chatMessageSaveErrorMessage(_ error: String) -> String {
        return String.localizedStringWithFormat(NSLocalizedString("chat_message_save_error", comment: "Chat message save error"), error)
    }
    
    // MARK: - Group Chat Features
    static let groupChat = NSLocalizedString("group_chat", comment: "Group chat")
    static let groupChats = NSLocalizedString("group_chats", comment: "Group chats")
    static let individualChat = NSLocalizedString("individual_chat", comment: "Individual chat")
    static let createGroup = NSLocalizedString("create_group", comment: "Create group")
    static let groupName = NSLocalizedString("group_name", comment: "Group name")
    static let groupMembers = NSLocalizedString("group_members", comment: "Group members")
    static let memberSelection = NSLocalizedString("member_selection", comment: "Member selection")
    static let selectMembers = NSLocalizedString("select_members", comment: "Select members")
    static let groupCreation = NSLocalizedString("group_creation", comment: "Group creation")
    static let editGroup = NSLocalizedString("edit_group", comment: "Edit group")
    static let deleteGroup = NSLocalizedString("delete_group", comment: "Delete group")
    static let groupSettings = NSLocalizedString("group_settings", comment: "Group settings")
    
    // MARK: - Group Chat Messages
    static let enterMessage = NSLocalizedString("enter_message", comment: "Enter message")
    static let noGroupChats = NSLocalizedString("no_group_chats", comment: "No group chats")
    static let createFirstGroup = NSLocalizedString("create_first_group", comment: "Create first group")
    static let groupChatDescription = NSLocalizedString("group_chat_description", comment: "Group chat description")
    static let minimumMembersRequired = NSLocalizedString("minimum_members_required", comment: "Minimum members required")
    static let addOshiFirst = NSLocalizedString("add_oshi_first", comment: "Add oshi first")
    static let noMessagesYet = NSLocalizedString("no_messages_yet", comment: "No messages yet")
    static let startGroupChat = NSLocalizedString("start_group_chat", comment: "Start group chat")
    static let addMembers = NSLocalizedString("add_members", comment: "Add members")
    
    // MARK: - Group Management
    static let newGroup = NSLocalizedString("new_group", comment: "New group")
    static let createNewGroup = NSLocalizedString("create_new_group", comment: "Create new group")
    static let editGroupInfo = NSLocalizedString("edit_group_info", comment: "Edit group info")
    static let groupNamePlaceholder = NSLocalizedString("group_name_placeholder", comment: "Group name placeholder")
    static let groupNameEmptyDefault = NSLocalizedString("group_name_empty_default", comment: "Group name empty default")
    static let selectAll = NSLocalizedString("select_all", comment: "Select all")
    static let deselectAll = NSLocalizedString("deselect_all", comment: "Deselect all")
    static let done = NSLocalizedString("done", comment: "Done")
    static let complete = NSLocalizedString("complete", comment: "Complete")
    static let creating = NSLocalizedString("creating", comment: "Creating")
    
    // MARK: - Group Chat UI
    static let searchGroups = NSLocalizedString("search_groups", comment: "Search groups")
    static let searchOshi = NSLocalizedString("search_oshi", comment: "Search oshi")
    static let preparingGroupChat = NSLocalizedString("preparing_group_chat", comment: "Preparing group chat")
    static let deletingGroup = NSLocalizedString("deleting_group", comment: "Deleting group")
    static let groupDeleted = NSLocalizedString("group_deleted", comment: "Group deleted")
    static let groupCreated = NSLocalizedString("group_created", comment: "Group created")
    static let groupUpdated = NSLocalizedString("group_updated", comment: "Group updated")
    
    // MARK: - Group Chat Confirmations
    static let deleteGroupTitle = NSLocalizedString("delete_group_title", comment: "Delete group title")
    static let leaveGroup = NSLocalizedString("leave_group", comment: "Leave group")
    static let removeMember = NSLocalizedString("remove_member", comment: "Remove member")
    
    // MARK: - Group Chat Empty States
    static let noGroupChatsDescription = NSLocalizedString("no_group_chats_description", comment: "No group chats description")
    static let createGroupButton = NSLocalizedString("create_group_button", comment: "Create group button")
    static let needMoreMembers = NSLocalizedString("need_more_members", comment: "Need more members")
    static let registerMoreOshi = NSLocalizedString("register_more_oshi", comment: "Register more oshi")
    
    // MARK: - Group Name Suggestions
    static let groupNameSuggestion1 = NSLocalizedString("group_name_suggestion_1", comment: "Group name suggestion 1")
    static let groupNameSuggestion2 = NSLocalizedString("group_name_suggestion_2", comment: "Group name suggestion 2")
    static let groupNameSuggestion3 = NSLocalizedString("group_name_suggestion_3", comment: "Group name suggestion 3")
    static let groupNameSuggestion4 = NSLocalizedString("group_name_suggestion_4", comment: "Group name suggestion 4")
    static let groupNameSuggestion5 = NSLocalizedString("group_name_suggestion_5", comment: "Group name suggestion 5")
    
    // MARK: - Group Chat Features
    static let groupIcon = NSLocalizedString("group_icon", comment: "Group icon")
    static let groupDescription = NSLocalizedString("group_description", comment: "Group description")
    static let memberList = NSLocalizedString("member_list", comment: "Member list")
    static let groupInfo = NSLocalizedString("group_info", comment: "Group info")
    static let preview = NSLocalizedString("preview", comment: "Preview")
    static let validationMinMembers = NSLocalizedString("validation_min_members", comment: "Validation min members")
    static let memberAdded = NSLocalizedString("member_added", comment: "Member added")
    static let memberRemoved = NSLocalizedString("member_removed", comment: "Member removed")
    
    // MARK: - Chat Tab Types
    static let individual = NSLocalizedString("individual", comment: "Individual")
    static let group = NSLocalizedString("group", comment: "Group")
    
    // MARK: - Helper functions for dynamic content
    static func membersCount(_ count: Int) -> String {
        return String.localizedStringWithFormat(NSLocalizedString("members_count", comment: "Members count"), count)
    }
    
    static func deleteGroupMessage(_ groupName: String) -> String {
        return String.localizedStringWithFormat(NSLocalizedString("delete_group_message", comment: "Delete group message"), groupName)
    }
    
    // GroupChatRowView用の時刻表示多言語対応
    static let yesterday = NSLocalizedString("yesterday", comment: "Yesterday")
    
    // 曜日の多言語対応（必要に応じて）
    static func dayOfWeek(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale.current  // 現在のロケールを使用
        return formatter.string(from: date)
    }
    
    // 日時フォーマット用のヘルパー関数
    static func formatChatTime(_ timestamp: TimeInterval) -> String {
        guard timestamp > 0 else { return "" }
        
        let date = Date(timeIntervalSince1970: timestamp)
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return L10n.yesterday
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) == true {
            return L10n.dayOfWeek(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
    }
    
    static let oshiLogTab = NSLocalizedString("oshi_log_tab", comment: "Oshi log tab")
    static let pilgrimageTab = NSLocalizedString("pilgrimage_tab", comment: "Pilgrimage tab")
    static let chatTab = NSLocalizedString("chat_tab", comment: "Chat tab")
    static let groupChatTab = NSLocalizedString("group_chat_tab", comment: "Group chat tab")
    static let settingsTab = NSLocalizedString("settings_tab", comment: "Settings tab")
    
    // MARK: - Group Chat Tab Messages
    static let loadingGroupChats = NSLocalizedString("loading_group_chats", comment: "Loading group chats")
    static let noGroupChatsAvailable = NSLocalizedString("no_group_chats_available", comment: "No group chats available")
    static let createGroupChatsMessage = NSLocalizedString("create_group_chats_message", comment: "Create group chats message")
    static let createGroupButtonText = NSLocalizedString("create_group_button_text", comment: "Create group button text")
    static let selectGroupPlease = NSLocalizedString("select_group_please", comment: "Select group please")
    static let selectGroupFromList = NSLocalizedString("select_group_from_list", comment: "Select group from list")
    static let showGroupList = NSLocalizedString("show_group_list", comment: "Show group list")
    
    // MARK: - System Messages (for debugging/logging)
    static let oshiDataLoaded = NSLocalizedString("oshi_data_loaded", comment: "Oshi data loaded")
    static let firebaseSavedOshi = NSLocalizedString("firebase_saved_oshi", comment: "Firebase saved oshi")
    static let fallbackOshi = NSLocalizedString("fallback_oshi", comment: "Fallback oshi")
    static let oshiSelectionCompleted = NSLocalizedString("oshi_selection_completed", comment: "Oshi selection completed")
    static let oshiIdSaveError = NSLocalizedString("oshi_id_save_error", comment: "Oshi ID save error")
    static let oshiIdSaveSuccess = NSLocalizedString("oshi_id_save_success", comment: "Oshi ID save success")
    static let groupIdSaveError = NSLocalizedString("group_id_save_error", comment: "Group ID save error")
    static let groupIdSaveSuccess = NSLocalizedString("group_id_save_success", comment: "Group ID save success")
    static let savedGroupIdRetrieved = NSLocalizedString("saved_group_id_retrieved", comment: "Saved group ID retrieved")
    static let noSavedGroupId = NSLocalizedString("no_saved_group_id", comment: "No saved group ID")
    static let savedGroupRestored = NSLocalizedString("saved_group_restored", comment: "Saved group restored")
    static let defaultGroupSelected = NSLocalizedString("default_group_selected", comment: "Default group selected")
    
    // MARK: - Error Messages
    static let noNamePlaceholder = NSLocalizedString("no_name_placeholder", comment: "No name placeholder")
    static let correspondingOshiNotFound = NSLocalizedString("corresponding_oshi_not_found", comment: "Corresponding oshi not found")
    static let selectedOshiIdChangeDetected = NSLocalizedString("selected_oshi_id_change_detected", comment: "Selected oshi ID change detected")
    
    // MARK: - Loading States
    static let preparingData = NSLocalizedString("preparing_data", comment: "Preparing data")
    static let loadingPleaseWait = NSLocalizedString("loading_please_wait", comment: "Loading please wait")
    
    // MARK: - Tutorial and Onboarding
    static let tutorialStarting = NSLocalizedString("tutorial_starting", comment: "Tutorial starting")
    static let welcomeToApp = NSLocalizedString("welcome_to_app", comment: "Welcome to app")
}

func getCurrentLanguage() -> String {
    return Locale.current.languageCode ?? "en"
}

// Helper function to check if current language is Japanese
func isJapanese() -> Bool {
    return getCurrentLanguage() == "ja"
}

extension Date {
    func timeAgoDisplay() -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(self)
        
        let minute: TimeInterval = 60
        let hour: TimeInterval = 60 * minute
        let day: TimeInterval = 24 * hour
        let month: TimeInterval = 30 * day
        let year: TimeInterval = 365 * day
        
        if timeInterval < minute {
            return L10n.justNow
        } else if timeInterval < hour {
            let minutes = Int(timeInterval / minute)
            return L10n.minutesAgo(minutes)
        } else if timeInterval < day {
            let hours = Int(timeInterval / hour)
            return L10n.hoursAgo(hours)
        } else if timeInterval < month {
            let days = Int(timeInterval / day)
            return L10n.daysAgo(days)
        } else if timeInterval < year {
            let months = Int(timeInterval / month)
            return L10n.monthsAgo(months)
        } else {
            let years = Int(timeInterval / year)
            return L10n.yearsAgo(years)
        }
    }
}
