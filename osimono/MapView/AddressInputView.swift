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
                Section(header: Text("所在地情報")) {
                    Picker("都道府県", selection: $prefecture) {
                        ForEach(prefectures, id: \.self) { pref in
                            Text(pref)
                        }
                    }
                    
                    TextField("市区町村・番地", text: $streetAddress)
                        .foregroundColor(streetAddress.isEmpty ? .red : .primary)
                }
                
                Section(header: Text("ビル名・階数")) {
                    TextField("デジタルポート6F", text: $buildingName)
                }
                
                Section {
                    Button(action: {
                        generateHapticFeedback()
                        useCurrentLocation()
                    }) {
                        Text("現在地を入力")
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
                        Text("住所を確認")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .navigationTitle("住所入力")
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
        // Basic validation logic
        if !streetAddress.isEmpty && !prefecture.isEmpty {
            isAddressValidated = true
        } else {
            // Show an error alert if needed
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
                            print("現在地  ：\(locality) \(thoroughfare) \(subThoroughfare)")
                            streetAddress = "\(locality) \(thoroughfare) \(subThoroughfare)"
                        } else if let name = placemark.name {
                            streetAddress = name
                        }
                        // 逆ジオコーディング成功後、AddressConfirmationViewに遷移するためにフラグをON
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
