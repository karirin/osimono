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

struct AddOshiView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var oshiName: String = ""
    @State private var oshiMemo: String = ""
    @State private var selectedImage: UIImage?
    @State private var selectedBackgroundImage: UIImage?
    @State private var isShowingImagePicker = false
    @State private var isShowingBackgroundPicker = false
    @State private var isImagePickerForProfile = true
    @State private var isLoading = false
    @State private var currentEditType: UploadImageType? = nil
    @State private var image: UIImage? = nil
    @State private var imageUrl: URL? = nil
    @State var backgroundImageUrl: URL?
    
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
                            
                            // メモフィールド
//                            VStack(alignment: .leading) {
//                                Text("メモ")
//                                    .font(.headline)
//                                    .padding(.horizontal)
//
//                                TextEditor(text: $oshiMemo)
//                                    .frame(minHeight: 120)
//                                    .padding(4)
//                                    .background(Color.white)
//                                    .cornerRadius(10)
//                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
//                                    .overlay(
//                                        RoundedRectangle(cornerRadius: 10)
//                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
//                                    )
//                                    .padding(.horizontal)
//                            }
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
//                        .disabled(oshiName.isEmpty || isLoading)
//                        .opacity(oshiName.isEmpty ? 0.6 : 1.0)
                        .padding(.horizontal, 30)
                        .padding(.vertical)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .sheet(item: $currentEditType) { type in
            ImageAddOshiPicker(
                image: $image,
                onImagePicked: { pickedImage in
                    self.image = pickedImage
                    
                    // この部分が重要: 選択した画像をUIに表示するために更新
                    if type == .profile {
                        self.selectedImage = pickedImage
                    } else {
                        self.selectedBackgroundImage = pickedImage
                    }
                    
                    // アップロード処理
                    uploadImageToFirebase(pickedImage, type: type)
                }
            )
        }
        .onTapGesture {
            hideKeyboard()
        }
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
    
    // ハプティックフィードバックを生成する関数（未定義だったので追加）
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    func saveOshi() {
        print("saveOshi1")
        guard let userId = Auth.auth().currentUser?.uid, !oshiName.isEmpty else { return }
        print("saveOshi2")
        isLoading = true
        
        let oshiId = UUID().uuidString
        var data: [String: Any] = [
            "id": oshiId,
            "name": oshiName,
            "memo": oshiMemo,
            "createdAt": Date().timeIntervalSince1970
        ]
        
        let dispatchGroup = DispatchGroup()
        
        // プロフィール画像をアップロード
        if let image = selectedImage {
            print("saveOshi3")
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
            print("saveOshi4")
            dispatchGroup.enter()
            uploadImage(image, path: "oshis/\(userId)/\(oshiId)/background.jpg") { imageUrl in
                if let url = imageUrl {
                    data["backgroundImageUrl"] = url
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            print("saveOshi5")
            self.saveDataToFirebase(oshiId, data)
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
    
    func saveDataToFirebase(_ oshiId: String, _ data: [String: Any]) {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        let ref = Database.database().reference().child("oshis").child(userId).child(oshiId)
        
        ref.setValue(data) { error, _ in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if error == nil {
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

#Preview {
    AddOshiView()
}
