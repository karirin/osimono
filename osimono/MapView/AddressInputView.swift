//
//  AddressInputView.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth
import MapKit

struct AddressInputView: View {
    @State private var city = ""
    @State private var prefectures = ["東京都", "大阪府", "神奈川県", "その他"]
    @State private var showAddLocation = false
    @State private var isAddressValidated = false
    @StateObject private var locationManager = LocationManager()
    var image: UIImage?
    @Binding var prefecture: String
    @Binding var streetAddress: String
    @Binding var buildingName: String
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("location_info", comment: "Location Information"))) {
                    Picker(NSLocalizedString("prefecture", comment: "Prefecture"), selection: $prefecture) {
                        ForEach(prefectures, id: \.self) { pref in
                            Text(pref)
                        }
                    }
                    
                    TextField(NSLocalizedString("street_address_placeholder", comment: "City, district, street number"), text: $streetAddress)
                        .foregroundColor(streetAddress.isEmpty ? .red : .primary)
                }
                
                Section(header: Text(NSLocalizedString("building_floor", comment: "Building Name & Floor"))) {
                    TextField(NSLocalizedString("building_example", comment: "Digital Port 6F"), text: $buildingName)
                }
                
                Section {
                    Button(action: {
                        generateHapticFeedback()
                        useCurrentLocation()
                    }) {
                        Text(NSLocalizedString("enter_current_location", comment: "Enter Current Location"))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                
                Section {
                    Button(action: {
                        generateHapticFeedback()
                        validateAddress()
                    }) {
                        Text(NSLocalizedString("confirm_address", comment: "Confirm Address"))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("address_input", comment: "Address Input"))
            .sheet(isPresented: $isAddressValidated) {
                AddressConfirmationView(
                    prefecture: prefecture,
                    streetAddress: streetAddress,
                    buildingName: buildingName,
                    image: image
                )
            }
        }
    }
    
    func validateAddress() {
        if !streetAddress.isEmpty && !prefecture.isEmpty {
            isAddressValidated = true
        }
    }
    
    func useCurrentLocation() {
        if let location = locationManager.userLocation {
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let placemark = placemarks?.first {
                    DispatchQueue.main.async {
                        prefecture = placemark.administrativeArea ?? prefecture
                        if let locality = placemark.locality,
                           let thoroughfare = placemark.thoroughfare,
                           let subThoroughfare = placemark.subThoroughfare {
                            streetAddress = "\(locality) \(thoroughfare) \(subThoroughfare)"
                        } else if let name = placemark.name {
                            streetAddress = name
                        }
                        isAddressValidated = true
                    }
                } else {
                    print("逆ジオコーディング失敗: \(error?.localizedDescription ?? "不明なエラー")")
                }
            }
        } else {
            print("現在地が取得できません")
        }
    }
}
