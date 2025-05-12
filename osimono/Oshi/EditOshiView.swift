//
//  EditOshiView.swift
//  osimono
//
//  Updated to add personality editing
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import SwiftyCrop

// EditOshiView.swift として更新
struct EditOshiView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var oshiName: String = ""
    @State private var selectedImage: UIImage?
    @State private var selectedBackgroundImage: UIImage?
    @State private var isLoading = false
    @State private var currentEditType: UploadImageType? = nil
    @State private var image: UIImage? = nil
    var oshi: Oshi
    var onSave: ((Oshi) -> Void)?
    var onUpdate: () -> Void // 更新後のコールバック
    
    @State private var oshiList: [Oshi] = []
    @State private var isShowingOshiSelector = false
    @State private var selectedOshi: Oshi? // 編集対象の推し
    @State private var showAddOshiForm = false
    @State private var showPersonalityEditor = false // 性格編集画面表示フラグ
    
    @State private var selectedImageForCropping: UIImage?   // 追加
    @State private var showImagePicker = false              // 追加
    @State private var croppingImage: UIImage?
    
    private var cropConfig: SwiftyCropConfiguration {
        var cfg = SwiftyCropConfiguration(
            texts: .init(cancelButton: "キャンセル",
                         interactionInstructions: "",
                         saveButton:   "適用")
        )
        return cfg
    }
    
    // 色の定義
    let primaryColor = Color(.systemPink)
    let backgroundColor = Color(UIColor.systemGroupedBackground)
    
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
                    
                    Text("推しを編集")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        generateHapticFeedback()
                        updateOshi()
                    }) {
                        Text("保存")
                            .foregroundColor(primaryColor)
                    }
                    .padding()
                }
//                .padding(.top, 8)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 推しプロフィール画像とその編集セクション
                        VStack {
                            // 推しプロフィール画像
                            Button(action: {
                                currentEditType = .profile
                                showImagePicker = true
                                generateHapticFeedback()
                            }) {
                                ZStack {
                                    if let image = selectedImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(primaryColor, lineWidth: 3)
                                            )
                                    } else if let imageUrl = oshi.imageUrl, let url = URL(string: imageUrl) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 120, height: 120)
                                                    .clipShape(Circle())
                                                    .overlay(
                                                        Circle()
                                                            .stroke(primaryColor, lineWidth: 3)
                                                    )
                                            default:
                                                Circle()
                                                    .fill(Color.gray.opacity(0.2))
                                                    .frame(width: 120, height: 120)
                                                    .overlay(
                                                        Image(systemName: "person.crop.circle")
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 40)
                                                            .foregroundColor(primaryColor)
                                                    )
                                            }
                                        }
                                    } else {
                                        Circle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 120, height: 120)
                                            .overlay(
                                                Image(systemName: "person.crop.circle")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 40)
                                                    .foregroundColor(primaryColor)
                                            )
                                    }
                                    
                                    // 編集アイコン
                                    Circle()
                                        .fill(primaryColor)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Image(systemName: "pencil")
                                                .font(.system(size: 15))
                                                .foregroundColor(.white)
                                        )
                                        .offset(x: 40, y: 40)
                                }
                            }
                            .padding(.top, 20)
                            
                            Text("推しの画像を変更できます")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                            
                            // 推し変更ボタン（デザイン改善版）
                            Button(action: {
                                withAnimation(.spring()) {
                                    isShowingOshiSelector = true
                                }
                                generateHapticFeedback()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 14))
                                    Text("別の推しを選択")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(primaryColor.opacity(0.15))
                                        .overlay(
                                            Capsule()
                                                .stroke(primaryColor, lineWidth: 1)
                                        )
                                )
                                .foregroundColor(primaryColor)
                            }
                            .padding(.top, 15)
                        }
                        
                        // 名前フィールド
                        VStack(alignment: .leading) {
                            Text("推しの名前")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            TextField("名前を入力", text: $oshiName)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                .padding(.horizontal)
                        }
                        .padding(.top, 10)
                        
                        // 背景画像選択
                        VStack(alignment: .leading) {
                            Text("背景画像")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            Button(action: {
                                currentEditType = .background
                                showImagePicker = true
                                generateHapticFeedback()
                            }) {
                                if let image = selectedBackgroundImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 150)
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(primaryColor, lineWidth: 1)
                                        )
                                } else if let bgUrl = oshi.backgroundImageUrl, let url = URL(string: bgUrl) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 150)
                                                .frame(maxWidth: .infinity)
                                                .clipped()
                                                .cornerRadius(12)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(primaryColor, lineWidth: 1)
                                                )
                                        default:
                                            placeholderBackground
                                        }
                                    }
                                } else {
                                    placeholderBackground
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 10)
                        
                        // 性格・特徴編集ボタン (新規追加)
                        Button(action: {
                            generateHapticFeedback()
                            showPersonalityEditor = true
                        }) {
                            HStack {
                                Image(systemName: "person.fill.questionmark")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(
                                        Circle()
                                            .fill(primaryColor)
                                    )
                                
                                VStack(alignment: .leading) {
                                    Text("性格・特徴を編集")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("推しの性格や好みを設定してチャットを個性的に")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        // 現在の性格設定プレビュー (新規追加)
                        if hasPersonalitySettings() {
                            personalityPreview
                                .padding(.horizontal)
                                .padding(.top, 5)
                        }
                        
                        // 保存ボタン
                        Button(action: {
                            generateHapticFeedback()
                            updateOshi()
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
//                        .padding(.top, 30)
                    }
//                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            // 初期値をセット
            self.oshiName = oshi.name
            fetchOshiList()
        }
        .onTapGesture {
            hideKeyboard()
        }
        .fullScreenCover(isPresented: $showAddOshiForm, onDismiss: {
            fetchOshiList() // 新しい推しが追加されたら一覧を更新
        }) {
            AddOshiView()
        }
        .sheet(isPresented: $showPersonalityEditor) {
            EditOshiPersonalityView(
                oshi: oshi,
                onSave: { updatedOshi in
                    // 親ビューに更新を通知
                    self.onSave?(updatedOshi)
                },
                onUpdate: {
                    onUpdate()
                }
            )
        }
        .overlay(
            ZStack {
                if isShowingOshiSelector {
                    oshiSelectorOverlay
                }
            }
        )
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView { picked in
                selectedImageForCropping = picked
            }
        }
        .onChange(of: selectedImageForCropping) { newImage in
            if let img = newImage { croppingImage = img }
        }
        .fullScreenCover(item: $croppingImage) { img in
            NavigationView {
                SwiftyCropView(
                    imageToCrop: img,
                    maskShape: (currentEditType == .profile) ? .circle : .rectangle,
                    configuration: cropConfig
                ) { cropped in
                    handleCroppedImage(cropped)
                    croppingImage = nil
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // 性格設定があるかチェック
    private func hasPersonalitySettings() -> Bool {
        return oshi.personality != nil || oshi.speaking_style != nil ||
               oshi.birthday != nil || oshi.height != nil ||
               oshi.hometown != nil || oshi.favorite_color != nil ||
               oshi.favorite_food != nil || oshi.disliked_food != nil ||
               (oshi.interests != nil && !oshi.interests!.isEmpty)
    }
    
    // 性格設定プレビュー
    var personalityPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("現在の設定")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 8) {
                // 性別情報を表示（新規追加）
                if let gender = oshi.gender, !gender.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 12))
                            .foregroundColor(primaryColor.opacity(0.8))
                        
                        // 「その他：詳細」形式に対応
                        if gender.hasPrefix("その他：") {
                            let detailStartIndex = gender.index(gender.startIndex, offsetBy: 4)
                            let genderDetail = String(gender[detailStartIndex...])
                            Text("性別：\(genderDetail)")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        } else {
                            Text("性別：\(gender)")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                if let personality = oshi.personality, !personality.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(primaryColor.opacity(0.8))
                        
                        Text("性格: \(personality)")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }
                }
                
                if let speakingStyle = oshi.speaking_style, !speakingStyle.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 12))
                            .foregroundColor(primaryColor.opacity(0.8))
                        
                        Text("話し方: \(speakingStyle)")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }
                }
                
                if let birthday = oshi.birthday, !birthday.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "gift")
                            .font(.system(size: 12))
                            .foregroundColor(primaryColor.opacity(0.8))
                        
                        Text("誕生日: \(birthday)")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }
                }
                
                if let interests = oshi.interests, !interests.isEmpty {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "heart")
                            .font(.system(size: 12))
                            .foregroundColor(primaryColor.opacity(0.8))
                        
                        Text("趣味: \(interests.joined(separator: "、"))")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    var oshiSelectorOverlay: some View {
        ZStack {
            // 半透明の背景
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring()) {
                        isShowingOshiSelector = false
                    }
                }
            
            VStack(spacing: 20) {
                // ヘッダー
                HStack {
                    Text("推しを変更")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        generateHapticFeedback()
                        withAnimation(.spring()) {
                            isShowingOshiSelector = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                
                // 推しリスト - グリッドレイアウト
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                    // 新規追加ボタン
                    Button(action: {
                        generateHapticFeedback()
                        showAddOshiForm = true
                        isShowingOshiSelector = false
                    }) {
                        VStack {
                            ZStack {
                                Circle()
                                    .fill(primaryColor.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 30))
                                    .foregroundColor(primaryColor)
                            }
                            
                            Text("新規追加")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // 推しリスト
                    ForEach(oshiList) { oshi in
                        Button(action: {
                            generateHapticFeedback()
                            saveSelectedOshiId(oshi.id)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            VStack {
                                ZStack {
                                    // プロフィール画像またはプレースホルダー
                                    if let imageUrl = oshi.imageUrl, let url = URL(string: imageUrl) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(Circle())
                                            default:
                                                Circle()
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 80, height: 80)
                                                    .overlay(
                                                        Text(String(oshi.name.prefix(1)))
                                                            .font(.system(size: 30, weight: .bold))
                                                            .foregroundColor(.white)
                                                    )
                                            }
                                        }
                                    } else {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Text(String(oshi.name.prefix(1)))
                                                    .font(.system(size: 30, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                    
                                    // 選択インジケーター
                                    if oshi.id == self.oshi.id {
                                        Circle()
                                            .stroke(primaryColor, lineWidth: 4)
                                            .frame(width: 85, height: 85)
                                    }
                                }
                                
                                Text(oshi.name)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(1))
            )
            .padding()
        }
    }
    
    // 背景画像プレースホルダー
    var placeholderBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.2))
            .frame(height: 150)
            .overlay(
                VStack {
                    Image(systemName: "photo.badge.plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40)
                        .foregroundColor(primaryColor)
                    
                    Text("背景画像を選択")
                        .foregroundColor(primaryColor)
                        .padding(.top, 8)
                }
            )
    }
    
    func saveSelectedOshiId(_ oshiId: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.updateChildValues(["selectedOshiId": oshiId]) { error, _ in
            if let error = error {
                print("推しID保存エラー: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleCroppedImage(_ cropped: UIImage?) {
        guard let image = cropped, let type = currentEditType else { return }
        if type == .profile {
            selectedImage = image
        } else {
            selectedBackgroundImage = image
        }
        uploadImageToFirebase(image, type: type)
    }
    
    func fetchOshiList() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let ref = Database.database().reference().child("oshis").child(userId)
        
        ref.observeSingleEvent(of: .value) { snapshot in
            var newOshis: [Oshi] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot {
                    if let value = childSnapshot.value as? [String: Any] {
                        let id = childSnapshot.key
                        let name = value["name"] as? String ?? "名前なし"
                        let imageUrl = value["imageUrl"] as? String
                        let backgroundImageUrl = value["backgroundImageUrl"] as? String
                        let memo = value["memo"] as? String
                        let createdAt = value["createdAt"] as? TimeInterval
                        
                        // 性格関連の属性を追加
                        let personality = value["personality"] as? String
                        let speakingStyle = value["speaking_style"] as? String
                        let birthday = value["birthday"] as? String
                        let height = value["height"] as? Int
                        let favoriteColor = value["favorite_color"] as? String
                        let favoriteFood = value["favorite_food"] as? String
                        let dislikedFood = value["disliked_food"] as? String
                        let hometown = value["hometown"] as? String
                        let interests = value["interests"] as? [String]
                        let gender = value["gender"] as? String ?? "男性" // 性別情報を追加（デフォルトは男性）
                        
                        let oshi = Oshi(
                            id: id,
                            name: name,
                            imageUrl: imageUrl,
                            backgroundImageUrl: backgroundImageUrl,
                            memo: memo,
                            createdAt: createdAt,
                            personality: personality,
                            interests: interests,
                            speaking_style: speakingStyle,
                            birthday: birthday,
                            height: height,
                            favorite_color: favoriteColor,
                            favorite_food: favoriteFood,
                            disliked_food: dislikedFood,
                            hometown: hometown,
                            gender: gender // 性別情報を追加
                        )
                        newOshis.append(oshi)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.oshiList = newOshis
            }
        }
    }
    
    // 画像アップロード関数
    func uploadImageToFirebase(_ image: UIImage, type: UploadImageType) {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("ユーザーがログインしていません")
            return
        }
        
        isLoading = true
        
        let storageRef = Storage.storage().reference()
        let filename = type == .profile ? "profile.jpg" : "background.jpg"
        let imageRef = storageRef.child("oshis/\(userID)/\(oshi.id)/\(filename)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        imageRef.putData(imageData, metadata: metadata) { _, error in
            if let error = error {
                print("アップロードエラー: \(error.localizedDescription)")
                isLoading = false
                return
            }
            
            imageRef.downloadURL { url, error in
                isLoading = false
                
                if let error = error {
                    print("URL取得エラー: \(error.localizedDescription)")
                    return
                }
                
                if let url = url {
                    let dbRef = Database.database().reference().child("oshis").child(userID).child(oshi.id)
                    let updates: [String: Any] = type == .profile
                    ? ["imageUrl": url.absoluteString]
                    : ["backgroundImageUrl": url.absoluteString]
                    
                    dbRef.updateChildValues(updates)
                }
            }
        }
    }
    
    // 推し情報の更新
    func updateOshi() {
        guard let userID = Auth.auth().currentUser?.uid, !oshiName.isEmpty else { return }
        
        isLoading = true
        
        // 画像のアップロードが必要な場合は先にアップロードする
        let dispatchGroup = DispatchGroup()
        
        var profileImageUrl: String? = nil
        var backgroundImageUrl: String? = nil
        
        // プロフィール画像をアップロード
        if let profileImage = selectedImage {
            dispatchGroup.enter()
            uploadImage(profileImage, type: .profile) { url in
                profileImageUrl = url
                dispatchGroup.leave()
            }
        }
        
        // 背景画像をアップロード
        if let backgroundImage = selectedBackgroundImage {
            dispatchGroup.enter()
            uploadImage(backgroundImage, type: .background) { url in
                backgroundImageUrl = url
                dispatchGroup.leave()
            }
        }
        
        // すべてのアップロードが完了したらデータベースを更新
        dispatchGroup.notify(queue: .main) {
            let dbRef = Database.database().reference().child("oshis").child(userID).child(oshi.id)
            var updates: [String: Any] = [
                "name": oshiName
            ]
            
            if let url = profileImageUrl {
                updates["imageUrl"] = url
            }
            
            if let url = backgroundImageUrl {
                updates["backgroundImageUrl"] = url
            }
            
            dbRef.updateChildValues(updates) { error, _ in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    if error == nil {
                        // 更新コールバックを呼び出し
                        onUpdate()
                        // ビューを閉じる
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        
        // 画像のアップロードがない場合は直接データベースを更新
        if selectedImage == nil && selectedBackgroundImage == nil {
            let dbRef = Database.database().reference().child("oshis").child(userID).child(oshi.id)
            let updates: [String: Any] = [
                "name": oshiName
            ]
            
            dbRef.updateChildValues(updates) { error, _ in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    if error == nil {
                        // 更新コールバックを呼び出し
                        onUpdate()
                        // ビューを閉じる
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    func uploadImage(_ image: UIImage, type: UploadImageType, completion: @escaping (String?) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("ユーザーがログインしていません")
            completion(nil)
            return
        }
        
        let storageRef = Storage.storage().reference()
        let filename = type == .profile ? "profile.jpg" : "background.jpg"
        let imageRef = storageRef.child("oshis/\(userID)/\(oshi.id)/\(filename)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        imageRef.putData(imageData, metadata: metadata) { _, error in
            if let error = error {
                print("アップロードエラー: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            imageRef.downloadURL { url, error in
                if let error = error {
                    print("URL取得エラー: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                if let url = url {
                    completion(url.absoluteString)
                } else {
                    completion(nil)
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

#Preview {
    // サンプルデータを作成
    let sampleOshi = Oshi(
        id: "sample-id",
        name: "サンプル推し",
        imageUrl: nil,
        backgroundImageUrl: nil,
        memo: "サンプルメモ",
        createdAt: Date().timeIntervalSince1970,
        personality: "明るく元気",
        interests: ["音楽", "ダンス"],
        speaking_style: "タメ口、絵文字多用"
    )
    
    // プレビュー用のクロージャ
    let updateAction = {}
    
    return EditOshiView(oshi: sampleOshi, onUpdate: updateAction)
        .preferredColorScheme(.light)
}
