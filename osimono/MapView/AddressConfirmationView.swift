//
//  AddressConfirmationView.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth
import MapKit

struct AddressConfirmationView: View {
    let prefecture: String
    let streetAddress: String
    let buildingName: String
    var image: UIImage?
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0),
        span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
    )
    @State private var coordinate: CLLocationCoordinate2D?
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedLocationId: String? = nil
    
    // フルアドレスを組み立てる
    var fullAddress: String {
        if buildingName.isEmpty {
            return "\(prefecture) \(streetAddress)"
        } else {
            return "\(prefecture) \(streetAddress) \(buildingName)"
        }
    }
    
    var body: some View {
        VStack {
            Text(NSLocalizedString("pin_location_correct", comment: "Is the pin location correct?"))
                .font(.headline)
                .padding()
            
            if let coordinate = coordinate {
                Map(coordinateRegion: $region, annotationItems: [MapAnnotationItem(coordinate: coordinate)]) { item in
                    MapAnnotation(coordinate: item.coordinate, anchorPoint: CGPoint(x: 0.5, y: 1.0)) {
                        AddressMapPinView(image: image, isSelected: false)
                    }
                }
                .frame(height: 400)
                .cornerRadius(10)
            } else {
                ProgressView(NSLocalizedString("searching_location", comment: "Searching for location..."))
                    .frame(height: 300)
            }
            
            Text(fullAddress)
                .padding()
            
            HStack {
                Button(NSLocalizedString("cancel", comment: "Cancel")) {
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                
                Button(NSLocalizedString("next", comment: "Next")) {
                    // 確認後の次の処理を追加
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding()
        }
        .onAppear {
            DispatchQueue.main.async {
                geocodeAddress()
            }
        }
    }
    
    func geocodeAddress() {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(fullAddress) { placemarks, error in
            if let placemark = placemarks?.first, let location = placemark.location {
                DispatchQueue.main.async {
                    coordinate = location.coordinate
                    region.center = location.coordinate
                }
            } else {
                print("住所のジオコーディング失敗: \(error?.localizedDescription ?? "不明なエラー")")
            }
        }
    }
}
