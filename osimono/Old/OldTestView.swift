//
//  OldTestView.swift
//  osimono
//
//  Created by Apple on 2025/04/05.
//

//import SwiftUI
//import FirebaseAuth
//import FirebaseStorage
//import PhotosUI
//import ShimmerEffect
//import Shimmer
//import Firebase
//
//enum UploadImageType1: Identifiable {
//    case profile
//    case background
//
//    var id: String {
//        switch self {
//        case .profile: return "profile"
//        case .background: return "background"
//        }
//    }
//}
//
//struct ContentView1: View {
//    @State private var image: UIImage? = nil
//    @State private var imageUrl: URL? = nil
//    @State private var isShowingImagePicker = false
//    @State private var isShowingForm = false
//    @State private var addFlag = false
//    @State private var editFlag = false
//    @ObservedObject var authManager = AuthManager()
//    @State var backgroundImageUrl: URL?
//    @State private var editType: UploadImageType1? = nil
//    @State private var currentEditType: UploadImageType1? = nil
//    @State private var isLoading = true
//    @State private var selectedTab = 0
//    @Environment(\.colorScheme) var colorScheme
//
//    // テーマカラーの定義
//    let primaryColor = Color("#3B82F6") // 青系
//    let accentColor = Color("#10B981") // 緑系
//    let backgroundColor = Color("#F9FAFB") // 明るい背景色
//    let cardColor = Color("#FFFFFF") // カード背景色
//    let textColor = Color("#1F2937") // テキスト色
//
//    // プロフィールセクションの高さ
//    var profileSectionHeight: CGFloat {
//        isSmallDevice() ? 180 : 220
//    }
//
//    var body: some View {
//        NavigationView {
//            ZStack {
//                // 背景色
//                backgroundColor.ignoresSafeArea()
//
//                VStack(spacing: 0) {
//                    // プロフィールセクション
//                    profileSection
//
//                    // タブビュー
//                    customTabView
//
//                    // メインコンテンツ
//                    TabView(selection: $selectedTab) {
//                        GoodsListView1(addFlag: $addFlag)
//                            .tag(0)
//
//                        Text("お気に入り")
//                            .font(.system(size: 20, weight: .medium))
//                            .foregroundColor(textColor)
//                            .tag(1)
//
//                        Text("カテゴリー")
//                            .font(.system(size: 20, weight: .medium))
//                            .foregroundColor(textColor)
//                            .tag(2)
//
//                        Text("設定")
//                            .font(.system(size: 20, weight: .medium))
//                            .foregroundColor(textColor)
//                            .tag(3)
//                    }
//                    .tabViewStyle(.page(indexDisplayMode: .never))
//                    .animation(.easeInOut, value: selectedTab)
//                }
//            }
//            .overlay(
//                VStack(spacing: -5) {
//                    Spacer()
//                    HStack {
//                        Spacer()
//                        Button(action: {
//                            withAnimation(.spring()) {
//                                editFlag.toggle()
//                            }
//                            generateHapticFeedback()
//                        }) {
//                            Image(systemName: "square.and.pencil")
//                                .font(.system(size: 22, weight: .medium))
//                                .padding(15)
//                                .background(
//                                    Circle()
//                                        .fill(accentColor)
//                                        .shadow(color: accentColor.opacity(0.3), radius: 5, x: 0, y: 3)
//                                )
//                                .foregroundColor(.white)
//                        }
//                        .padding(.trailing)
//                        .offset(y: editFlag ? -60 : 0)
//                    }
//
//                    HStack {
//                        Spacer()
//                        Button(action: {
//                            withAnimation(.spring()) {
////                                addFlag = true
//                            }
//                            generateHapticFeedback()
//                        }) {
//                            Image(systemName: "plus")
//                                .font(.system(size: 25, weight: .medium))
//                                .padding(18)
//                                .background(
//                                    Circle()
//                                        .fill(primaryColor)
//                                        .shadow(color: primaryColor.opacity(0.3), radius: 5, x: 0, y: 3)
//                                )
//                                .foregroundColor(.white)
//                        }
//                        .padding()
//                    }
//                }
//            )
//            .navigationBarTitle("マイコレクション", displayMode: .inline)
//            .navigationBarItems(trailing:
//                Button(action: {
//                    // 通知ボタン
//                }) {
//                    Image(systemName: "bell")
//                        .font(.system(size: 16, weight: .medium))
//                        .foregroundColor(textColor)
//                }
//            )
//        }
//        .accentColor(primaryColor)
//        .onAppear {
//            loadAllData()
//        }
//        .sheet(isPresented: $isShowingImagePicker) {
//            ImagePicker(image: $image, onImagePicked: { pickedImage in
//                self.image = pickedImage
//                uploadImageToFirebase(pickedImage)
//            })
//        }
//        .sheet(item: $currentEditType) { type in
//            ImagePicker(
//                image: $image,
//                onImagePicked: { pickedImage in
//                    self.image = pickedImage
//                    uploadImageToFirebase(pickedImage, type: type)
//                    fetchUserImageURL(type: .profile) { url in
//                        self.imageUrl = url
//                    }
//                    fetchUserImageURL(type: .background) { url in
//                        self.backgroundImageUrl = url
//                    }
//                }
//            )
//        }
//    }
//
//    // プロフィールセクション
//    var profileSection: some View {
//        ZStack(alignment: .bottom) {
//            // 背景画像
//            if isLoading {
//                // ローディング状態の背景
//                Rectangle()
//                    .frame(height: profileSectionHeight)
//                    .frame(maxWidth: .infinity)
//                    .foregroundColor(Color.gray.opacity(0.1))
////                    .shimmer(true)
//            } else {
//                // 背景画像の表示
//                if let backgroundImageUrl = backgroundImageUrl {
//                    AsyncImage(url: backgroundImageUrl) { phase in
//                        switch phase {
//                        case .success(let image):
//                            image
//                                .resizable()
//                                .scaledToFill()
//                                .frame(height: profileSectionHeight)
//                                .clipped()
//                                .overlay(
//                                    LinearGradient(
//                                        gradient: Gradient(colors: [.clear, Color.black.opacity(0.3)]),
//                                        startPoint: .top,
//                                        endPoint: .bottom
//                                    )
//                                )
//                                .overlay(
//                                    editFlag ? editBackgroundOverlay : nil
//                                )
//                        default:
//                            Rectangle()
//                                .frame(height: profileSectionHeight)
//                                .foregroundColor(Color.gray.opacity(0.1))
////                                .shimmer(true)
//                        }
//                    }
//                } else {
//                    // 背景画像がない場合
//                    ZStack {
//                        LinearGradient(
//                            gradient: Gradient(colors: [primaryColor.opacity(0.7), accentColor.opacity(0.7)]),
//                            startPoint: .topLeading,
//                            endPoint: .bottomTrailing
//                        )
//                        .frame(height: profileSectionHeight)
//
//                        if editFlag {
//                            editBackgroundOverlay
//                        }
//                    }
//                }
//            }
//
//            // プロフィール情報とアバター
//            VStack(spacing: 8) {
//                // プロフィール画像
//                ZStack {
//                    if let imageUrl = imageUrl {
//                        AsyncImage(url: imageUrl) { phase in
//                            switch phase {
//                            case .success(let image):
//                                ZStack {
//                                    image
//                                        .resizable()
//                                        .scaledToFill()
//                                        .frame(width: 100, height: 100)
//                                        .clipShape(Circle())
//                                        .overlay(
//                                            Circle()
//                                                .stroke(Color.white, lineWidth: 3)
//                                        )
//                                        .shadow(color: Color.black.opacity(0.2), radius: 5)
//
//                                    if editFlag {
//                                        Button(action: {
//                                            currentEditType = .profile
//                                            generateHapticFeedback()
//                                        }) {
//                                            ZStack {
//                                                Circle()
//                                                    .fill(Color.black.opacity(0.5))
//                                                    .frame(width: 100, height: 100)
//
//                                                Image(systemName: "camera.fill")
//                                                    .foregroundColor(.white)
//                                                    .font(.system(size: 30))
//                                            }
//                                        }
//                                    }
//                                }
//                            case .failure(_):
//                                profilePlaceholder
//                            case .empty:
//                                profilePlaceholder
//                            @unknown default:
//                                profilePlaceholder
//                            }
//                        }
//                    } else {
//                        Button(action: {
//                            isShowingImagePicker = true
//                        }) {
//                            profilePlaceholder
//                        }
//                    }
//                }
//                .padding(.bottom, 4)
//
//                // ユーザー名と詳細
//                VStack(spacing: 4) {
//                    Text("ユーザー")
//                        .font(.system(size: 18, weight: .bold))
//                        .foregroundColor(.white)
//
//                    Text("コレクション: \(goods.count)点")
//                        .font(.system(size: 14))
//                        .foregroundColor(.white.opacity(0.9))
//                }
//                .padding(.bottom, 12)
//            }
//            .offset(y: 30)
//        }
//        .frame(height: profileSectionHeight + 60)
//    }
//
//    // カスタムタブビュー
//    var customTabView: some View {
//        HStack(spacing: 0) {
//            ForEach(0..<4) { index in
//                Button(action: {
//                    withAnimation {
//                        selectedTab = index
//                    }
//                    generateHapticFeedback()
//                }) {
//                    VStack(spacing: 4) {
//                        Image(systemName: tabIcon(for: index))
//                            .font(.system(size: 20))
//
//                        Text(tabTitle(for: index))
//                            .font(.system(size: 12))
//                    }
//                    .foregroundColor(selectedTab == index ? primaryColor : Color.gray)
//                    .frame(maxWidth: .infinity)
//                    .padding(.vertical, 8)
//                }
//            }
//        }
//        .background(cardColor)
//        .cornerRadius(12)
//        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
//        .padding(.horizontal)
//        .padding(.top, 40)
//    }
//
//    // 背景編集オーバーレイ
//    var editBackgroundOverlay: some View {
//        ZStack {
//            Color.black.opacity(0.3)
//
//            VStack {
//                HStack {
//                    Spacer()
//                    Button(action: {
//                        currentEditType = .background
//                        generateHapticFeedback()
//                    }) {
//                        Image(systemName: "camera.fill")
//                            .font(.system(size: 24))
//                            .foregroundColor(.white)
//                            .padding(12)
//                            .background(Circle().fill(Color.black.opacity(0.5)))
//                    }
//                    .padding()
//                }
//                Spacer()
//            }
//        }
//    }
//
//    // プロフィール画像プレースホルダー
//    var profilePlaceholder: some View {
//        ZStack {
//            Circle()
//                .fill(Color.gray.opacity(0.3))
//                .frame(width: 100, height: 100)
//                .overlay(
//                    Circle()
//                        .stroke(Color.white, lineWidth: 3)
//                )
//                .shadow(color: Color.black.opacity(0.1), radius: 5)
//
//            Image(systemName: "person.fill")
//                .resizable()
//                .scaledToFit()
//                .frame(width: 50, height: 50)
//                .foregroundColor(.white)
//
//            if isShowingImagePicker == false {
//                Image(systemName: "plus.circle.fill")
//                    .font(.system(size: 24))
//                    .foregroundColor(.white)
//                    .background(Circle().fill(primaryColor))
//                    .offset(x: 32, y: 32)
//            }
//        }
//    }
//
//    // タブアイコン取得
//    func tabIcon(for index: Int) -> String {
//        switch index {
//        case 0: return "square.grid.2x2"
//        case 1: return "heart"
//        case 2: return "folder"
//        case 3: return "gearshape"
//        default: return ""
//        }
//    }
//
//    // タブタイトル取得
//    func tabTitle(for index: Int) -> String {
//        switch index {
//        case 0: return "コレクション"
//        case 1: return "お気に入り"
//        case 2: return "カテゴリー"
//        case 3: return "設定"
//        default: return ""
//        }
//    }
//
//    // 商品データの参照用プロパティ
//    var goods: [Goods] {
//        // GoodsListViewからデータを取得するためのダミープロパティ
//        // 実際の実装では、共有された状態管理を使うべき
//        []
//    }
//
//    func loadAllData() {
//        isLoading = true
//
//        let dispatchGroup = DispatchGroup()
//
//        dispatchGroup.enter()
//        fetchUserImageURL(type: .profile) { url in
//            self.imageUrl = url
//            dispatchGroup.leave()
//        }
//
//        dispatchGroup.enter()
//        fetchUserImageURL(type: .background) { url in
//            self.backgroundImageUrl = url
//            dispatchGroup.leave()
//        }
//
//        dispatchGroup.notify(queue: .main) {
//            withAnimation {
//                self.isLoading = false
//            }
//        }
//    }
//
//    func fetchUserImageURL(type: UploadImageType, completion: @escaping (URL?) -> Void) {
//        guard let userID = Auth.auth().currentUser?.uid else {
//            completion(nil)
//            return
//        }
//
//        let filename = type == .profile ? "profile.jpg" : "background.jpg"
//        let storageRef = Storage.storage().reference().child("images/\(userID)/\(filename)")
//
//        storageRef.downloadURL { url, error in
//            completion(url)
//        }
//    }
//
//    func fetchUserImageURL(completion: @escaping (URL?) -> Void) {
//        guard let userID = Auth.auth().currentUser?.uid else {
//            print("ユーザーがログインしていません")
//            completion(nil)
//            return
//        }
//
//        let storageRef = Storage.storage().reference()
//        let imageRef = storageRef.child("images/\(userID)/profile.jpg")
//
//        imageRef.downloadURL { url, error in
//            if let error = error {
//                print("画像URL取得エラー: \(error.localizedDescription)")
//                completion(nil)
//            } else {
//                completion(url)
//            }
//        }
//    }
//
//    func uploadImageToFirebase(_ image: UIImage, type: UploadImageType1 = .profile) {
//        guard let userID = Auth.auth().currentUser?.uid else {
//            print("ユーザーがログインしていません")
//            return
//        }
//
//        let storageRef = Storage.storage().reference()
//        let filename = type == .profile ? "profile.jpg" : "background.jpg"
//        let imageRef = storageRef.child("images/\(userID)/\(filename)")
//
//        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
//
//        let metadata = StorageMetadata()
//        metadata.contentType = "image/jpeg"
//
//        // アップロード中の表示
//        withAnimation {
//            isLoading = true
//        }
//
//        imageRef.putData(imageData, metadata: metadata) { _, error in
//            if let error = error {
//                print("アップロードエラー: \(error.localizedDescription)")
//            } else {
//                print("画像をアップロードしました")
//                if type == .profile {
//                    fetchUserImageURL(type: .profile) { url in
//                        self.imageUrl = url
//                    }
//                } else {
//                    fetchUserImageURL(type: .background) { url in
//                        self.backgroundImageUrl = url
//                    }
//                }
//            }
//
//            // アップロード完了後
//            withAnimation {
//                isLoading = false
//            }
//        }
//    }
//}
//
//// GoodsListViewの更新版
//struct GoodsListView1: View {
//    @State private var goods: [Goods] = []
//    @State private var selectedImage: UIImage?
//    @State private var isShowingForm = false
//    @State private var selectedCategory: String = "すべて"
//    @State private var searchText: String = ""
//    @Binding var addFlag: Bool
//    @State var isLoading = false
//    @State private var showingFilterMenu = false
//    @State private var sortOption = "新しい順"
//
//    // 色の定義
//    let primaryColor = Color("#3B82F6") // 青系
//    let backgroundColor = Color("#F9FAFB") // 明るい背景色
//    let cardColor = Color("#FFFFFF") // カード背景色
//
//    // カテゴリーリスト
//    let categories = ["すべて", "アクリル", "服", "CDアルバム", "ポスター", "その他"]
//
//    var userId: String? {
//        Auth.auth().currentUser?.uid
//    }
//
//    // 検索とフィルター適用後の商品リスト
//    var filteredGoods: [Goods] {
//        var result = goods
//
//        // カテゴリーフィルター
//        if selectedCategory != "すべて" {
//            result = result.filter { $0.category == selectedCategory }
//        }
//
//        // 検索テキストフィルター
//        if !searchText.isEmpty {
//            result = result.filter { good in
//                return good.title?.lowercased().contains(searchText.lowercased()) ?? false ||
//                good.memo?.lowercased().contains(searchText.lowercased()) ?? false
//            }
//        }
//
//        // ソート
//        switch sortOption {
//        case "新しい順":
//            result.sort { (a, b) -> Bool in
//                guard let dateA = a.date, let dateB = b.date else { return false }
//                return dateA > dateB
//            }
//        case "古い順":
//            result.sort { (a, b) -> Bool in
//                guard let dateA = a.date, let dateB = b.date else { return false }
//                return dateA < dateB
//            }
//        case "価格高い順":
//            result.sort { (a, b) -> Bool in
//                return (a.price ?? 0) > (b.price ?? 0)
//            }
//        case "価格安い順":
//            result.sort { (a, b) -> Bool in
//                return (a.price ?? 0) < (b.price ?? 0)
//            }
//        case "お気に入り順":
//            result.sort { (a, b) -> Bool in
//                return (a.favorite ?? 0) > (b.favorite ?? 0)
//            }
//        default:
//            break
//        }
//
//        return result
//    }
//
//    var body: some View {
//        VStack(spacing: 0) {
//            // 検索バーとフィルター
//            HStack(spacing: 12) {
//                // 検索バー
//                HStack {
//                    Image(systemName: "magnifyingglass")
//                        .foregroundColor(.gray)
//
//                    TextField("検索", text: $searchText)
//                        .font(.system(size: 14))
//
//                    if !searchText.isEmpty {
//                        Button(action: {
//                            searchText = ""
//                        }) {
//                            Image(systemName: "xmark.circle.fill")
//                                .foregroundColor(.gray)
//                        }
//                    }
//                }
//                .padding(8)
//                .background(cardColor)
//                .cornerRadius(10)
//                .shadow(color: Color.black.opacity(0.05), radius: 2)
//
//                // フィルターボタン
//                Button(action: {
//                    withAnimation {
//                        showingFilterMenu.toggle()
//                    }
//                    generateHapticFeedback()
//                }) {
//                    Image(systemName: "slider.horizontal.3")
//                        .foregroundColor(primaryColor)
//                        .padding(8)
//                        .background(cardColor)
//                        .cornerRadius(10)
//                        .shadow(color: Color.black.opacity(0.05), radius: 2)
//                }
//            }
//            .padding(.horizontal)
//            .padding(.vertical, 8)
//
//            // カテゴリー選択
//            ScrollView(.horizontal, showsIndicators: false) {
//                HStack(spacing: 12) {
//                    ForEach(categories, id: \.self) { category in
//                        Button(action: {
//                            withAnimation {
//                                selectedCategory = category
//                            }
//                            generateHapticFeedback()
//                        }) {
//                            Text(category)
//                                .font(.system(size: 14))
//                                .padding(.horizontal, 12)
//                                .padding(.vertical, 6)
//                                .background(
//                                    RoundedRectangle(cornerRadius: 20)
//                                        .fill(selectedCategory == category ? primaryColor : Color.gray.opacity(0.1))
//                                )
//                                .foregroundColor(selectedCategory == category ? .white : .gray)
//                        }
//                    }
//                }
//                .padding(.horizontal)
//                .padding(.vertical, 8)
//            }
//
//            if showingFilterMenu {
//                VStack(alignment: .leading, spacing: 12) {
//                    Text("並び替え")
//                        .font(.system(size: 14, weight: .medium))
//                        .foregroundColor(.gray)
//
//                    HStack {
//                        ForEach(["新しい順", "古い順", "価格高い順", "価格安い順", "お気に入り順"], id: \.self) { option in
//                            Button(action: {
//                                sortOption = option
//                                withAnimation {
//                                    showingFilterMenu = false
//                                }
//                            }) {
//                                Text(option)
//                                    .font(.system(size: 12))
//                                    .padding(.horizontal, 8)
//                                    .padding(.vertical, 4)
//                                    .background(
//                                        RoundedRectangle(cornerRadius: 15)
//                                            .stroke(sortOption == option ? primaryColor : Color.gray.opacity(0.3), lineWidth: 1)
//                                            .background(
//                                                RoundedRectangle(cornerRadius: 15)
//                                                    .fill(sortOption == option ? primaryColor.opacity(0.1) : Color.clear)
//                                            )
//                                    )
//                                    .foregroundColor(sortOption == option ? primaryColor : .gray)
//                            }
//                            .padding(.trailing, 4)
//                        }
//                    }
//                    .padding(.bottom, 4)
//                }
//                .padding()
//                .background(cardColor)
//                .cornerRadius(12)
//                .shadow(color: Color.black.opacity(0.05), radius: 3)
//                .padding(.horizontal)
//                .transition(.opacity.combined(with: .move(edge: .top)))
//            }
//
//            // メインコンテンツ
//            if isLoading {
//                // ローディング表示
//                VStack {
//                    Spacer()
//                    ProgressView()
//                        .progressViewStyle(CircularProgressViewStyle())
//                        .scaleEffect(1.2)
//                    Text("読み込み中...")
//                        .font(.system(size: 14))
//                        .foregroundColor(.gray)
//                        .padding(.top, 8)
//                    Spacer()
//                }
//            } else if filteredGoods.isEmpty {
//                // 空の状態表示
//                VStack(spacing: 20) {
//                    Spacer()
//
//                    Image(systemName: "square.grid.2x2")
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: 60, height: 60)
//                        .foregroundColor(.gray.opacity(0.3))
//
//                    VStack(spacing: 8) {
//                        Text("コレクションがありません")
//                            .font(.system(size: 20, weight: .medium))
//                            .foregroundColor(.gray)
//
//                        Text("右下の「+」ボタンから追加できます")
//                            .font(.system(size: 14))
//                            .foregroundColor(.gray.opacity(0.7))
//                            .multilineTextAlignment(.center)
//                    }
//
//                    Button(action: {
//                        addFlag = true
//                        generateHapticFeedback()
//                    }) {
//                        HStack {
//                            Image(systemName: "plus")
//                            Text("アイテムを追加")
//                        }
//                        .font(.system(size: 16, weight: .medium))
//                        .foregroundColor(.white)
//                        .padding(.horizontal, 24)
//                        .padding(.vertical, 12)
//                        .background(
//                            RoundedRectangle(cornerRadius: 25)
//                                .fill(primaryColor)
//                        )
//                    }
//                    .padding(.top, 16)
//
//                    Spacer()
//                    Spacer()
//                }
//                .padding()
//            } else {
//                // コレクション表示
//                ScrollView {
//                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
//                        ForEach(filteredGoods) { item in
//                            NavigationLink(destination: GoodsDetailView(goods: item)) {
//                                VStack(alignment: .leading, spacing: 0) {
//                                    // 画像
//                                    ZStack(alignment: .topTrailing) {
//                                        if let imageUrl = item.imageUrl,
//                                           !imageUrl.isEmpty,
//                                           let url = URL(string: imageUrl) {
//                                            AsyncImage(url: url) { phase in
//                                                if let image = phase.image {
//                                                    image
//                                                        .resizable()
//                                                        .scaledToFill()
//                                                        .frame(width: (UIScreen.main.bounds.width - 40) / 3,
//                                                               height: (UIScreen.main.bounds.width - 40) / 3)
//                                                        .clipped()
//                                                } else {
//                                                    Rectangle()
//                                                        .foregroundColor(.gray.opacity(0.1))
//                                                        .frame(width: (UIScreen.main.bounds.width - 40) / 3,
//                                                               height: (UIScreen.main.bounds.width - 40) / 3)
//                                                        .shimmer(true)
//                                                }
//                                            }
//                                        } else {
//                                            ZStack {
//                                                Rectangle()
//                                                    .foregroundColor(.gray.opacity(0.1))
//                                                    .frame(width: (UIScreen.main.bounds.width - 40) / 3,
//                                                           height: (UIScreen.main.bounds.width - 40) / 3)
//
//                                                Image(systemName: "photo")
//                                                    .font(.system(size: 24))
//                                                    .foregroundColor(.gray)
//                                            }
//                                        }
//
////                                        // お気に入りバッジ
//                                        if let favorite = item.favorite, favorite >= 4 {
//                                            Image(systemName: "star.fill")
//                                                .foregroundColor(.yellow)
//                                                .padding(6)
//                                                .background(Circle().fill(.white))
//                                                .shadow(radius: 1)
//                                                .padding(4)
//                                        }
//                                    }
//
//                                    // 商品情報
//                                    VStack(alignment: .leading, spacing: 2) {
//                                        if let name = item.title, !name.isEmpty {
//                                            Text(name)
//                                                .font(.system(size: 12, weight: .medium))
//                                                .foregroundColor(.black)
//                                                .lineLimit(1)
//                                        }
//
//                                        if let price = item.price {
//                                            Text("¥\(price)")
//                                                .font(.system(size: 11))
//                                                .foregroundColor(.gray)
//                                        }
//                                    }
//                                    .padding(6)
//                                    .frame(width: (UIScreen.main.bounds.width - 40) / 3, alignment: .leading)
//                                    .background(cardColor)
//                                }
//                                .cornerRadius(12)
//                                .shadow(color: Color.black.opacity(0.05), radius: 3)
//                                .padding(.bottom, 6)
//                            }
//                        }
//                    }
//                    .padding(.horizontal)
//                    .padding(.top, 8)
//                    .padding(.bottom, 80) // 下部のボタンのためのスペース
//                }
//            }
//        }
//        .background(backgroundColor)
//        .onAppear {
//            fetchGoods()
//        }
//        .onChange(of: addFlag) { newValue in
//            if !newValue {
//                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                    fetchGoods()
//                }
//            }
//        }
//        .fullScreenCover(isPresented: $addFlag) {
//            GoodsFormView()
//        }
//    }
//
//    func fetchGoods() {
//        guard let userId = userId else { return }
//        self.isLoading = true
//        let ref = Database.database().reference().child("goods").child(userId)
//        ref.observeSingleEvent(of: .value) { snapshot in
//            var newGoods: [Goods] = []
//
//            for child in snapshot.children {
//                if let childSnapshot = child as? DataSnapshot {
//
//                    if let value = childSnapshot.value as? [String: Any] {
//                        do {
//                            let jsonData = try JSONSerialization.data(withJSONObject: value)
//                            let good = try JSONDecoder().decode(Goods.self, from: jsonData)
//                            newGoods.append(good)
//                        } catch {
//                            print("デコードエラー: \(error.localizedDescription)")
//                            print("エラーが発生したデータ: \(value)")
//                        }
//                    }
//                }
//            }
//
//            DispatchQueue.main.async {
//                self.goods = newGoods
//                self.isLoading = false
//                print("fetchGoods 完了", self.goods)
//            }
//        }
//    }
//}
