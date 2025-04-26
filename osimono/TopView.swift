//
//  TopView.swift
//  osimono
//
//  Created by Apple on 2025/03/23.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct TopView: View {
    @State private var selectedOshiId: String = "default"
    
    var body: some View {
        TabView {
            HStack{
                ContentView()
            }
            
            .tabItem {
                Image(systemName: "rectangle.split.2x2")
                    .padding()
                Text("推しコレ")
                    .padding()
            }
            ZStack {
                TimelineView(oshiId: selectedOshiId)
            }
            .tabItem {
                Image(systemName: "calendar.day.timeline.left")
                    .frame(width:1,height:1)
                Text("年表")
            }
            ZStack {
                MapView(oshiId: selectedOshiId)
            }
            .tabItem {
                Image(systemName: "map")
                Text("マップ")
            }
        }
        .onAppear{
            observeSelectedOshiId()
        }
    }
    
    func observeSelectedOshiId() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.observe(.value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else { return }
            
            if let selectedOshiId = value["selectedOshiId"] as? String {
                DispatchQueue.main.async {
                    self.selectedOshiId = selectedOshiId
                }
            }
        }
    }
}

#Preview {
    TopView()
}
