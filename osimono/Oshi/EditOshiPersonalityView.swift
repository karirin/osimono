//
//  EditOshiPersonalityView.swift
//  osimono
//
//  Created by Apple on 2025/05/10.
//  多言語対応版
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage

struct EditOshiPersonalityView: View {
    @Environment(\.presentationMode) var presentationMode
    var oshi: Oshi
    let onSave: (Oshi) -> Void
    @State private var personality: String = ""
    @State private var speakingStyle: String = ""
    @State private var birthday: String = ""
    @State private var height: String = ""
    @State private var favoriteColor: String = ""
    @State private var favoriteFood: String = ""
    @State private var dislikedFood: String = ""
    @State private var hometown: String = ""
    @State private var interests: [String] = []
    @State private var newInterest: String = ""
    @State private var initializationCompleted: Bool = false
    @State private var userNickname: String = ""
    // 性別選択用の状態変数を追加
    @State private var gender: String = L10n.maleGender
    @State private var genderDetail: String = ""
    
    // 性別選択肢（多言語対応）
    private var genderOptions: [String] {
        [L10n.maleGender, L10n.femaleGender, L10n.otherGender]
    }
    
    @State private var isLoading = false
    @ObservedObject var viewModel: OshiViewModel
    var onUpdate: () -> Void
    
    // 色の定義
    let primaryColor = Color(.systemPink)
    let backgroundColor = Color(UIColor.systemGroupedBackground)
    let cardBackgroundColor = Color(UIColor.secondarySystemGroupedBackground)
    
    @State private var preferredLanguage: String = "auto"
    
    init(viewModel: OshiViewModel, onSave: @escaping (Oshi) -> Void, onUpdate: @escaping () -> Void) {
        self.viewModel = viewModel
        self.oshi = viewModel.selectedOshi
        self.onSave = onSave
        self.onUpdate = onUpdate
        
        _initializationCompleted = State(initialValue: false)
        
        // 初期値の設定
        _personality = State(initialValue: viewModel.selectedOshi.personality ?? "")
        _speakingStyle = State(initialValue: viewModel.selectedOshi.speaking_style ?? "")
        _birthday = State(initialValue: viewModel.selectedOshi.birthday ?? "")
        _height = State(initialValue: viewModel.selectedOshi.height != nil ? "\(viewModel.selectedOshi.height!)" : "")
        _favoriteColor = State(initialValue: viewModel.selectedOshi.favorite_color ?? "")
        _favoriteFood = State(initialValue: viewModel.selectedOshi.favorite_food ?? "")
        _dislikedFood = State(initialValue: viewModel.selectedOshi.disliked_food ?? "")
        _hometown = State(initialValue: viewModel.selectedOshi.hometown ?? "")
        _interests = State(initialValue: viewModel.selectedOshi.interests ?? [])
        _userNickname = State(initialValue: viewModel.selectedOshi.user_nickname ?? "")
        
        _preferredLanguage = State(initialValue: viewModel.selectedOshi.preferred_language ?? "auto")
        
        // 性別情報の処理（多言語対応）
        let genderValue = viewModel.selectedOshi.gender ?? L10n.maleGender
        if genderValue.hasPrefix("\(L10n.otherGender)：") {
            _gender = State(initialValue: L10n.otherGender)
            let detailStartIndex = genderValue.index(genderValue.startIndex, offsetBy: 4)
            _genderDetail = State(initialValue: String(genderValue[detailStartIndex...]))
        } else {
            _gender = State(initialValue: genderValue)
            _genderDetail = State(initialValue: "")
        }
    }
    
    var body: some View {
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // カスタムナビゲーションバー
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text(L10n.back)
                            .foregroundColor(primaryColor)
                    }
                    .padding()
                    
                    Spacer()
                    
                    Text(L10n.editPersonalityTraits)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        generateHapticFeedback()
                        savePersonality()
                    }) {
                        Text(L10n.save)
                            .foregroundColor(primaryColor)
                    }
                    .padding()
                }
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 推しプロフィール画像表示
                        if let imageUrl = oshi.imageUrl, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(primaryColor, lineWidth: 3)
                                        )
                                default:
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Image(systemName: "person.crop.circle")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 40)
                                                .foregroundColor(primaryColor)
                                        )
                                }
                            }
                            .padding(.top, 20)
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Image(systemName: "person.crop.circle")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40)
                                        .foregroundColor(primaryColor)
                                )
                        }
                        
                        Text(oshi.name)
                            .font(.headline)
                            .padding(.bottom, 10)
                        
                        VStack(alignment: .leading, spacing: 15) {
                            SectionHeader(title: L10n.basicInfo, icon: "person.fill")
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.gender)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Picker(L10n.gender, selection: $gender) {
                                    ForEach(genderOptions, id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                
                                if gender == L10n.otherGender {
                                     TextField(L10n.genderDetailPlaceholder, text: $genderDetail)
                                         .padding(10)
                                         .background(Color(.tertiarySystemFill))
                                         .cornerRadius(8)
                                         .padding(.top, 5)
                                         .transition(.opacity.combined(with: .slide))
                                         .animation(.easeInOut, value: gender)
                                 }
                            }
                        }
                        .padding()
                        .background(cardBackgroundColor)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                        
                        // 性格入力セクション
                        personalitySection
                        
                        userInteractionSection
                        
                        // プロフィール入力セクション
                        profileSection
                        
                        languageSettingSection
                        
                        // 趣味・興味入力セクション
                        interestsSection
                        
                        // 好き嫌いセクション
                        likesDislikesSection
                        
                        // 保存ボタン
                        Button(action: {
                            generateHapticFeedback()
                            savePersonality()
                        }) {
                            ZStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(L10n.saveChanges)
                                        .font(.system(size: 16, weight: .bold))
                                }
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
                        .padding(.horizontal, 30)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 80 {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
        )
        .onAppear {
            // 空の場合のみロード
            if !initializationCompleted {
                loadDirectlyFromFirebase()
            }
            
            // 現在の言語に基づいて初期値を設定
            if gender.isEmpty {
                gender = L10n.maleGender
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    var languageSettingSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeader(title: L10n.conversationLanguage, icon: "globe")
            
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.selectConversationLanguage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // 言語選択ピッカー
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(LanguageManager.shared.getAvailableLanguages(), id: \.code) { language in
                        Button(action: {
                            preferredLanguage = language.code
                            generateHapticFeedback()
                        }) {
                            HStack {
                                Image(systemName: preferredLanguage == language.code ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(preferredLanguage == language.code ? primaryColor : .gray)
                                
                                Text(language.name)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(preferredLanguage == language.code ? primaryColor.opacity(0.1) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(preferredLanguage == language.code ? primaryColor : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // 説明テキスト
                Text(L10n.languageSettingNote)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    // 性格セクション
    var personalitySection: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeader(title: L10n.personalityTraits, icon: "person.fill.questionmark")
            
            CustomTextField(
                title: L10n.personality,
                placeholder: L10n.personalityPlaceholder,
                text: $personality,
                iconName: "sparkles"
            )
            
            CustomTextField(
                title: L10n.speakingStyleFeatures,
                placeholder: L10n.speakingStylePlaceholder,
                text: $speakingStyle,
                iconName: "bubble.left.fill"
            )
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    var userInteractionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeader(title: L10n.userRelationship, icon: "person.2.fill")
            
            CustomTextField(
                title: L10n.userNicknameTitle,
                placeholder: L10n.userNicknamePlaceholder,
                text: $userNickname,
                iconName: "person.circle"
            )
            
            // ヘルプテキスト
            Text(L10n.userNicknameHelp)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    // プロフィールセクション
    var profileSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeader(title: L10n.profileSection, icon: "person.text.rectangle.fill")
            
            CustomTextField(
                title: L10n.birthday,
                placeholder: L10n.birthdayPlaceholder,
                text: $birthday,
                iconName: "gift.fill"
            )
            
            CustomTextField(
                title: L10n.height,
                placeholder: L10n.heightPlaceholder,
                text: $height,
                iconName: "ruler.fill",
                keyboardType: .numberPad
            )
            
            CustomTextField(
                title: L10n.hometown,
                placeholder: L10n.hometownPlaceholder,
                text: $hometown,
                iconName: "mappin.and.ellipse"
            )
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    // 趣味・興味セクション
    var interestsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeader(title: L10n.interestsHobbies, icon: "heart.fill")
            
            // 既存の興味タグ
            FlowLayout(
                mode: .scrollable,
                items: interests,
                itemSpacing: 8
            ) { interest in
                InterestTag(
                    text: interest,
                    onRemove: {
                        if let index = interests.firstIndex(of: interest) {
                            interests.remove(at: index)
                        }
                    }
                )
            }
            
            // 新しい興味を追加
            HStack {
                TextField(L10n.addNewInterest, text: $newInterest)
                    .padding(10)
                    .background(Color(.tertiarySystemFill))
                    .cornerRadius(8)
                
                Button(action: {
                    if !newInterest.isEmpty {
                        interests.append(newInterest)
                        newInterest = ""
                        generateHapticFeedback()
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(primaryColor)
                }
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    // 好き嫌いセクション
    var likesDislikesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeader(title: L10n.likesDislikesSection, icon: "hand.thumbsup.fill")
            
            CustomTextField(
                title: L10n.favoriteColor,
                placeholder: L10n.favoriteColorPlaceholder,
                text: $favoriteColor,
                iconName: "paintpalette.fill"
            )
            
            CustomTextField(
                title: L10n.favoriteFood,
                placeholder: L10n.favoriteFoodPlaceholder,
                text: $favoriteFood,
                iconName: "fork.knife"
            )
            
            CustomTextField(
                title: L10n.dislikedFood,
                placeholder: L10n.dislikedFoodPlaceholder,
                text: $dislikedFood,
                iconName: "xmark.circle"
            )
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private func loadDirectlyFromFirebase() {
       guard let userID = Auth.auth().currentUser?.uid else { return }
       
       let oshiRef = Database.database().reference().child("oshis").child(userID).child(oshi.id)
       oshiRef.observeSingleEvent(of: .value) { snapshot in
           guard let data = snapshot.value as? [String: Any] else { return }
           
           DispatchQueue.main.async {
               // データを取得して設定
               self.personality = data["personality"] as? String ?? ""
               self.speakingStyle = data["speaking_style"] as? String ?? ""
               self.birthday = data["birthday"] as? String ?? ""
               self.height = data["height"] != nil ? "\(data["height"] as? Int ?? 0)" : ""
               self.favoriteColor = data["favorite_color"] as? String ?? ""
               self.favoriteFood = data["favorite_food"] as? String ?? ""
               self.dislikedFood = data["disliked_food"] as? String ?? ""
               self.hometown = data["hometown"] as? String ?? ""
               self.interests = data["interests"] as? [String] ?? []
               self.userNickname = data["user_nickname"] as? String ?? ""
               self.preferredLanguage = data["preferred_language"] as? String ?? "auto"
               
               // 性別の処理（多言語対応）
               let genderValue = data["gender"] as? String ?? L10n.maleGender
               if genderValue.hasPrefix("\(L10n.otherGender)：") {
                   self.gender = L10n.otherGender
                   let detailStartIndex = genderValue.index(genderValue.startIndex, offsetBy: 4)
                   self.genderDetail = String(genderValue[detailStartIndex...])
               } else {
                   self.gender = genderValue
                   self.genderDetail = ""
               }
               
               self.initializationCompleted = true
           }
       }
    }
    
    // データの保存
    private func savePersonality() {
        guard let userID = Auth.auth().currentUser?.uid else {
            return
        }
        
        isLoading = true
        
        let dbRef = Database.database().reference().child("oshis").child(userID).child(oshi.id)
        
        // 性別情報を準備（多言語対応）
        let genderValue = gender == L10n.otherGender && !genderDetail.isEmpty ? "\(L10n.otherGender)：\(genderDetail)" : gender
        
        var updates: [String: Any] = [
            "personality": personality,
            "speaking_style": speakingStyle,
            "birthday": birthday,
            "hometown": hometown,
            "favorite_color": favoriteColor,
            "favorite_food": favoriteFood,
            "disliked_food": dislikedFood,
            "interests": interests,
            "gender": genderValue
        ]
        
        updates["preferred_language"] = preferredLanguage
        
        if let heightValue = Int(height) {
            updates["height"] = heightValue
        }
        
        updates["user_nickname"] = userNickname
        
        dbRef.updateChildValues(updates) { error, _ in
            DispatchQueue.main.async {
                isLoading = false
                
                if error == nil {
                    // データを更新
                    var updatedOshi = viewModel.selectedOshi
                    
                    // 新しいデータを設定
                    updatedOshi.personality = personality
                    updatedOshi.speaking_style = speakingStyle
                    updatedOshi.birthday = birthday
                    updatedOshi.hometown = hometown
                    updatedOshi.favorite_color = favoriteColor
                    updatedOshi.favorite_food = favoriteFood
                    updatedOshi.disliked_food = dislikedFood
                    updatedOshi.interests = interests
                    if let heightInt = Int(height) {
                        updatedOshi.height = heightInt
                    }
                    updatedOshi.gender = gender
                    updatedOshi.user_nickname = userNickname
                    updatedOshi.preferred_language = preferredLanguage
                    viewModel.selectedOshi = updatedOshi
                    
                    // Binding変数を明示的に更新
                    onSave(updatedOshi)
                    // 更新コールバックも呼び出し
                    onUpdate()
                    // ビューを閉じる
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    // キーボードを閉じる
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // ハプティックフィードバック
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// セクションヘッダー（多言語対応）
struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.pink)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

// カスタムテキストフィールド
struct CustomTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let iconName: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.secondary)
                
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
            }
            .padding(10)
            .background(Color(.tertiarySystemFill))
            .cornerRadius(8)
        }
    }
}

// 興味タグ
struct InterestTag: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 14))
                .padding(.leading, 10)
                .padding(.trailing, 4)
                .padding(.vertical, 5)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.trailing, 6)
        }
        .background(Color.pink)
        .foregroundColor(.white)
        .cornerRadius(15)
    }
}

// フローレイアウト（タグ表示用）
struct FlowLayout<T: Hashable, V: View>: View {
    enum Mode {
        case scrollable
        case vstack
    }
    
    let mode: Mode
    let items: [T]
    let itemSpacing: CGFloat
    let lineSpacing: CGFloat
    let content: (T) -> V

    init(
        mode: Mode = .scrollable,
        items: [T],
        itemSpacing: CGFloat = 8,
        lineSpacing: CGFloat = 8,
        @ViewBuilder content: @escaping (T) -> V
    ) {
        self.mode = mode
        self.items = items
        self.itemSpacing = itemSpacing
        self.lineSpacing = lineSpacing
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
    }

    @State private var contentHeight: CGFloat = .zero

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .padding(.trailing, itemSpacing)
                    .padding(.bottom, lineSpacing)
                    .alignmentGuide(.leading) { dimension in
                        if (abs(width - dimension.width) > geometry.size.width) {
                            width = 0
                            height -= dimension.height + lineSpacing
                        }
                        
                        let result = width
                        if item == items.last {
                            width = 0
                        } else {
                            width -= dimension.width + itemSpacing
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == items.last {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .frame(maxHeight: mode == .scrollable ? nil : height)
    }
}

#Preview {
    // サンプルデータを作成
    let sampleOshi = Oshi(
        id: "sample-id",
        name: "サンプル推し",
        imageUrl: nil,
        backgroundImageUrl: nil,
        memo: "サンプルメモ",
        createdAt: Date().timeIntervalSince1970
    )
    
    // サンプルのOshiViewModelを作成
    let sampleViewModel = OshiViewModel(oshi: sampleOshi)
    
    // プレビュー用のクロージャ
    let onSaveAction: (Oshi) -> Void = { oshi in
        print("保存されました: \(oshi.name)")
    }
    
    let onUpdateAction: () -> Void = {
        print("更新されました")
    }
    
    // selectedOshiを設定してからViewを返す
    EditOshiPersonalityView(
        viewModel: {
            sampleViewModel.selectedOshi = sampleOshi
            return sampleViewModel
        }(),
        onSave: onSaveAction,
        onUpdate: onUpdateAction
    )
    .preferredColorScheme(.light)
}
