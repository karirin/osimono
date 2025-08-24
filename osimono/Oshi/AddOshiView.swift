//
//  AddOshiView.swift
//  osimono
//
//  推しの登録数制限機能を追加 + 画像登録機能完全実装 + 多言語対応
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import SwiftyCrop

extension UIImage: Identifiable {
    public var id: UUID { UUID() }
}

struct AddOshiView: View {
    // 既存の状態変数
    @Environment(\.presentationMode) var presentationMode
    @State private var oshiName: String = ""
    @State private var oshiMemo: String = ""
    @State private var selectedImage: UIImage?
    @State private var selectedBackgroundImage: UIImage?
    @State private var isLoading = false
    @State private var currentEditType: UploadImageType? = nil
    @State private var image: UIImage? = nil
    @State private var imageUrl: URL? = nil
    @State var backgroundImageUrl: URL?
    @State private var selectedImageForCropping: UIImage?
    @State private var showImagePicker = false
    @State private var croppingImage: UIImage?
    
    // 性格関連の属性
    @State private var personality: String = ""
    @State private var speakingStyle: String = ""
    @State private var showAdvancedOptions: Bool = false
    @State private var userNickname: String = ""

    // 性別選択用の状態変数
    @State private var gender: String = L10n.maleGender
    @State private var genderDetail: String = ""
    
    // 新規追加：制限関連の状態変数
    @State private var currentOshiCount: Int = 0
    @State private var showOshiLimitModal = false
    @State private var showManageOshiModal = false
    @State private var showSubscriptionView = false
    @State private var oshiList: [Oshi] = []
    @StateObject private var subscriptionManager = SubscriptionManager()
    
    // 性別選択肢（多言語対応）
    private var genderOptions: [String] {
        [L10n.maleGender, L10n.femaleGender, L10n.otherGender]
    }
    
    // 色の定義
    let primaryColor = Color(UIColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1.0))
    let backgroundColor = Color(UIColor.systemGroupedBackground)
    
    public struct Texts {
        public var cancelButton: String
        public var interactionInstructions: String
        public var saveButton: String
    }
    
    private var cropConfig: SwiftyCropConfiguration {
        var cfg = SwiftyCropConfiguration(
            texts: .init(
                cancelButton: L10n.cancel,
                interactionInstructions: "",
                saveButton: L10n.apply
            )
        )
        return cfg
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
                    
                    Text(L10n.addOshi)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        generateHapticFeedback()
                        checkLimitAndSaveOshi()
                    }) {
                        Text(L10n.register)
                            .foregroundColor(primaryColor)
                    }
                    .padding()
                }
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 20) {
                        // 推しプロフィール画像
                        VStack {
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
                                    } else {
                                        Circle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 120, height: 120)
                                            .overlay(
                                                Image(systemName: "person.crop.circle.badge.plus")
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
                            
                            Text(L10n.oshiImageDescription)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                        }
                        
                        // 背景画像選択
                        VStack(alignment: .leading) {
                            Text(L10n.backgroundImage)
                                .font(.headline)
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
                                } else {
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
                                                
                                                Text(L10n.selectBackgroundImage)
                                                    .foregroundColor(primaryColor)
                                                    .padding(.top, 8)
                                            }
                                        )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // 情報入力フォーム
                        VStack(spacing: 20) {
                            // 名前フィールド
                            VStack(alignment: .leading) {
                                Text(L10n.oshiName)
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                TextField(L10n.enterName, text: $oshiName)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                    .padding(.horizontal)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(L10n.gender)
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                Picker(L10n.gender, selection: $gender) {
                                    ForEach(genderOptions, id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .padding(.horizontal)
                                
                                if gender == L10n.otherGender {
                                    TextField(L10n.genderDetailPlaceholder, text: $genderDetail)
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(10)
                                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                        .padding(.horizontal)
                                        .padding(.top, 5)
                                        .transition(.opacity.combined(with: .slide))
                                        .animation(.easeInOut, value: gender)
                                }
                            }
                            
                            // 性格入力フィールド
                            VStack(alignment: .leading) {
                                Text(L10n.oshiPersonality)
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                TextField(L10n.personalityPlaceholder, text: $personality)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                    .padding(.horizontal)
                            }
                            
                            // 話し方の特徴入力フィールド
                            VStack(alignment: .leading) {
                                Text(L10n.speakingStyleTitle)
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                TextField(L10n.speakingStylePlaceholder, text: $speakingStyle)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                    .padding(.horizontal)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(L10n.userNicknameTitle)
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                TextField(L10n.userNicknamePlaceholder, text: $userNickname)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                    .padding(.horizontal)
                            }
                            
                            // 詳細設定への案内
                            HStack {
                                Spacer()
                                Text(L10n.detailedPersonalityNote)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                Spacer()
                            }
                        }
                        
                        // 追加ボタン
                        Button(action: {
                            generateHapticFeedback()
                            checkLimitAndSaveOshi()
                        }) {
                            ZStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(L10n.registerOshi)
                                        .fontWeight(.bold)
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
                        .padding(.vertical)
                    }
                    .padding(.bottom, 30)
                }
            }
            
            // モーダル表示
            if showOshiLimitModal {
                OshiLimitModal(
                    isPresented: $showOshiLimitModal,
                    currentOshiCount: currentOshiCount,
                    onUpgrade: {
                        showOshiLimitModal = false
                        showSubscriptionView = true
                    }
                )
                .zIndex(999)
            }
            
            if showManageOshiModal {
                ManageOshiModal(
                    isPresented: $showManageOshiModal,
                    oshiList: $oshiList,
                    onOshiDeleted: {
                        // 推しが削除されたら、カウントを更新
                        loadCurrentOshiCount()
                    }
                )
                .zIndex(998)
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView { pickedImage in
                self.selectedImageForCropping = pickedImage
            }
        }
        .onChange(of: selectedImageForCropping) { newImage in
            guard let img = newImage else { return }
            croppingImage = img
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
        .sheet(isPresented: $showSubscriptionView) {
            SubscriptionPreView()
        }
        .onTapGesture {
            hideKeyboard()
        }
        .onAppear {
            loadCurrentOshiCount()
            // 現在の言語に基づいて初期値を設定
            if gender.isEmpty {
                gender = L10n.maleGender
            }
        }
    }
    
    // 新規追加：制限チェック付きの保存処理
    private func checkLimitAndSaveOshi() {
        // サブスクリプション会員は制限なし
        if subscriptionManager.isSubscribed {
            saveOshi()
            return
        }
        
        // 制限チェック
        if !OshiLimitManager.shared.canAddNewOshi(currentOshiCount: currentOshiCount, isSubscribed: false) {
            showOshiLimitModal = true
            return
        }
        
        // 制限内なら保存
        saveOshi()
    }
    
    // 現在の推し数を取得
    private func loadCurrentOshiCount() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let ref = Database.database().reference().child("oshis").child(userId)
        ref.observeSingleEvent(of: .value) { snapshot in
            DispatchQueue.main.async {
                self.currentOshiCount = Int(snapshot.childrenCount)
                
                // 推しリストも更新（管理モーダル用）
                var newOshis: [Oshi] = []
                for child in snapshot.children {
                    if let childSnapshot = child as? DataSnapshot,
                       let value = childSnapshot.value as? [String: Any] {
                        let id = childSnapshot.key
                        let name = value["name"] as? String ?? L10n.noName
                        let imageUrl = value["imageUrl"] as? String
                        let backgroundImageUrl = value["backgroundImageUrl"] as? String
                        let memo = value["memo"] as? String
                        let createdAt = value["createdAt"] as? TimeInterval
                        
                        let oshi = Oshi(
                            id: id,
                            name: name,
                            imageUrl: imageUrl,
                            backgroundImageUrl: backgroundImageUrl,
                            memo: memo,
                            createdAt: createdAt
                        )
                        newOshis.append(oshi)
                    }
                }
                self.oshiList = newOshis
            }
        }
    }
    
    // クロップ完了後の処理
    private func handleCroppedImage(_ croppedImage: UIImage?) {
        guard let image = croppedImage,
              let editType = currentEditType else { return }

        if editType == .profile {
            selectedImage = image
        } else {
            selectedBackgroundImage = image
        }

        uploadImageToFirebase(image, type: editType)
    }
    
    func fetchUserImageURL(type: UploadImageType, completion: @escaping (URL?) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        
        let filename = type == .profile ? "profile.jpg" : "background.jpg"
        let storageRef = Storage.storage().reference().child("images/\(userID)/\(filename)")
        
        storageRef.downloadURL { url, error in
            completion(url)
        }
    }
    
    // 画像アップロード
    func uploadImageToFirebase(_ image: UIImage, type: UploadImageType = .profile) {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("ユーザーがログインしていません")
            return
        }
        
        let storageRef = Storage.storage().reference()
        let filename = type == .profile ? "profile.jpg" : "background.jpg"
        let imageRef = storageRef.child("images/\(userID)/\(filename)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        withAnimation {
            isLoading = true
        }
        
        imageRef.putData(imageData, metadata: metadata) { _, error in
            if let error = error {
                print("アップロードエラー: \(error.localizedDescription)")
            } else {
                print("画像をアップロードしました")
                if type == .profile {
                    fetchUserImageURL(type: .profile) { url in
                        self.imageUrl = url
                    }
                } else {
                    fetchUserImageURL(type: .background) { url in
                        self.backgroundImageUrl = url
                    }
                }
            }
            
            withAnimation {
                isLoading = false
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // 推しを保存する処理（性格情報を追加）
    func saveOshi() {
        guard let userId = Auth.auth().currentUser?.uid, !oshiName.isEmpty else { return }
        isLoading = true
        
        let oshiId = UUID().uuidString
        var data: [String: Any] = [
            "id": oshiId,
            "name": oshiName,
            "memo": oshiMemo,
            "createdAt": Date().timeIntervalSince1970
        ]
        
        // 性別情報の追加（「その他」の場合は詳細を含める）
        if gender == L10n.otherGender && !genderDetail.isEmpty {
            data["gender"] = "\(L10n.otherGender)：\(genderDetail)"
        } else {
            data["gender"] = gender
        }
        
        // 性格情報が入力されていれば追加
        if !personality.isEmpty {
            data["personality"] = personality
        }
        
        // 話し方の特徴が入力されていれば追加
        if !speakingStyle.isEmpty {
            data["speaking_style"] = speakingStyle
        }

        // 呼び方設定の保存
        if !userNickname.isEmpty {
            data["user_nickname"] = userNickname
        }
        
        let dispatchGroup = DispatchGroup()
        
        // プロフィール画像をアップロード
        if let image = selectedImage {
            dispatchGroup.enter()
            uploadImage(image, path: "oshis/\(userId)/\(oshiId)/profile.jpg") { imageUrl in
                if let url = imageUrl {
                    data["imageUrl"] = url
                }
                dispatchGroup.leave()
            }
        }
        
        // 背景画像をアップロード
        if let image = selectedBackgroundImage {
            dispatchGroup.enter()
            uploadImage(image, path: "oshis/\(userId)/\(oshiId)/background.jpg") { imageUrl in
                if let url = imageUrl {
                    data["backgroundImageUrl"] = url
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.saveDataToFirebase(data)
        }
    }
    
    func uploadImage(_ image: UIImage, path: String, completion: @escaping (String?) -> Void) {
        let storageRef = Storage.storage().reference()
        let imageRef = storageRef.child(path)
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        imageRef.putData(imageData, metadata: metadata) { _, error in
            if let error = error {
                print("画像アップロードエラー: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            imageRef.downloadURL { url, error in
                if let error = error {
                    print("URL取得エラー: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                completion(url?.absoluteString)
            }
        }
    }
    
    func saveDataToFirebase(_ data: [String: Any]) {
        guard let userId = Auth.auth().currentUser?.uid, let oshiId = data["id"] as? String else {
            isLoading = false
            return
        }
        
        let ref = Database.database().reference().child("oshis").child(userId).child(oshiId)
        
        ref.setValue(data) { error, _ in
            DispatchQueue.main.async {
                if error == nil {
                    self.saveSelectedOshiId(oshiId)
                } else {
                    self.isLoading = false
                    print("データ保存エラー: \(error!.localizedDescription)")
                }
            }
        }
    }
    
    func saveSelectedOshiId(_ oshiId: String) {
        guard let userID = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.updateChildValues(["selectedOshiId": oshiId]) { error, _ in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if error == nil {
                    self.presentationMode.wrappedValue.dismiss()
                } else {
                    print("推しID保存エラー: \(error!.localizedDescription)")
                }
            }
        }
    }
}

// ImagePickerViewの実装
struct ImagePickerView: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    AddOshiView()
}
