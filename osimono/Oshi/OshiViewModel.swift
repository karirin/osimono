//
//  OshiViewModel.swift
//  osimono
//
//  Created by Apple on 2025/05/13.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseDatabase

// グローバルに共有できるビューモデル
class OshiViewModel: ObservableObject {
    @Published var selectedOshi: Oshi
    static let placeholder = OshiViewModel(oshi: Oshi(id: "placeholder", name: "", imageUrl: nil, backgroundImageUrl: nil, memo: nil, createdAt: nil))
    init(oshi: Oshi) {
        self.selectedOshi = oshi
        // 初期化時に完全なデータを取得
        loadFullData()
    }
    
    private func loadFullData() {
           guard let userID = Auth.auth().currentUser?.uid else { return }
           
           let oshiRef = Database.database().reference().child("oshis").child(userID).child(selectedOshi.id)
           oshiRef.observeSingleEvent(of: .value) { [weak self] snapshot in
               guard let self = self, let data = snapshot.value as? [String: Any] else { return }
               
               // 新しいOshiオブジェクトを作成して全プロパティを設定
               var newOshi = self.selectedOshi
               
               // 全てのプロパティを設定
               newOshi.personality = data["personality"] as? String
               newOshi.speaking_style = data["speaking_style"] as? String
               newOshi.birthday = data["birthday"] as? String
               newOshi.hometown = data["hometown"] as? String
               newOshi.favorite_color = data["favorite_color"] as? String
               newOshi.favorite_food = data["favorite_food"] as? String
               newOshi.disliked_food = data["disliked_food"] as? String
               newOshi.interests = data["interests"] as? [String]
               newOshi.gender = data["gender"] as? String
               newOshi.height = data["height"] as? Int
               
               DispatchQueue.main.async {
                   self.selectedOshi = newOshi
               }
           }
       }
    
    func updateOshi(_ newOshi: Oshi) {
         DispatchQueue.main.async {
             self.selectedOshi = newOshi
             self.objectWillChange.send()
         }
     }
    
    // Firebase からデータを読み込む
    private func loadOshiData() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        // ロード中フラグを設定（オプション）
        // self.isUpdatingData = true
        
        let dbRef = Database.database().reference().child("oshis").child(userID).child(selectedOshi.id)
        dbRef.observeSingleEvent(of: .value) { snapshot in
            guard let data = snapshot.value as? [String: Any] else {
                print("データが取得できませんでした")
                // self.isUpdatingData = false
                return
            }
            
            // 完全に新しいオブジェクトを作成
            var newOshi = Oshi(
                id: self.selectedOshi.id,
                name: data["name"] as? String ?? self.selectedOshi.name,
                imageUrl: data["imageUrl"] as? String ?? self.selectedOshi.imageUrl,
                backgroundImageUrl: data["backgroundImageUrl"] as? String,
                memo: data["memo"] as? String,
                createdAt: data["createdAt"] as? TimeInterval ?? self.selectedOshi.createdAt
            )
            
            // すべてのプロパティを設定
            newOshi.personality = data["personality"] as? String
            newOshi.speaking_style = data["speaking_style"] as? String
            newOshi.birthday = data["birthday"] as? String
            newOshi.hometown = data["hometown"] as? String
            newOshi.favorite_color = data["favorite_color"] as? String
            newOshi.favorite_food = data["favorite_food"] as? String
            newOshi.disliked_food = data["disliked_food"] as? String
            newOshi.interests = data["interests"] as? [String]
            newOshi.gender = data["gender"] as? String
            newOshi.height = data["height"] as? Int
            
            DispatchQueue.main.async {
                print("更新前: \(self.selectedOshi.personality ?? "なし")")
                print("更新データ: \(newOshi.personality ?? "なし")")
                // UIを更新
                self.selectedOshi = newOshi
                print("更新後: \(self.selectedOshi.personality ?? "なし")")
                // self.isUpdatingData = false
                
                // このデータ更新を確実に反映させるために、State更新フラグなどを設定
                // self.dataUpdateCounter += 1  // このような更新カウンターを用意しておくと便利
            }
        }
    }
    
    // Firebase に保存する
    func saveOshiData(_ updatedOshi: Oshi, completion: @escaping (Error?) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "OshiViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "ユーザーIDが取得できません"]))
            return
        }
        
        let dbRef = Database.database().reference().child("oshis").child(userID).child(updatedOshi.id)
        
        // 保存するデータを作成
        var data: [String: Any] = [
            "name": updatedOshi.name,
        ]
        
        // オプションのプロパティを追加
        if let personality = updatedOshi.personality {
            data["personality"] = personality
        }
        
        if let speaking_style = updatedOshi.speaking_style {
            data["speaking_style"] = speaking_style
        }
        
        if let favorite_food = updatedOshi.favorite_food {
            data["favorite_food"] = favorite_food
        }
        
        if let disliked_food = updatedOshi.disliked_food {
            data["disliked_food"] = disliked_food
        }
        
        if let interests = updatedOshi.interests {
            data["interests"] = interests
        }
        
        if let gender = updatedOshi.gender {
            data["gender"] = gender
        }
        
        // Firebase に保存
        dbRef.updateChildValues(data) { error, _ in
            if let error = error {
                completion(error)
                return
            }
            
            // 保存成功後、ローカルのモデルも更新
            DispatchQueue.main.async {
                self.selectedOshi = updatedOshi
                completion(nil)
            }
        }
    }
}
