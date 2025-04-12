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
}

// ユーザーの評価モデル
struct UserRating: Codable {
    var locationId: String
    var rating: Int      // 1～5の評価
    var userId: String?
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
    
    // Realtime Database の参照
    private var db = Database.database().reference()
    private var storage = Storage.storage()
    
    // 全ユーザーのロケーションを読み込む場合の実装
    func fetchLocations() {
        // 「locations」ノードの下に各ユーザー毎に保存されているので全ユーザーノードを巡回する
        db.child("locations").observe(.value) { snapshot in
            var newLocations: [EventLocation] = []
            for userChild in snapshot.children {
                if let userSnap = userChild as? DataSnapshot {
                    for locChild in userSnap.children {
                        if let locSnap = locChild as? DataSnapshot,
                           let dict = locSnap.value as? [String: Any] {
                            do {
                                let jsonData = try JSONSerialization.data(withJSONObject: dict)
                                var location = try JSONDecoder().decode(EventLocation.self, from: jsonData)
                                // 自動生成されたキーを ID として利用
                                location.id = locSnap.key
                                newLocations.append(location)
                            } catch {
                                print("Error decoding location: \(error)")
                            }
                        }
                    }
                }
            }
            self.locations = newLocations.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    // 現在ログイン中のユーザーの ID 直下にロケーションを保存する
    func addLocation(title: String, latitude: Double, longitude: Double, category: String = "その他", initialRating: Int = 0, note: String? = nil, image: UIImage? = nil) {
        // ログインしているユーザーの ID を取得（ログインしていなければ保存しない）
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            return
        }
        
        // 初回評価がある場合の設定
        let ratingSum = initialRating > 0 ? initialRating : 0
        let ratingCount = initialRating > 0 ? 1 : 0
        
        var newLocation = EventLocation(
            title: title,
            latitude: latitude,
            longitude: longitude,
            imageURL: nil,
            category: category,
            ratingSum: ratingSum,
            note: note,
            createdAt: Date()
        )
        
        do {
            // 「locations」直下の該当ユーザー ID ノードに自動生成のキーで保存
            let ref = db.child("locations").child(userId).childByAutoId()
            let locationDict = try newLocation.asDictionary()
            ref.setValue(locationDict) { error, _ in
                if let error = error {
                    print("Error adding location: \(error.localizedDescription)")
                } else {
                    // 初回評価がある場合はユーザー評価も保存
                    if initialRating > 0 {
                        self.saveUserRating(locationId: ref.key ?? "", rating: initialRating, userId: userId)
                    }
                    
                    // 画像がある場合は Firebase Storage にアップロードし、imageURL を更新
                    if let image = image, let imageData = image.jpegData(compressionQuality: 0.7) {
                        let storageRef = self.storage.reference().child("location_images/\(ref.key ?? "no_key").jpg")
                        storageRef.putData(imageData, metadata: nil) { metadata, error in
                            if let error = error {
                                print("Error uploading image: \(error.localizedDescription)")
                                return
                            }
                            
                            storageRef.downloadURL { url, error in
                                if let error = error {
                                    print("Error getting download URL: \(error.localizedDescription)")
                                    return
                                }
                                
                                guard let downloadURL = url else { return }
                                
                                ref.updateChildValues(["imageURL": downloadURL.absoluteString]) { error, _ in
                                    if let error = error {
                                        print("Error updating imageURL: \(error.localizedDescription)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            print("Error converting location to dictionary: \(error.localizedDescription)")
        }
    }
    
    // ユーザーの評価を別テーブル「userRatings」に保存
    func saveUserRating(locationId: String, rating: Int, userId: String) {
        let userRating = UserRating(
            locationId: locationId,
            rating: rating,
            userId: userId
        )
        
        do {
            let ref = db.child("userRatings").childByAutoId()
            let ratingDict = try userRating.asDictionary()
            ref.setValue(ratingDict) { error, _ in
                if let error = error {
                    print("Error saving user rating: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Error converting user rating to dictionary: \(error.localizedDescription)")
        }
    }
    
    // 既存のロケーション評価をトランザクションで更新する
    // oldRating は、ユーザーが既に付けた評価の値として渡します
    func updateRating(for locationId: String, newRating: Int, oldRating: Int) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No user logged in")
            return
        }
        
        // 「locations」直下の全ユーザーノードを巡回して対象のロケーションを検索
        db.child("locations").observeSingleEvent(of: .value) { snapshot in
            for userChild in snapshot.children {
                if let userSnap = userChild as? DataSnapshot {
                    if userSnap.hasChild(locationId) {
                        let locationRef = userSnap.childSnapshot(forPath: locationId).ref
                        locationRef.runTransactionBlock({ currentData -> TransactionResult in
                            if var locationData = currentData.value as? [String: Any],
                               let ratingSum = locationData["ratingSum"] as? Int,
                               let ratingCount = locationData["ratingCount"] as? Int {
                                let newRatingSum = ratingSum - oldRating + newRating
                                locationData["ratingSum"] = newRatingSum
                                currentData.value = locationData
                                return TransactionResult.success(withValue: currentData)
                            }
                            return TransactionResult.success(withValue: currentData)
                        }, andCompletionBlock: { error, committed, snapshot in
                            if let error = error {
                                print("Error updating rating: \(error.localizedDescription)")
                            } else {
                                // 更新後、userRatingsテーブルも更新する
                                self.db.child("userRatings")
                                    .queryOrdered(byChild: "locationId")
                                    .queryEqual(toValue: locationId)
                                    .observeSingleEvent(of: .value) { snapshot in
                                        var ratingFound = false
                                        for child in snapshot.children {
                                            if let childSnapshot = child as? DataSnapshot,
                                               let dict = childSnapshot.value as? [String: Any],
                                               let uid = dict["userId"] as? String,
                                               uid == userId {
                                                childSnapshot.ref.updateChildValues([
                                                    "rating": newRating,
                                                    "timestamp": Date().timeIntervalSince1970
                                                ])
                                                ratingFound = true
                                                break
                                            }
                                        }
                                        if !ratingFound {
                                            self.saveUserRating(locationId: locationId, rating: newRating, userId: userId)
                                        }
                                    }
                            }
                        })
                        break
                    }
                }
            }
        }
    }
    
    // 指定したロケーションに対する、現在のユーザーの評価を取得
    func getUserRating(for locationId: String, completion: @escaping (Int?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        db.child("userRatings")
            .queryOrdered(byChild: "locationId")
            .queryEqual(toValue: locationId)
            .observeSingleEvent(of: .value) { snapshot in
                for child in snapshot.children {
                    if let childSnapshot = child as? DataSnapshot,
                       let dict = childSnapshot.value as? [String: Any],
                       let uid = dict["userId"] as? String,
                       uid == userId,
                       let rating = dict["rating"] as? Int {
                        completion(rating)
                        return
                    }
                }
                completion(nil)
            }
    }
}
