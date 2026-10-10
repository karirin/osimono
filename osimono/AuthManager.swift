//
//  AuthManager.swift
//  osimono
//
//  Created by Apple on 2025/03/20.
//

import SwiftUI
import Firebase
import FirebaseAuth

class AuthManager: ObservableObject {
    @Published var user: FirebaseAuth.User? {
        willSet {
            objectWillChange.send()
        }
    }
    var onLoginCompleted: (() -> Void)?
    /// 匿名ログインに失敗した（オフライン等）。起動画面で再試行を案内する
    @Published var signInFailed = false
    
    // AuthManager は画面ごとに作られるため、同時に複数の匿名アカウントを作らないようアプリ全体で1つだけ実行する
    private static var isSigningIn = false
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var retryWorkItem: DispatchWorkItem?
    
    init() {
        user = Auth.auth().currentUser
        // 別インスタンスでのログイン完了も反映する
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if self.user?.uid != user?.uid {
                self.user = user
            }
            if user != nil {
                self.signInFailed = false
            }
        }
        if user == nil {
            signInAnonymously()
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        retryWorkItem?.cancel()
    }
    
    var currentUserId: String? {
        return user?.uid
//        return "h00DJESlqpPmGWzZKgMIMyxeDqo1"
    }
    
    func signInAnonymously() {
        retryWorkItem?.cancel()
        guard Auth.auth().currentUser == nil else {
            user = Auth.auth().currentUser
            return
        }
        if Self.isSigningIn {
            print("既にサインイン処理中です")
            return
        }
        Self.isSigningIn = true
        Auth.auth().signInAnonymously { [weak self] authResult, error in
            DispatchQueue.main.async {
                Self.isSigningIn = false
                if let error = error {
                    print("匿名ログインエラー: \(error.localizedDescription)")
                    self?.signInFailed = true
                    self?.scheduleRetry()
                    return
                }
                
                // ログイン成功
                self?.signInFailed = false
                self?.user = authResult?.user
                print("匿名ユーザーとしてログインしました: \(authResult?.user.uid ?? "")")
                self?.onLoginCompleted?()
            }
        }
    }
    
    /// 通信が戻ったときに自動でログインできるよう、少し待って再試行する
    private func scheduleRetry() {
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.user == nil else { return }
            self.signInAnonymously()
        }
        retryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }
    
    func fetchUserFlag(completion: @escaping (Int?, Error?) -> Void) {
        guard let userId = user?.uid else {
            // ユーザーIDがnilの場合、すなわちログインしていない場合
            let error = NSError(domain: "AuthManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "ログインしていません。"])
            completion(nil, error)
            return
        }

        let userRef = Database.database().reference().child("users").child(userId)
        // "userFlag"の値を取得する
        userRef.child("userFlag").observeSingleEvent(of: .value) { snapshot in
            if let userFlag = snapshot.value as? Int {
                // userFlagが存在し、Int型として取得できた場合
                DispatchQueue.main.async {
                    completion(userFlag, nil)
                }
            } else {
                // userFlagが存在しない場合は0を返す
                DispatchQueue.main.async {
                    completion(0, nil)
                }
            }
        } withCancel: { error in
            // データベースの読み取りに失敗した場合
            DispatchQueue.main.async {
                completion(nil, error)
            }
        }
    }
    
    func anonymousSignIn(completion: @escaping () -> Void) {
        Auth.auth().signInAnonymously { result, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            } else if let result = result {
                print("Signed in anonymously with user ID: \(result.user.uid)")
                self.onLoginCompleted?()
            }
            completion()
        }
    }
    
    func updateUserCsFlag(userId: String, userCsFlag: Int, completion: @escaping (Bool) -> Void) {
        let userRef = Database.database().reference().child("users").child(userId)
        let updates = ["userCsFlag": userCsFlag]
        print(updates)
        userRef.updateChildValues(updates) { (error, _) in
            if let error = error {
                print("Error updating tutorialNum: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    func updateContact(userId: String, newContact: String, completion: @escaping (Bool) -> Void) {
        // contactテーブルの下の指定されたuserIdの参照を取得
        let contactRef = Database.database().reference().child("contacts").child(userId)
        // まず現在のcontactの値を読み取る
        contactRef.observeSingleEvent(of: .value, with: { snapshot in
            // 既存の問い合わせ内容を保持する変数を準備
            var contacts: [String] = []
            
            // 現在の問い合わせ内容がある場合、それを読み込む
            if let currentContacts = snapshot.value as? [String] {
                contacts = currentContacts
            }
            
            // 新しい問い合わせ内容をリストに追加
            contacts.append(newContact)
            
            // データベースを更新する
            contactRef.setValue(contacts, withCompletionBlock: { error, _ in
                if let error = error {
                    print("Error updating contact: \(error)")
                    completion(false)
                } else {
                    completion(true)
                }
            })
        }) { error in
            print(error.localizedDescription)
            completion(false)
        }
    }
    
    func createUserRecord(completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("ユーザーがログインしていません")
            completion(false)
            return
        }
        let userRecord: [String: Any] = [
            "uid": uid,
            "createdAt": ServerValue.timestamp(),
            "userFlag": 0  // 必要に応じて初期値を設定
        ]
        let usersRef = Database.database().reference().child("users").child(uid)
        usersRef.setValue(userRecord) { error, _ in
            if let error = error {
                print("ユーザーレコード作成エラー: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    
    func updateUserFlag(userId: String, userFlag: Int, completion: @escaping (Bool) -> Void) {
        let userRef = Database.database().reference().child("users").child(userId)
        let updates = ["userFlag": userFlag]
        userRef.updateChildValues(updates) { (error, _) in
            if let error = error {
                print("Error updating tutorialNum: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
}

struct AuthManager1: View {
    @ObservedObject var authManager = AuthManager()
    
    var body: some View {
        VStack {
            Button(action: {
                generateHapticFeedback()
                authManager.createUserRecord { success in
                    if success {
                        print("ユーザーレコードが正常に作成されました。")
                    } else {
                        print("ユーザーレコードの作成に失敗しました。")
                    }
                }
            }) {
                Text("ユーザーレコード作成")
            }
            if authManager.user == nil {
                Text("Not logged in")
            } else {
                Text("Logged in with user ID: \(authManager.user!.uid)")
            }
            Button(action: {
                if self.authManager.user == nil {
                    self.authManager.anonymousSignIn(){}
                }
            }) {
                Text("Log in anonymously")
            }
        }
    }
}

struct AuthManager_Previews: PreviewProvider {
    static var previews: some View {
        AuthManager1()
    }
}
