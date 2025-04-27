import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage

class TimelineViewModel: ObservableObject {
    @Published var events: [TimelineEvent] = []
    @Published var currentOshiId: String = "default" // 現在の推しID
    @Published var isLoading: Bool = false // 読み込み中の状態
    
    private var dbRef: DatabaseReference {
        let userID = Auth.auth().currentUser?.uid ?? "default"
        return Database.database().reference().child("timelineEvents").child(userID)
    }
    
    init() {
        fetchEvents(forOshiId: currentOshiId)
    }
    
    // 推しIDを更新して、そのIDに関連するイベントを取得
    func updateCurrentOshi(id: String) {
        currentOshiId = id
        fetchEvents(forOshiId: id)
    }
    
    // 特定の推しに関連するイベントを取得
    func fetchEvents(forOshiId oshiId: String = "default") {
        isLoading = true
        
        dbRef.child(oshiId).observe(.value) { snapshot in
            var newEvents: [TimelineEvent] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let dict = snap.value as? [String: Any],
                   let time = dict["time"] as? String,
                   let title = dict["title"] as? String,
                   let colorString = dict["color"] as? String {
                    let imageURL = dict["imageURL"] as? String
                    let id = UUID(uuidString: dict["id"] as? String ?? "") ?? UUID()
                    let color: Color = {
                        switch colorString {
                        case "blue": return Color(hex: "3B82F6") // Tailwind blue-500
                        case "green": return Color(hex: "10B981") // Tailwind green-500
                        default: return .gray
                        }
                    }()
                    let event = TimelineEvent(
                        id: id,
                        time: time,
                        title: title,
                        color: color,
                        image: nil,
                        imageURL: imageURL,
                        oshiId: oshiId
                    )
                    newEvents.append(event)
                }
            }
            DispatchQueue.main.async {
                self.events = newEvents.sorted { event1, event2 in
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy/MM/dd HH:mm"
                    if let date1 = formatter.date(from: event1.time),
                       let date2 = formatter.date(from: event2.time) {
                        return date1 > date2 // 新しい順に並べ替え
                    }
                    return false
                }
                self.isLoading = false
            }
        }
    }
    
    // イベントを追加する関数（コールバック付き）
    func addEvent(event: TimelineEvent, completion: ((Bool) -> Void)? = nil) {
        isLoading = true
        var newEvent = event
        newEvent.oshiId = currentOshiId // 現在の推しIDを設定
        
        if let image = newEvent.image {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                completion?(false)
                isLoading = false
                return
            }
            let imageId = UUID().uuidString
            let imageRef = Storage.storage().reference().child("timelineImages/\(currentOshiId)/\(imageId).jpg")
            
            imageRef.putData(imageData, metadata: nil) { metadata, error in
                if let error = error {
                    print("画像アップロード失敗: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        completion?(false)
                    }
                    return
                }
                imageRef.downloadURL { url, error in
                    if let downloadURL = url {
                        self.saveEventToFirebase(newEvent, imageURL: downloadURL.absoluteString) { success in
                            DispatchQueue.main.async {
                                self.isLoading = false
                                completion?(success)
                            }
                        }
                    } else {
                        self.saveEventToFirebase(newEvent, imageURL: nil) { success in
                            DispatchQueue.main.async {
                                self.isLoading = false
                                completion?(success)
                            }
                        }
                    }
                }
            }
        } else {
            saveEventToFirebase(newEvent, imageURL: nil) { success in
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion?(success)
                }
            }
        }
    }
    
    private func saveEventToFirebase(_ event: TimelineEvent, imageURL: String?, completion: ((Bool) -> Void)? = nil) {
        let colorString: String
        if event.color == Color(hex: "3B82F6") {
            colorString = "blue"
        } else if event.color == Color(hex: "10B981") {
            colorString = "green"
        } else {
            colorString = "gray"
        }
        
        let eventId = event.id.uuidString
        var eventDict: [String: Any] = [
            "id": eventId,
            "time": event.time,
            "title": event.title,
            "color": colorString
        ]
        
        if let imageURL = imageURL {
            eventDict["imageURL"] = imageURL
        }
        
        let oshiId = event.oshiId ?? currentOshiId
        dbRef.child(oshiId).child(eventId).setValue(eventDict) { error, _ in
            if let error = error {
                print("イベント保存エラー: \(error.localizedDescription)")
                completion?(false)
            } else {
                // UIの更新のため、イベントを再取得
                self.fetchEvents(forOshiId: oshiId)
                completion?(true)
            }
        }
    }
    
    // 特定のイベントを削除
    func deleteEvent(event: TimelineEvent, completion: ((Bool) -> Void)? = nil) {
        isLoading = true
        let oshiId = event.oshiId ?? currentOshiId
        dbRef.child(oshiId).child(event.id.uuidString).removeValue { error, _ in
            if let error = error {
                print("イベント削除エラー: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion?(false)
                }
            } else {
                // 画像も削除
                if let imageURL = event.imageURL, !imageURL.isEmpty {
                    let storageRef = Storage.storage().reference(forURL: imageURL)
                    storageRef.delete { error in
                        if let error = error {
                            print("画像削除エラー: \(error.localizedDescription)")
                        }
                        // UIの更新のため、イベントを再取得
                        self.fetchEvents(forOshiId: oshiId)
                        DispatchQueue.main.async {
                            self.isLoading = false
                            completion?(true)
                        }
                    }
                } else {
                    // 画像がない場合は直接イベントを再取得
                    self.fetchEvents(forOshiId: oshiId)
                    DispatchQueue.main.async {
                        self.isLoading = false
                        completion?(true)
                    }
                }
            }
        }
    }
}

enum TimelineMode: String, CaseIterable {
    case week = "週間"
    case month = "月間"
}

struct TimelineEvent: Identifiable {
    let id: UUID
    let time: String
    let title: String
    let color: Color
    let image: UIImage?
    let imageURL: String?
    var oshiId: String?
}
