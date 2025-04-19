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
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("推しの情報")) {
                    TextField("推しの名前", text: $oshiName)
                    
                    Button(action: {
                        generateHapticFeedback()
                        isShowingImagePicker = true
                    }) {
                        HStack {
                            Text("プロフィール画像")
                            Spacer()
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Button(action: {
                        generateHapticFeedback()
                        isShowingBackgroundPicker = true
                    }) {
                        HStack {
                            Text("背景画像")
                            Spacer()
                            if let image = selectedBackgroundImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 30)
                                    .cornerRadius(4)
                            } else {
                                Image(systemName: "photo.badge.plus")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    TextField("メモ", text: $oshiMemo)
                }
                
                Section {
                    Button(action: {
                        generateHapticFeedback()
                        saveOshi()
                    }) {
                        Text("追加")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
            }
            .navigationTitle("推しを追加")
            .navigationBarItems(leading: Button("キャンセル") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(image: $selectedImage, onImagePicked: { _ in })
        }
        .sheet(isPresented: $isShowingBackgroundPicker) {
            ImagePicker(image: $selectedBackgroundImage, onImagePicked: { _ in })
        }
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
