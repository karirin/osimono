//
//  EditOshiPersonalityView.swift
//  osimono
//
//  Created by Apple on 2025/05/10.
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
    
    // 性別選択用の状態変数を追加
    @State private var gender: String = "男性"
    @State private var genderDetail: String = ""
    // 性別選択肢
    let genderOptions = ["男性", "女性", "その他"]
    
    @State private var isLoading = false
    @ObservedObject var viewModel: OshiViewModel
    var onUpdate: () -> Void
    
    // 色の定義
    let primaryColor = Color(.systemPink)
    let backgroundColor = Color(UIColor.systemGroupedBackground)
    let cardBackgroundColor = Color(UIColor.secondarySystemGroupedBackground)
    
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
        
        // 性別情報の処理
        let genderValue = viewModel.selectedOshi.gender ?? "男性"
        if genderValue.hasPrefix("その他：") {
            _gender = State(initialValue: "その他")
            let detailStartIndex = genderValue.index(genderValue.startIndex, offsetBy: 4)
            _genderDetail = State(initialValue: String(genderValue[detailStartIndex...]))
        } else {
            _gender = State(initialValue: genderValue)
            _genderDetail = State(initialValue: "")
        }
        
        print("初期化時 - 性格: \(viewModel.selectedOshi.personality ?? "なし")")
        print("初期化時 - 話し方: \(viewModel.selectedOshi.speaking_style ?? "なし")")
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
                        Text("戻る")
                            .foregroundColor(primaryColor)
                    }
                    .padding()
                    
                    Spacer()
                    
                    Text("推しの性格を編集")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        generateHapticFeedback()
                        savePersonality()
                    }) {
                        Text("保存")
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
                            SectionHeader(title: "基本情報", icon: "person.fill")
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("性別")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary) // .grayから変更
                                
                                Picker("性別", selection: $gender) {
                                    ForEach(genderOptions, id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                
                                if gender == "その他" {
                                     TextField("詳細を入力（例：犬、ロボット、橋など）", text: $genderDetail)
                                         .padding(10)
                                         .background(Color(.tertiarySystemFill)) // ダークモード対応
                                         .cornerRadius(8)
                                         .padding(.top, 5)
                                         .transition(.opacity.combined(with: .slide))
                                         .animation(.easeInOut, value: gender)
                                 }
                            }
                        }
                        .padding()
                        .background(cardBackgroundColor) // Color.whiteから変更
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                        
                        // 性格入力セクション
                        personalitySection
                        
                        // プロフィール入力セクション
                        profileSection
                        
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
                                    Text("保存する")
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
            
            // デバッグ出力
            print("onAppear時 - 性格: \(viewModel.selectedOshi.personality ?? "なし")")
            print("onAppear時 - 話し方: \(viewModel.selectedOshi.speaking_style ?? "なし")")
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    // 性格セクション
    var personalitySection: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeader(title: "性格・特徴", icon: "person.fill.questionmark")
            
            CustomTextField(
                title: "性格",
                placeholder: "明るい、優しい、クールなど",
                text: $personality,
                iconName: "sparkles"
            )
            
            CustomTextField(
                title: "話し方の特徴",
                placeholder: "敬語、タメ口、絵文字多用など",
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
    
    // プロフィールセクション
    var profileSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeader(title: "プロフィール", icon: "person.text.rectangle.fill")
            
            CustomTextField(
                title: "誕生日",
                placeholder: "1月1日",
                text: $birthday,
                iconName: "gift.fill"
            )
            
            CustomTextField(
                title: "身長",
                placeholder: "例: 165",
                text: $height,
                iconName: "ruler.fill",
                keyboardType: .numberPad
            )
            
            CustomTextField(
                title: "出身地",
                placeholder: "例: 東京都",
                text: $hometown,
                iconName: "mappin.and.ellipse"
            )
        }
        .padding()
        .background(cardBackgroundColor) // Color.whiteから変更
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    // 趣味・興味セクション
    var interestsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeader(title: "趣味・興味", icon: "heart.fill")
            
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
                TextField("新しい趣味・興味を追加", text: $newInterest)
                    .padding(10)
                    .background(Color(.tertiarySystemFill)) // ダークモード対応
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
        .background(cardBackgroundColor) // Color.whiteから変更
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    // 好き嫌いセクション
    var likesDislikesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionHeader(title: "好きなもの・苦手なもの", icon: "hand.thumbsup.fill")
            
            CustomTextField(
                title: "好きな色",
                placeholder: "例: ピンク",
                text: $favoriteColor,
                iconName: "paintpalette.fill"
            )
            
            CustomTextField(
                title: "好きな食べ物",
                placeholder: "例: ラーメン",
                text: $favoriteFood,
                iconName: "fork.knife"
            )
            
            CustomTextField(
                title: "苦手な食べ物",
                placeholder: "例: セロリ",
                text: $dislikedFood,
                iconName: "xmark.circle"
            )
        }
        .padding()
        .background(cardBackgroundColor) // Color.whiteから変更
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
               
               // 性別の処理
               let genderValue = data["gender"] as? String ?? "男性"
               if genderValue.hasPrefix("その他：") {
                   self.gender = "その他"
                   let detailStartIndex = genderValue.index(genderValue.startIndex, offsetBy: 4)
                   self.genderDetail = String(genderValue[detailStartIndex...])
               } else {
                   self.gender = genderValue
                   self.genderDetail = ""
               }
               
               self.initializationCompleted = true
               print("Firebase直接取得 - 性格: \(self.personality)")
           }
       }
    }
    
    // 現在のデータをロード
    private func loadCurrentData() {
        // ローカルのデータがすでに設定されている場合はロードしない
        if !personality.isEmpty {
            print("既存データあり - スキップ")
            return
        }
        
        print("loadCurrentData呼び出し - oshi: \(oshi)")
        
        personality = oshi.personality ?? ""
        speakingStyle = oshi.speaking_style ?? ""
        birthday = oshi.birthday ?? ""
        height = oshi.height != nil ? "\(oshi.height!)" : ""
        favoriteColor = oshi.favorite_color ?? ""
        favoriteFood = oshi.favorite_food ?? ""
        dislikedFood = oshi.disliked_food ?? ""
        hometown = oshi.hometown ?? ""
        interests = oshi.interests ?? []
        
        // 性別情報の処理
        let genderValue = oshi.gender ?? "男性"
        // 「その他：詳細」形式の場合を処理
        if genderValue.hasPrefix("その他：") {
            gender = "その他"
            let detailStartIndex = genderValue.index(genderValue.startIndex, offsetBy: 4)
            genderDetail = String(genderValue[detailStartIndex...])
        } else {
            gender = genderValue
            genderDetail = ""
        }
    }
    
    // データの保存
    private func savePersonality() {
        guard let userID = Auth.auth().currentUser?.uid else {
            return
        }
        
        isLoading = true
        
        let dbRef = Database.database().reference().child("oshis").child(userID).child(oshi.id)
        
        // 性別情報を準備
        let genderValue = gender == "その他" && !genderDetail.isEmpty ? "その他：\(genderDetail)" : gender
        
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
        
        if let heightValue = Int(height) {
            updates["height"] = heightValue
        }
        
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

// セクションヘッダー
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
                .foregroundColor(.secondary) // .grayから変更
            
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.secondary) // .grayから変更
                
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
            }
            .padding(10)
            .background(Color(.tertiarySystemFill)) // ダークモード対応
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

