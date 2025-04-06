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

struct EventLocation: Identifiable {
    var id: String
    var title: String
    var latitude: Double
    var longitude: Double
    var imageURL: String?  // ここを追加
}

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

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            userLocation = location
            // 必要なら一度だけ更新する場合は更新停止
            manager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }
}

class LocationViewModel: ObservableObject {
    @Published var locations: [EventLocation] = []

    init() {
        fetchLocations()
    }
    
    func uploadImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }
        let storageRef = Storage.storage().reference().child("location_images").child(UUID().uuidString + ".jpg")
        storageRef.putData(imageData, metadata: nil) { metadata, error in
             if let error = error {
                 print("Upload error: \(error.localizedDescription)")
                 completion(nil)
                 return
             }
             storageRef.downloadURL { url, error in
                 if let error = error {
                     print("Download URL error: \(error.localizedDescription)")
                     completion(nil)
                 } else {
                     completion(url?.absoluteString)
                 }
             }
        }
    }

    func addLocation(title: String, latitude: Double, longitude: Double, image: UIImage? = nil) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("addLocation 1")
            return
        }
        let saveLocation = { (imageURL: String?) in
            var newLocation: [String: Any] = [
                "title": title,
                "latitude": latitude,
                "longitude": longitude
            ]
            if let imageURL = imageURL {
                newLocation["imageURL"] = imageURL
            }
            let ref = Database.database().reference().child("eventLocations").child(userId).childByAutoId()
            print("addLocation 2")
            ref.setValue(newLocation)
        }
        
        if let image = image {
            uploadImage(image) { imageURL in
                saveLocation(imageURL)
            }
        } else {
            saveLocation(nil)
        }
    }

    func fetchLocations() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let ref = Database.database().reference().child("eventLocations").child(userId)

        ref.observe(.value) { snapshot in
            var newLocations: [EventLocation] = []
            for child in snapshot.children.allObjects as! [DataSnapshot] {
                if let dict = child.value as? [String: Any],
                   let title = dict["title"] as? String,
                   let latitude = dict["latitude"] as? Double,
                   let longitude = dict["longitude"] as? Double {
                    let imageURL = dict["imageURL"] as? String  // 追加
                    let location = EventLocation(id: child.key, title: title, latitude: latitude, longitude: longitude, imageURL: imageURL)
                    newLocations.append(location)
                }
            }
            DispatchQueue.main.async {
                self.locations = newLocations
            }
        }
    }

}
