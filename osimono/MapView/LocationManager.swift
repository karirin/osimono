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
    
    // 場所を削除
    func deleteLocation(locationId: String, oshiId: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // まず画像があれば削除
        if let location = locations.first(where: { $0.id == locationId }),
           let imageURL = location.imageURL {
            // Storage参照を作成
            let imagePath = "location_images/\(userId)/\(oshiId)/\(locationId).jpg"
            let storageRef = storage.reference().child(imagePath)
            
            // 画像を削除
            storageRef.delete { error in
                if let error = error {
                    print("画像削除エラー: \(error.localizedDescription)")
                }
            }
        }
        
        // データベースから削除
        let ref = db.child("locations").child(userId).child(oshiId).child(locationId)
        ref.removeValue { error, _ in
            if let error = error {
                print("削除エラー: \(error.localizedDescription)")
            } else {
                print("削除成功")
                
                // oshiItemsテーブルからも削除（聖地巡礼の場合）
                let oshiItemRef = self.db.child("oshiItems").child(userId).child(oshiId).child(locationId)
                oshiItemRef.removeValue()
            }
        }
    }

    // 場所を更新
    func updateLocation(id: String,
                       title: String,
                       latitude: Double,
                       longitude: Double,
                       category: String,
                       rating: Int,
                       note: String?,
                       image: UIImage?,
                       completion: @escaping (Bool) -> Void) {
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            completion(false)
            return
        }
        
        let locationRef = db.child("locations").child(userId).child(currentOshiId).child(id)
        
        var updateData: [String: Any] = [
            "title": title,
            "latitude": latitude,
            "longitude": longitude,
            "category": category,
            "ratingSum": rating,
            "note": note ?? "",
            "createdAt": Date().timeIntervalSince1970
        ]
        
        // 画像がある場合は先にアップロード
        if let image = image, let imageData = image.jpegData(compressionQuality: 0.7) {
            let imagePath = "location_images/\(userId)/\(currentOshiId)/\(id).jpg"
            let storageRef = storage.reference().child(imagePath)
            
            storageRef.putData(imageData, metadata: nil) { metadata, error in
                if let error = error {
                    print("Error uploading image: \(error.localizedDescription)")
                    // 画像アップロードに失敗してもデータは更新
                    self.performLocationUpdate(ref: locationRef, data: updateData, completion: completion)
                    return
                }
                
                storageRef.downloadURL { url, error in
                    if let downloadURL = url {
                        updateData["imageURL"] = downloadURL.absoluteString
                    }
                    self.performLocationUpdate(ref: locationRef, data: updateData, completion: completion)
                }
            }
        } else {
            // 画像がない場合は直接更新
            performLocationUpdate(ref: locationRef, data: updateData, completion: completion)
        }
    }
    
    private func performLocationUpdate(ref: DatabaseReference, data: [String: Any], completion: @escaping (Bool) -> Void) {
        ref.updateChildValues(data) { error, _ in
            if let error = error {
                print("Error updating location: \(error.localizedDescription)")
                completion(false)
            } else {
                print("Location updated successfully")
                completion(true)
            }
        }
    }
    
    func getLocationDetails(id: String, completion: @escaping (EventLocation?) -> Void) {
        print("🔍 Starting getLocationDetails for ID: '\(id)'")
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user found")
            completion(nil)
            return
        }
        print("✅ User ID: \(userId)")
        
        print("✅ Current Oshi ID: \(currentOshiId)")
        
        let locationRef = db.child("locations").child(userId).child(currentOshiId).child(id)
        print("🔍 Firebase path: locations/\(userId)/\(currentOshiId)/\(id)")
        
        locationRef.observeSingleEvent(of: .value) { snapshot in
            print("📡 Firebase response received")
            print("📊 Snapshot exists: \(snapshot.exists())")
            print("📊 Snapshot key: \(snapshot.key)")
            print("📊 Snapshot value: \(snapshot.value ?? "nil")")
            
            if let dict = snapshot.value as? [String: Any] {
                print("✅ Successfully converted to dictionary")
                print("📋 Dictionary contents: \(dict)")
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: dict)
                    print("✅ Successfully converted to JSON data")
                    
                    var location = try JSONDecoder().decode(EventLocation.self, from: jsonData)
                    print("✅ Successfully decoded to EventLocation")
                    print("📍 Location title: \(location.title)")
                    
                    location.id = snapshot.key
                    location.oshiId = self.currentOshiId
                    print("✅ Set ID and OshiId, completing with location")
                    completion(location)
                } catch {
                    print("❌ Error decoding location details: \(error)")
                    print("❌ JSON Data: \(String(data: try! JSONSerialization.data(withJSONObject: dict), encoding: .utf8) ?? "nil")")
                    completion(nil)
                }
            } else {
                print("❌ Failed to convert snapshot to dictionary")
                print("❌ Snapshot value type: \(type(of: snapshot.value))")
                completion(nil)
            }
        } withCancel: { error in
            print("❌ Firebase error: \(error.localizedDescription)")
            completion(nil)
        }
    }
    
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
    func addLocation(id: String? = nil,
                     title: String,
                     latitude: Double,
                     longitude: Double,
                     category: String,
                     initialRating: Int,
                     note: String?,
                     image: UIImage?,
                     customImageUrl: String? = nil,
                     completion: @escaping (String?) -> Void) {
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            completion(nil)
            return
        }
        
        let ratingSum = initialRating > 0 ? initialRating : 0
        
        let newLocation = EventLocation(
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
            let ref: DatabaseReference
            if let providedId = id {
                ref = db.child("locations").child(userId).child(currentOshiId).child(providedId)
            } else {
                ref = db.child("locations").child(userId).child(currentOshiId).childByAutoId()
            }
            var locationDict = try newLocation.asDictionary()
            if let customImageUrl, !customImageUrl.isEmpty {
                locationDict["imageURL"] = customImageUrl
            }
            
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

                    if let customImageUrl, !customImageUrl.isEmpty {
                        completion(newLocationId)
                        return
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
            }
        }
    }
    
    // 指定したロケーションに対する、現在のユーザーの評価を取得
    func getUserRating(for locationId: String, oshiId: String, completion: @escaping (Int?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
    }
    
    func updateCurrentOshi(id: String) {
        currentOshiId = id
        fetchLocations(forOshiId: id)
    }

    func fetchTimelineEventsLinked(to locationId: String, oshiId: String, completion: @escaping ([TimelineEvent]) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion([])
            return
        }

        let eventsRef = db.child("timelineEvents").child(userId).child(oshiId)
        eventsRef.observeSingleEvent(of: .value) { snapshot in
            var events: [TimelineEvent] = []

            for child in snapshot.children {
                guard let childSnapshot = child as? DataSnapshot,
                      let dict = childSnapshot.value as? [String: Any],
                      let linkedLocationId = dict["locationId"] as? String,
                      linkedLocationId == locationId,
                      let time = dict["time"] as? String,
                      let title = dict["title"] as? String,
                      let colorString = dict["color"] as? String else {
                    continue
                }

                let color: Color
                switch colorString {
                case "blue":
                    color = Color(hex: "3B82F6")
                case "green":
                    color = Color(hex: "10B981")
                default:
                    color = .gray
                }

                events.append(
                    TimelineEvent(
                        id: UUID(uuidString: dict["id"] as? String ?? childSnapshot.key) ?? UUID(),
                        time: time,
                        title: title,
                        color: color,
                        image: nil,
                        imageURL: dict["imageURL"] as? String,
                        oshiId: oshiId,
                        locationId: linkedLocationId,
                        locationTitle: dict["locationTitle"] as? String
                    )
                )
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd HH:mm"
            let sortedEvents = events.sorted {
                guard let firstDate = formatter.date(from: $0.time),
                      let secondDate = formatter.date(from: $1.time) else {
                    return $0.time > $1.time
                }
                return firstDate > secondDate
            }

            DispatchQueue.main.async {
                completion(sortedEvents)
            }
        }
    }
}
