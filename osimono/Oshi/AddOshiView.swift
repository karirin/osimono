//
//  AddOshiView.swift
//  osimono
//
//  Created by Apple on 2025/04/13.
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
    @State private var showAdvancedOptions: Bool = false // 詳細設定表示トグル
    
    public struct Texts {
        public var cancelButton: String
        public var interactionInstructions: String
        public var saveButton: String
    }
    
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
    
    // 性別選択用の状態変数
    @State private var gender: String = "男性"  // デフォルトは「男性」
    @State private var genderDetail: String = "" // 「その他」の場合の詳細
    
    // 性別選択肢
    let genderOptions = ["男性", "女性", "その他"]
    
    // 色の定義
    let primaryColor = Color(UIColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1.0))
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
                    
                    Text("推しを登録")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // 右側のスペースを確保して中央揃えを維持
                    Button(action: {
                        generateHapticFeedback()
                        saveOshi()
                    }) {
                        Text("登録")
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
                            
                            Text("推しの画像を登録できます")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                        }
                        
                        // 背景画像選択
                        VStack(alignment: .leading) {
                            Text("背景画像")
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
                                                
                                                Text("背景画像を選択")
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
                                Text("推しの名前")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                TextField("名前を入力", text: $oshiName)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                    .padding(.horizontal)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("性別")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                Picker("性別", selection: $gender) {
                                    ForEach(genderOptions, id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .padding(.horizontal)
                                if gender == "その他" {
                                       TextField("詳細を入力（例：犬、ロボット、橋など）", text: $genderDetail)
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
                            
                            // 性格入力フィールド（新規追加）
                            VStack(alignment: .leading) {
                                Text("推しの性格 (オプション)")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                TextField("明るい、優しい、クール など", text: $personality)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                    .padding(.horizontal)
                            }
                            
                            // 話し方の特徴入力フィールド（新規追加）
                            VStack(alignment: .leading) {
                                Text("話し方の特徴 (オプション)")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                TextField("敬語、タメ口、絵文字多用 など", text: $speakingStyle)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                    .padding(.horizontal)
                            }
                            
                            // 詳細設定への案内（新規追加）
                            HStack {
                                Spacer()
                                Text("詳細な性格設定は登録後に編集画面から設定できます")
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
                            saveOshi()
                        }) {
                            ZStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("登録する")
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
        }
        // 画像選択用のシート
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
        .onTapGesture {
            hideKeyboard()
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
        
        // アップロード中の表示
        withAnimation {
            isLoading = true
        }
        
        imageRef.putData(imageData, metadata: metadata) { _, error in
            if let error = error {
                print("アップロードエラー: \(error.localizedDescription)")
            } else {
                print("画像をアップロードしました")
                // URLを取得
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
            
            // アップロード完了後
            withAnimation {
                isLoading = false
            }
        }
    }
    
    // キーボードを閉じる
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // ハプティックフィードバックを生成する
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
        if gender == "その他" && !genderDetail.isEmpty {
            data["gender"] = "\(gender)：\(genderDetail)"
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
                    // 保存に成功したら、選択されたOshiIDとして保存
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
                    // 全ての処理が完了したらビューを閉じる
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
