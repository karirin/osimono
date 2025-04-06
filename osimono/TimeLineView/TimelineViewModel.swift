//
//  TimelineMockupView.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage

class TimelineViewModel: ObservableObject {
    @Published var events: [TimelineEvent] = []
    
    private var dbRef: DatabaseReference {
        let userID = Auth.auth().currentUser?.uid ?? "default"
        return Database.database().reference().child("timelineEvents").child(userID)
    }
    
    init() {
        fetchEvents()
    }
    
    func fetchEvents() {
        dbRef.observe(.value) { snapshot in
            var newEvents: [TimelineEvent] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let dict = snap.value as? [String: Any],
                   let time = dict["time"] as? String,
                   let title = dict["title"] as? String,
                   let colorString = dict["color"] as? String {
                    let imageURL = dict["imageURL"] as? String
                    let color: Color = {
                        switch colorString {
                        case "gray": return .gray
                        case "blue": return Color(hex: "3B82F6") // Tailwind blue-500
                        case "green": return Color(hex: "10B981") // Tailwind green-500
                        default: return .gray
                        }
                    }()
                    let event = TimelineEvent(
                        id: UUID(),
                        time: time,
                        title: title,
                        color: color,
                        image: nil,
                        imageURL: imageURL
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
                        return date1 < date2
                    }
                    return false
                }
            }
        }
    }
    
    func addEvent(event: TimelineEvent) {
        if let image = event.image {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
            let imageRef = Storage.storage().reference().child("timelineImages/\(UUID().uuidString).jpg")
            imageRef.putData(imageData, metadata: nil) { metadata, error in
                if let error = error {
                    print("画像アップロード失敗: \(error.localizedDescription)")
                    return
                }
                imageRef.downloadURL { url, error in
                    if let downloadURL = url {
                        let colorString: String
                        if event.color == Color(hex: "3B82F6") {
                            colorString = "blue"
                        } else if event.color == Color(hex: "10B981") {
                            colorString = "green"
                        } else {
                            colorString = "gray"
                        }
                        
                        let eventDict: [String: Any] = [
                            "time": event.time,
                            "title": event.title,
                            "color": colorString,
                            "imageURL": downloadURL.absoluteString
                        ]
                        self.dbRef.childByAutoId().setValue(eventDict)
                    }
                }
            }
        } else {
            let colorString: String
            if event.color == Color(hex: "3B82F6") {
                colorString = "blue"
            } else if event.color == Color(hex: "10B981") {
                colorString = "green"
            } else {
                colorString = "gray"
            }
            
            let eventDict: [String: Any] = [
                "time": event.time,
                "title": event.title,
                "color": colorString
            ]
            dbRef.childByAutoId().setValue(eventDict)
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
}
