//
//  ContentView.swift
//  osimono
//
//  Created by Apple on 2025/03/20.
//

import SwiftUI
import FirebaseAuth
import FirebaseStorage
import PhotosUI
import ShimmerEffect
import Shimmer

enum UploadImageType1: Identifiable {
    case profile
    case background

    var id: String {
        switch self {
        case .profile: return "profile"
        case .background: return "background"
        }
    }
}

struct OldContentView: View {
    @State private var image: UIImage? = nil
    @State private var imageUrl: URL? = nil
    @State private var isShowingImagePicker = false
    @State private var isShowingForm = false
    @State private var addFlag = false
    @State private var editFlag = false
    @ObservedObject var authManager = AuthManager()
    @State var backgroundImageUrl: URL?
    @State private var editType: UploadImageType1? = nil
    @State private var currentEditType: UploadImageType1? = nil
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            VStack(spacing: isSmallDevice() ? -15 : -60){
                if isLoading {
                    ZStack(alignment: .top){
                        Rectangle()
                            .frame(height: isSmallDevice() ? 200 : 250)
                            .frame(maxWidth: .infinity)
                            .redacted(reason: .placeholder)
                            .edgesIgnoringSafeArea(.all)
                            .foregroundColor(.black)
                            .opacity(0.12)
                        Circle().foregroundColor(.black).opacity(0.09)
                            .frame(width: 150, height: 150)
                    }
                } else {
                    ZStack(alignment: .top){
                        if let backgroundImageUrl = backgroundImageUrl {
                            
                            AsyncImage(url: backgroundImageUrl) { phase in
                                switch phase {
                                case .success(let image):
                                    ZStack{
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: isSmallDevice() ? 200 : 250)
                                            .clipped()
                                            .edgesIgnoringSafeArea(.all)
                                        if editFlag {
                                            ZStack{
                                                Rectangle()
                                                    .foregroundColor(.black)
                                                    .opacity(0.2)
                                                    .frame(height: isSmallDevice() ? 200 : 250)
                                                    .frame(maxWidth: .infinity)
                                                    .edgesIgnoringSafeArea(.all)
                                                HStack{
                                                    Spacer()
                                                    Image(systemName: "camera.fill")
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 40, height: 40)
                                                        .foregroundColor(.white)
                                                }.padding()
                                            }.onTapGesture {
                                                currentEditType = .background
                                            }
                                        }
                                    }
                                default:
                                    Rectangle()
                                        .frame(height: isSmallDevice() ? 200 : 250)
                                        .frame(maxWidth: .infinity)
                                        .redacted(reason: .placeholder)
                                        .shimmering()
                                        .edgesIgnoringSafeArea(.all)
                                        .foregroundColor(.black)
                                        .opacity(0.4)
                                }
                            }
                        } else {
                            ZStack{
                                Rectangle()
                                    .foregroundColor(.black)
                                    .opacity(0.2)
                                    .frame(height: isSmallDevice() ? 200 : 250)
                                    .frame(maxWidth: .infinity)
                                    .edgesIgnoringSafeArea(.all)
                                HStack{
                                    Spacer()
                                    Image(systemName: "camera.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.white)
                                }.padding()
                            }.onTapGesture {
                                currentEditType = .background
                            }
                        }
                        if let imageUrl = imageUrl {
                            AsyncImage(url: imageUrl) { phase in
                                switch phase {
                                case .success(let image):
                                    ZStack{
                                        image
                                            .resizable().scaledToFill().frame(width:150,height: 150).cornerRadius(100)
                                        if editFlag {
                                            Button(action: {
                                                currentEditType = .profile
                                            }) {
                                                ZStack{
                                                    Circle()
                                                        .foregroundColor(.black)
                                                        .opacity(0.2)
                                                        .frame(width:150,height: 150)
                                                        .cornerRadius(100)
                                                    Image(systemName: "camera.fill")
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 40, height: 40)
                                                        .foregroundColor(.white)
                                                }
                                            }
                                        }
                                    }
                                case .failure(_):
                                    Button(action: {
                                        currentEditType = .profile
                                    }) {
                                        ZStack{
                                            Circle().foregroundColor(.black).opacity(0.3)
                                                .frame(width: 150, height: 150)
                                                .shimmering()
                                        }
                                    }
                                case .empty:
                                    Circle().foregroundColor(.black).opacity(0.3)
                                        .frame(width: 150, height: 150)
                                        .shimmering()
                                @unknown default:
                                    Circle().foregroundColor(.black).opacity(0.3)
                                        .frame(width: 150, height: 150)
                                        .shimmering()
                                }
                            }
                        } else {
                            Button(action: {
                                isShowingImagePicker = true
                            }) {
                                ZStack {
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 120, height: 120)
                                        .foregroundColor(.black)
                                        .clipShape(Circle())
                                    
                                    Circle().foregroundColor(.black).opacity(0.3)
                                        .frame(width: 150, height: 150)
                                    
                                    Image(systemName: "camera.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundColor(.white)
                                        .frame(width: 40, height: 40)
                                }
                            }
                        }
                    }
                }
                GoodsListView(addFlag: $addFlag)
            }
            .overlay(
                VStack(spacing:-5){
                    Spacer()
                    HStack{
                        Spacer()
                        Button(action: {
                            editFlag.toggle()
                        }) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 30))
                                .padding(15)
                                .padding(.bottom,3)
                                .background(.black).opacity(0.8)
                                .foregroundColor(Color.white)
                                .clipShape(Circle())
                        }
                        .shadow(radius: 3)
                        .padding(.trailing)
                    }
                    HStack{
                        Spacer()
                        Button(action: {
                            addFlag = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 30))
                                .padding(18)
                                .background(.black).opacity(0.8)
                                .foregroundColor(Color.white)
                                .clipShape(Circle())
                        }
                        .shadow(radius: 3)
                        .padding()
                    }
                }
            )
        }
        .onAppear {
            loadAllData()
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(image: $image, onImagePicked: { pickedImage in
                self.image = pickedImage
                uploadImageToFirebase(pickedImage) // ✅ 画像を選択した瞬間にアップロード
            })
        }
        .sheet(item: $currentEditType) { type in
            ImagePicker(
                image: $image,
                onImagePicked: { pickedImage in
                    self.image = pickedImage
//                    uploadImageToFirebase(pickedImage, type: type)
                    fetchUserImageURL(type: .profile) { url in
                        self.imageUrl = url
                    }
                    fetchUserImageURL(type: .background) { url in
                        self.backgroundImageUrl = url
                    }
                }
            )
        }
    }
    
    func loadAllData() {
        isLoading = true

        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        fetchUserImageURL(type: .profile) { url in
            self.imageUrl = url
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        fetchUserImageURL(type: .background) { url in
            self.backgroundImageUrl = url
            dispatchGroup.leave()
        }

        dispatchGroup.notify(queue: .main) {
            print("isLoading false")
            self.isLoading = false // 両方の画像ロード完了後に false にする
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

    /// ✅ Firebase Storage からユーザーの画像URLを取得
    func fetchUserImageURL(completion: @escaping (URL?) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("ユーザーがログインしていません")
            completion(nil)
            return
        }

        let storageRef = Storage.storage().reference()
        let imageRef = storageRef.child("images/\(userID)/profile.jpg")

        imageRef.downloadURL { url, error in
            if let error = error {
                print("画像URL取得エラー: \(error.localizedDescription)")
                completion(nil)
            } else {
                completion(url)
            }
        }
    }

    func uploadImageToFirebase(_ image: UIImage, type: UploadImageType) {
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
        }
    }

    /// ✅ 画像を Firebase Storage にアップロード
    func uploadImageToFirebase(_ image: UIImage) {
           guard let userID = Auth.auth().currentUser?.uid else {
               print("ユーザーがログインしていません")
               return
           }

           let storageRef = Storage.storage().reference()
           let imageRef = storageRef.child("images/\(userID)/profile.jpg")

           guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

           let metadata = StorageMetadata()
           metadata.contentType = "image/jpeg"

           imageRef.putData(imageData, metadata: metadata) { _, error in
               if let error = error {
                   print("アップロードエラー: \(error.localizedDescription)")
               } else {
                   print("画像をアップロードしました")
                   fetchUserImageURL { url in
                       self.imageUrl = url
                   }
               }
           }
       }
}

struct ShimmerView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color.gray.opacity(0.2) // ベースの色

            LinearGradient(gradient: Gradient(colors: [
                Color.gray.opacity(0.2),
                Color.white.opacity(0.6),
                Color.gray.opacity(0.2)
            ]), startPoint: .leading, endPoint: .trailing)
                .rotationEffect(.degrees(30))
                .offset(x: isAnimating ? 300 : -300)
                .animation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
        }
        .onAppear {
            isAnimating = true
        }
        .clipped()
        .cornerRadius(10)
    }
}


struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onImagePicked: (UIImage) -> Void

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let selectedImage = info[.originalImage] as? UIImage {
                parent.image = selectedImage
                parent.onImagePicked(selectedImage) // ✅ 画像選択時に即アップロード
            }
            picker.dismiss(animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}

struct ImageEditView: View {
    @State private var selectedImage: UIImage?
    @State private var imageType: UploadImageType = .profile
    @State private var isShowingPicker = false
    @Environment(\.dismiss) var dismiss
    var initialType: UploadImageType

    var onUpload: (UIImage, UploadImageType) -> Void
    
    init(onUpload: @escaping (UIImage, UploadImageType) -> Void, initialType: UploadImageType) {
        self.onUpload = onUpload
        self._imageType = State(initialValue: initialType)
        self.initialType = initialType
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Picker("画像の種類", selection: $imageType) {
                    Text("プロフィール").tag(UploadImageType.profile)
                    Text("背景").tag(UploadImageType.background)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .cornerRadius(10)
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .foregroundColor(.gray)
                }

                Button("画像を選択") {
                    isShowingPicker = true
                }
                .buttonStyle(.borderedProminent)

                Button("アップロード") {
                    if let image = selectedImage {
                        onUpload(image, imageType)
                        dismiss()
                    }
                }
                .disabled(selectedImage == nil)
                .buttonStyle(.bordered)
            }
            .navigationTitle("画像を編集")
            .sheet(isPresented: $isShowingPicker) {
                ImagePicker(image: $selectedImage, onImagePicked: { picked in
                    selectedImage = picked
                })
            }
        }
    }
}

#Preview {
    OldContentView()
}
