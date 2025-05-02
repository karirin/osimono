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
    private var isSigningIn = false
    
    init() {
        user = Auth.auth().currentUser
        if user == nil {
            signInAnonymously()
        } else {
            print("既存の匿名ユーザーを使用します: \(user?.uid ?? "")")
        }
    }
    
    var currentUserId: String? {
        print("user?.uid:\(user?.uid)")
        return user?.uid
    }
    
    func signInAnonymously() {
        if isSigningIn {
            print("既にサインイン処理中です")
            return
        }
        isSigningIn = true
        Auth.auth().signInAnonymously { [weak self] authResult, error in
            DispatchQueue.main.async {
                self?.isSigningIn = false
                if let error = error {
                    print("匿名ログインエラー: \(error.localizedDescription)")
                    return
                }
                
                // ログイン成功
                self?.user = authResult?.user
                print("匿名ユーザーとしてログインしました: \(authResult?.user.uid ?? "")")
                self?.onLoginCompleted?()
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
