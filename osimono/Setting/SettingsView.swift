import SwiftUI
import Firebase
import FirebaseAuth
import WebKit
import StoreKit
import SwiftyCrop
import FirebaseStorage

func generateHapticFeedback() {
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
}

//enum UploadImageType: Identifiable {
//    case profile
//    case background
//    
//    var id: Self { self }
//}

struct SettingsView: View {
    @State private var username: String = "推し活ユーザー"
    @State private var favoriteOshi: String = ""
    @State private var isShowingImagePicker = false
    @State private var isShowingLogoutAlert = false
    @ObservedObject var authManager = AuthManager()
    @State private var selectedOshi: Oshi? = nil
    
    // For bug reporting and App Store review
    @State private var showingBugReportForm = false
    @State private var showingReviewConfirmation = false
    @Environment(\.requestReview) private var requestReview
    
    @Environment(\.colorScheme) private var colorScheme
    
    // 色の定義を動的に変更
    var primaryColor: Color { Color(.systemPink) } // そのまま使用可能
    var accentColor: Color { Color(.purple) } // そのまま使用可能
    var backgroundColor: Color { colorScheme == .dark ? Color(.systemBackground) : Color(.white) }
    var cardColor: Color { colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.white) }
    var textColor: Color { colorScheme == .dark ? Color(.white) : Color(.black) }
    
    @State private var showingNotificationSettings = false
    @State private var showingPrivacySettings = false
    @State private var showingShareSettings = false
    
    // おすすめアプリの表示状態
    @State private var showingRecommendedApp1 = false
    @State private var showingRecommendedApp2 = false
    
    @State private var isShowingEditOshiView = false
    
    @State private var profileImage: UIImage?
    @State private var backgroundImage: UIImage?
    @State private var currentEditType: UploadImageType? = nil
    @State private var showImagePicker = false
    
    @State private var oshiList: [Oshi] = []
    // URLスキームを開くための環境変数
    @Environment(\.openURL) private var openURL
    
    @Binding var oshiChange: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // ヘッダー
                    Text("設定")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(primaryColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    VStack(spacing: 10) {
                        HStack {
                            Text("推しを編集")
                                .foregroundColor(.secondary)
                                .frame(alignment: .leading)
                            Spacer()
                        }.padding(.leading)
                        
                        VStack(spacing: 15) {
                            HStack {
                                // プロフィール画像
//                                Button(action: {
//                                    generateHapticFeedback()
//                                    isShowingEditOshiView = true
//                                }) {
                                    if let image = profileImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(primaryColor, lineWidth: 2)
                                            )
                                    } else {
                                        Circle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 60, height: 60)
                                            .overlay(
                                                Image(systemName: "person.circle.fill")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 30)
                                                    .foregroundColor(primaryColor)
                                            )
                                    }
//                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(username)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("アイコンをタップして変更")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .padding()
                        .background(cardColor)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                        .onTapGesture{
                            generateHapticFeedback()
                            isShowingEditOshiView = true
                        }
                    }
                    
                    VStack(spacing:10){
                        HStack{
                            Text("フィードバック")
                                .foregroundColor(.secondary)
                                .frame(alignment: .leading)
                            Spacer()
                        }.padding(.leading)
                        VStack(spacing: 15) {
                            
                            // 不具合報告
                            SettingRow(
                                icon: "exclamationmark.bubble",
                                title: "バグ・ご意見を報告",
                                color: .red,
                                action: { showingBugReportForm = true }
                            )
                            
                            // アプリレビュー
                            SettingRow(
                                icon: "star.fill",
                                title: "アプリを評価する",
                                color: .yellow,
                                action: {
                                    generateHapticFeedback()
                                    showingReviewConfirmation = true
                                }
                            )
                        }
                        .padding()
                        .background(cardColor)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                    
                    // おすすめアプリカード
                    VStack(spacing:10){
                        HStack{
                            Text("おすすめのアプリ")
                                .foregroundColor(.secondary)
                                .frame(alignment: .leading)
                            Spacer()
                        }.padding(.leading)
                        VStack(spacing: 0) {
                            // おすすめアプリ1
                            Button(action: {
                                generateHapticFeedback()
                                if let url = URL(string: "https://apps.apple.com/us/app/it%E3%82%AF%E3%82%A8%E3%82%B9%E3%83%88-it%E3%83%91%E3%82%B9%E3%83%9D%E3%83%BC%E3%83%88%E3%81%AB%E5%90%88%E6%A0%BC%E3%81%A7%E3%81%8D%E3%82%8B%E3%82%A2%E3%83%97%E3%83%AA/id6469339499") {
                                    openURL(url)
                                }
                            }) {
                                HStack(alignment: .center, spacing: 15) {
                                    // アプリアイコン画像
                                    ZStack {
                                        Image("ITクエスト")
                                            .resizable()
                                            .frame(width:60,height: 60)
                                            .cornerRadius(10)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("ITクエスト")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Text("ゲーム感覚でITパスポートに合格できるアプリ")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal)
                            }
                            
                            Divider()
                                .padding(.horizontal)
                            
                            Button(action: {
                                generateHapticFeedback()
                                if let url = URL(string: "https://apps.apple.com/us/app/%E3%83%89%E3%83%AA%E3%83%AB%E3%82%AF%E3%82%A8%E3%82%B9%E3%83%88-%E5%B0%8F%E5%AD%A6%E7%94%9F%E3%81%AE%E5%AD%A6%E7%BF%92%E3%82%A2%E3%83%97%E3%83%AA/id6711333088") {
                                    openURL(url)
                                }
                            }) {
                                HStack(alignment: .center, spacing: 15) {
                                    // アプリアイコン画像
                                    ZStack {
                                        Image("ドリルクエスト")
                                            .resizable()
                                            .frame(width:60,height: 60)
                                            .cornerRadius(10)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("ドリルクエスト")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Text("ゲーム感覚で小学校レベルの勉強ができるアプリ")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal)
                            }
                            
                            Divider()
                                .padding(.horizontal)
                            // おすすめアプリ2
                            Button(action: {
                                generateHapticFeedback()
                                if let url = URL(string: "https://apps.apple.com/us/app/%E3%83%A1%E3%82%A4%E3%82%AFtodo-%E8%87%AA%E5%88%86%E5%A5%BD%E3%81%BF%E3%81%AB%E3%82%AB%E3%82%B9%E3%82%BF%E3%83%9E%E3%82%A4%E3%82%BA%E3%81%A7%E3%81%8D%E3%82%8Btodo%E3%82%A2%E3%83%97%E3%83%AA/id6741789561") {
                                    openURL(url)
                                }
                            }) {
                                HStack(alignment: .center, spacing: 15) {
                                    // アプリアイコン画像
                                    ZStack {
                                        Image("メイクToDo")
                                            .resizable()
                                            .frame(width:60,height: 60)
                                            .cornerRadius(10)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("メイクToDo")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Text("自分好みにカスタマイズできるToDoアプリ")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal)
                            }
                            
                            Divider()
                                .padding(.horizontal)
                            
                            // おすすめアプリ3
                            Button(action: {
                                generateHapticFeedback()
                                if let url = URL(string: "https://apps.apple.com/us/app/%E3%82%B5%E3%83%A9%E3%83%AA%E3%83%BC-%E3%81%8A%E7%B5%A6%E6%96%99%E7%AE%A1%E7%90%86%E3%82%A2%E3%83%97%E3%83%AA/id6670354348") {
                                    openURL(url)
                                }
                            }) {
                                HStack(alignment: .center, spacing: 15) {
                                    // アプリアイコン画像
                                    ZStack {
                                        Image("サラリー｜お給料管理アプリ")
                                            .resizable()
                                            .frame(width:60,height: 60)
                                            .cornerRadius(10)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("サラリー")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Text("給料日までの給与が確認できる仕事のモチベーション管理アプリ")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal)
                            }
                        }
                        .background(cardColor)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                    
                    VStack(spacing:10){
                        HStack{
                            Text("アプリについて")
                                .foregroundColor(.secondary)
                                .frame(alignment: .leading)
                            Spacer()
                        }.padding(.leading)
                        VStack(spacing: 15) {
                            
                            // 各設定項目にアクションを追加
                            SettingRow(
                                icon: "doc.text.fill",
                                title: "利用規約",
                                color: .green,
                                action: { showingShareSettings = true }
                            )
                            
                            SettingRow(
                                icon: "lock.fill",
                                title: "プライバシーポリシー",
                                color: .orange,
                                action: { showingPrivacySettings = true }
                            )
                            
                            HStack {
                                Image(systemName: "wrench.adjustable")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 20))
                                
                                Text("アプリのバージョン")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("1.0.0")
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 8)
                        }
                        .padding()
                        .background(cardColor)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                    }
                }
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationDestination(isPresented: $showingNotificationSettings) {
                WebView(urlString: "https://docs.google.com/forms/d/e/1FAIpQLSfHxhubkEjUw_gexZtQGU8ujZROUgBkBcIhB3R6b8KZpKtOEQ/viewform?embedded=true")
            }
            .navigationDestination(isPresented: $showingPrivacySettings) {
                PrivacyView()
            }
            .navigationDestination(isPresented: $showingShareSettings) {
                TermsOfServiceView()
            }
            .navigationDestination(isPresented: $showingBugReportForm) {
                BugReportView()
            }
        }
        .onAppear {
            fetchOshiList()
            loadSelectedOshi()
        }
        .fullScreenCover(isPresented: $isShowingEditOshiView, onDismiss: {
            fetchOshiList()
            loadSelectedOshi()
            oshiChange.toggle()
        }) {
            if let oshi = selectedOshi {
                EditOshiView(oshi: oshi) {
                    fetchOshiList()
                    loadSelectedOshi()
                }
            }
        }
        .alert(isPresented: $isShowingLogoutAlert) {
            Alert(
                title: Text("ログアウト"),
                message: Text("本当にログアウトしますか？"),
                primaryButton: .destructive(Text("ログアウト")) {
                    logout()
                },
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
        .alert(isPresented: $showingReviewConfirmation) {
            Alert(
                title: Text("アプリを評価"),
                message: Text("App Storeでこのアプリを評価しますか？"),
                primaryButton: .default(Text("評価する")) {
                    // StoreKit 2.0のレビュー要求機能を呼び出す
                    requestReview()
                    
                    // または、App Storeのレビューページに直接移動
                    if let writeReviewURL = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID?action=write-review") {
                        openURL(writeReviewURL)
                    }
                },
                secondaryButton: .cancel(Text("後で"))
            )
        }
    }
    
//    func fetchOshiList() {
//        guard let userId = Auth.auth().currentUser?.uid else { return }
//        let ref = Database.database().reference().child("oshis").child(userId)
//        
//        ref.observeSingleEvent(of: .value) { snapshot in
//            var newOshis: [Oshi] = []
//            
//            for child in snapshot.children {
//                if let childSnapshot = child as? DataSnapshot {
//                    if let value = childSnapshot.value as? [String: Any] {
//                        let id = childSnapshot.key
//                        let name = value["name"] as? String ?? "名前なし"
//                        let imageUrl = value["imageUrl"] as? String
//                        let backgroundImageUrl = value["backgroundImageUrl"] as? String
//                        let memo = value["memo"] as? String
//                        let createdAt = value["createdAt"] as? TimeInterval
//                        
//                        let oshi = Oshi(
//                            id: id,
//                            name: name,
//                            imageUrl: imageUrl,
//                            backgroundImageUrl: backgroundImageUrl,
//                            memo: memo,
//                            createdAt: createdAt
//                        )
//                        newOshis.append(oshi)
//                    }
//                }
//            }
//            
//            DispatchQueue.main.async {
//                self.oshiList = newOshis
//            }
//        }
//    }
    
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
                        
                        let oshi = Oshi(
                            id: id,
                            name: name,
                            imageUrl: imageUrl,
                            backgroundImageUrl: backgroundImageUrl, // ここで追加
                            memo: memo,
                            createdAt: createdAt
                        )
                        print("fetchOshiList!!!!!!!")
                        newOshis.append(oshi)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.oshiList = newOshis
                self.loadSelectedOshi()
            }
        }
    }
    
    func loadSelectedOshi() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else { return }
            
            if let selectedOshiId = value["selectedOshiId"] as? String {
                // 選択中の推しIDが存在する場合、oshiListから該当する推しを検索して設定
                if let oshi = self.oshiList.first(where: { $0.id == selectedOshiId }) {
                    self.selectedOshi = oshi
                    self.username = oshi.name
                    if let profileImageUrl = oshi.imageUrl as? String,
                        let url = URL(string: profileImageUrl) {
                            loadImage(from: url) { image in
                                profileImage = image
                            }
                      }
                }
            }
        }
    }

    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("画像読み込みエラー: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }.resume()
    }
    // ログアウト
    func logout() {
        do {
            try Auth.auth().signOut()
            //            authManager.isLoggedIn = false
        } catch {
            print("ログアウトエラー: \(error.localizedDescription)")
        }
    }
}

struct WebView: UIViewRepresentable {
    let urlString: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
    }
}

// 設定行
struct SettingRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void  // アクションを追加
    
    var body: some View {
        Button(action: {
            generateHapticFeedback()  // タップ時の触覚フィードバック
            action()  // 設定されたアクションを実行
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 20))
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
            }
            .padding(.vertical, 8)
        }
    }
}

#Preview{
    SettingsView(oshiChange: .constant(false))
}
