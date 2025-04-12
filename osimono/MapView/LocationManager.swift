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
    var userId: String?
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
    
    // FirestoreではなくRealtime Databaseの参照を取得する
    private var db = Database.database().reference()
    private var storage = Storage.storage()
    
    // Realtime Databaseからロケーションデータを取得するメソッド
    func fetchLocations() {
        db.child("locations").observe(.value) { snapshot in
            var newLocations: [EventLocation] = []
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let dict = childSnapshot.value as? [String: Any] {
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: dict)
                        var location = try JSONDecoder().decode(EventLocation.self, from: jsonData)
                        // Realtime DatabaseではキーがIDとして利用されるため、ここでセットする
                        location.id = childSnapshot.key
                        newLocations.append(location)
                    } catch {
                        print("Error decoding location: \(error)")
                    }
                }
            }
            // createdAtで降順にソート
            self.locations = newLocations.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    // 新しいロケーションをRealtime Databaseに追加するメソッド
    func addLocation(title: String, latitude: Double, longitude: Double, category: String = "その他", initialRating: Int = 0, note: String? = nil, image: UIImage? = nil) {
        let userId = Auth.auth().currentUser?.uid
        
        // 初期評価の設定
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
            userId: userId
        )
        
        do {
            // childByAutoId()で自動生成されたキーで新しいロケーションを追加
            let ref = db.child("locations").childByAutoId()
            let locationDict = try newLocation.asDictionary()
            ref.setValue(locationDict) { error, _ in
                if let error = error {
                    print("Error adding location: \(error.localizedDescription)")
                } else {
                    // 追加成功時に評価を保存する（初期評価がある場合）
                    if initialRating > 0, let userId = userId {
                        self.saveUserRating(locationId: ref.key ?? "", rating: initialRating, userId: userId)
                    }
                    
                    // 画像がある場合はFirebase Storageにアップロードする
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
                                
                                // imageURLの更新はupdateChildValuesを利用
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
    
    // ユーザーの評価をRealtime Databaseに保存するメソッド
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
    
    // 既存のロケーション評価をRealtime Databaseのトランザクションで更新するメソッド
    // oldRatingは既存の評価値。newRatingは変更後の評価値として渡してください。
    func updateRating(for locationId: String, newRating: Int, oldRating: Int) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No user logged in")
            return
        }
        
        let locationRef = db.child("locations").child(locationId)
        
        locationRef.runTransactionBlock({ currentData -> TransactionResult in
            if var locationData = currentData.value as? [String: Any],
               let ratingSum = locationData["ratingSum"] as? Int{
                // 古い評価を差し引き、新しい評価を加える更新
                let newRatingSum = ratingSum - oldRating + newRating
                locationData["ratingSum"] = newRatingSum
                // ここでは評価の件数は変更しない（初回評価の更新と仮定）
                currentData.value = locationData
                return TransactionResult.success(withValue: currentData)
            }
            return TransactionResult.success(withValue: currentData)
        }, andCompletionBlock: { error, committed, snapshot in
            if let error = error {
                print("Error updating rating: \(error.localizedDescription)")
            } else {
                // ユーザーの評価も更新するためにuserRatingsから該当するものを検索する
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
                                // 既存の評価があれば更新
                                childSnapshot.ref.updateChildValues([
                                    "rating": newRating,
                                    "timestamp": Date().timeIntervalSince1970
                                ])
                                ratingFound = true
                                break
                            }
                        }
                        if !ratingFound {
                            // 評価がなければ新規保存
                            self.saveUserRating(locationId: locationId, rating: newRating, userId: userId)
                        }
                    }
            }
        })
    }
    
    // ユーザーの評価を取得するメソッド
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
