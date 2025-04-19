//
//  LocationManager.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth
import MapKit
import FirebaseStorage
import FirebaseDatabase  // Firestoreの代わりにRealtime Databaseを利用

// MARK: - モデル定義

// イベント・ロケーションのモデル（Realtime DatabaseではドキュメントIDの代わりにキーを利用）
struct EventLocation: Identifiable, Codable {
    var id: String?
    var title: String
    var latitude: Double
    var longitude: Double
    var imageURL: String?
    var category: String
    var ratingSum: Int = 0
    var note: String?
    var createdAt: Date = Date()
    var oshiId: String? // 推しID追加
}

// ユーザーの評価モデル
struct UserRating: Codable {
    var locationId: String
    var rating: Int      // 1～5の評価
    var userId: String?
    var oshiId: String?  // 推しIDを追加
    var timestamp: Date = Date()
}

// EncodableなモデルをDictionaryに変換する拡張
extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        let dict = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
        return dict as? [String: Any] ?? [:]
    }
}

// MARK: - 位置情報管理クラス

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocation?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    // 位置情報更新時の処理
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            userLocation = location
            // 1回のみ取得する場合はここで停止させる
            manager.stopUpdatingLocation()
        }
    }
    
    // 位置情報取得失敗時の処理
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }
}

// MARK: - ロケーションデータの管理（Realtime Database版）

class LocationViewModel: ObservableObject {
    @Published var locations: [EventLocation] = []
    @Published var currentOshiId: String = "default"
    
    // Realtime Database の参照
    private var db = Database.database().reference()
    private var storage = Storage.storage()
    
    // 全ユーザーのロケーションを読み込む場合の実装
    func fetchLocations(forOshiId oshiId: String = "default") {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // ユーザーID → 推しID → 投稿ID という階層構造でデータを取得
        let locationsRef = db.child("locations").child(userId).child(oshiId)
        
        locationsRef.observe(.value) { snapshot in
            var newLocations: [EventLocation] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let dict = childSnapshot.value as? [String: Any] {
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: dict)
                        var location = try JSONDecoder().decode(EventLocation.self, from: jsonData)
                        location.id = childSnapshot.key
                        location.oshiId = oshiId  // 明示的に推しIDを設定
                        newLocations.append(location)
                    } catch {
                        print("Error decoding location: \(error)")
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.locations = newLocations.sorted { $0.createdAt > $1.createdAt }
            }
        }
    }
    
    // 現在ログイン中のユーザーの ID 直下にロケーションを保存する
    func addLocation(title: String, latitude: Double, longitude: Double, category: String = "その他",
                     initialRating: Int = 0, note: String? = nil, image: UIImage? = nil,
                     completion: @escaping (String?) -> Void = {_ in }) {
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            completion(nil)
            return
        }
        
        let ratingSum = initialRating > 0 ? initialRating : 0
        
        var newLocation = EventLocation(
            title: title,
            latitude: latitude,
            longitude: longitude,
            imageURL: nil,
            category: category,
            ratingSum: ratingSum,
            note: note,
            createdAt: Date(),
            oshiId: currentOshiId
        )
        
        do {
            // ユーザーID → 推しID → 投稿ID という階層構造で保存
            let ref = db.child("locations").child(userId).child(currentOshiId).childByAutoId()
            let locationDict = try newLocation.asDictionary()
            
            ref.setValue(locationDict) { error, _ in
                if let error = error {
                    print("Error adding location: \(error.localizedDescription)")
                    completion(nil)
                } else {
                    // Return the newly created location ID
                    let newLocationId = ref.key
                    
                    // 初回評価がある場合はユーザー評価も保存
                    if initialRating > 0 {
                        self.saveUserRating(locationId: newLocationId ?? "", rating: initialRating, userId: userId, oshiId: self.currentOshiId)
                    }
                    
                    // 画像がある場合は Firebase Storage にアップロード
                    if let image = image, let imageData = image.jpegData(compressionQuality: 0.7) {
                        let imagePath = "location_images/\(userId)/\(self.currentOshiId)/\(newLocationId ?? "no_key").jpg"
                        let storageRef = self.storage.reference().child(imagePath)
                        
                        storageRef.putData(imageData, metadata: nil) { metadata, error in
                            if let error = error {
                                print("Error uploading image: \(error.localizedDescription)")
                                completion(newLocationId)
                                return
                            }
                            
                            storageRef.downloadURL { url, error in
                                if let error = error {
                                    print("Error getting download URL: \(error.localizedDescription)")
                                    completion(newLocationId)
                                    return
                                }
                                
                                guard let downloadURL = url else {
                                    completion(newLocationId)
                                    return
                                }
                                
                                ref.updateChildValues(["imageURL": downloadURL.absoluteString]) { error, _ in
                                    if let error = error {
                                        print("Error updating imageURL: \(error.localizedDescription)")
                                    }
                                    completion(newLocationId)
                                }
                            }
                        }
                    } else {
                        completion(newLocationId)
                    }
                }
            }
        } catch {
            print("Error converting location to dictionary: \(error.localizedDescription)")
            completion(nil)
        }
    }
    
    // ユーザーの評価を別テーブル「userRatings」に保存
    func saveUserRating(locationId: String, rating: Int, userId: String, oshiId: String) {
        let userRating = UserRating(
            locationId: locationId,
            rating: rating,
            userId: userId,
            oshiId: oshiId  // 推しIDを追加
        )
        
        do {
            // userRatingsの下にもユーザーID→推しID構造を作る
//            let ref = db.child("userRatings").child(userId).child(oshiId).childByAutoId()
//            let ratingDict = try userRating.asDictionary()
//            ref.setValue(ratingDict) { error, _ in
//                if let error = error {
//                    print("Error saving user rating: \(error.localizedDescription)")
//                }
//            }
        } catch {
            print("Error converting user rating to dictionary: \(error.localizedDescription)")
        }
    }
    
    // 既存のロケーション評価をトランザクションで更新する
    // oldRating は、ユーザーが既に付けた評価の値として渡します
    func updateRating(for locationId: String, newRating: Int, oldRating: Int, oshiId: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No user logged in")
            return
        }
        
        // ユーザーID→推しID→locationIdの構造で直接アクセス
        let locationRef = db.child("locations").child(userId).child(oshiId).child(locationId)
        
        locationRef.runTransactionBlock({ currentData -> TransactionResult in
            if var locationData = currentData.value as? [String: Any],
               let ratingSum = locationData["ratingSum"] as? Int {
                let newRatingSum = ratingSum - oldRating + newRating
                locationData["ratingSum"] = newRatingSum
                currentData.value = locationData
                return TransactionResult.success(withValue: currentData)
            }
            return TransactionResult.success(withValue: currentData)
        }) { error, committed, snapshot in
            if let error = error {
                print("Error updating rating: \(error.localizedDescription)")
            } else {
                // userRatingsの更新も階層構造に対応
//                self.db.child("userRatings").child(userId).child(oshiId)
//                    .queryOrdered(byChild: "locationId")
//                    .queryEqual(toValue: locationId)
//                    .observeSingleEvent(of: .value) { snapshot in
//                        var ratingFound = false
//                        for child in snapshot.children {
//                            if let childSnapshot = child as? DataSnapshot {
//                                childSnapshot.ref.updateChildValues([
//                                    "rating": newRating,
//                                    "timestamp": Date().timeIntervalSince1970
//                                ])
//                                ratingFound = true
//                                break
//                            }
//                        }
//                        if !ratingFound {
//                            self.saveUserRating(locationId: locationId, rating: newRating, userId: userId, oshiId: oshiId)
//                        }
//                    }
            }
        }
    }
    
    // 指定したロケーションに対する、現在のユーザーの評価を取得
    func getUserRating(for locationId: String, oshiId: String, completion: @escaping (Int?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        
//        db.child("userRatings").child(userId).child(oshiId)
//            .queryOrdered(byChild: "locationId")
//            .queryEqual(toValue: locationId)
//            .observeSingleEvent(of: .value) { snapshot in
//                for child in snapshot.children {
//                    if let childSnapshot = child as? DataSnapshot,
//                       let dict = childSnapshot.value as? [String: Any],
//                       let rating = dict["rating"] as? Int {
//                        completion(rating)
//                        return
//                    }
//                }
//                completion(nil)
//            }
    }
    
    func updateCurrentOshi(id: String) {
        currentOshiId = id
        fetchLocations(forOshiId: id)
    }

//    func fetchLocations(forOshiId oshiId: String = "default") {
//        db.child("locations").observe(.value) { snapshot in
//            var newLocations: [EventLocation] = []
//            for userChild in snapshot.children {
//                if let userSnap = userChild as? DataSnapshot {
//                    for locChild in userSnap.children {
//                        if let locSnap = locChild as? DataSnapshot,
//                           let dict = locSnap.value as? [String: Any] {
//                            do {
//                                let jsonData = try JSONSerialization.data(withJSONObject: dict)
//                                var location = try JSONDecoder().decode(EventLocation.self, from: jsonData)
//                                location.id = locSnap.key
//                                
//                                // 推しIDでフィルタリング
//                                if location.oshiId == oshiId || location.oshiId == nil {
//                                    newLocations.append(location)
//                                }
//                            } catch {
//                                print("Error decoding location: \(error)")
//                            }
//                        }
//                    }
//                }
//            }
//            self.locations = newLocations.sorted { $0.createdAt > $1.createdAt }
//        }
//    }
}
