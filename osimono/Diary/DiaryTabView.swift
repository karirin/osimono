//
//  DiaryTabView.swift
//  osimono
//
//  Created by Apple on 2025/05/04.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage

struct DiaryTabView: View {
    @State private var selectedOshiId: String = "default"
    
    var body: some View {
        DiaryView(oshiId: selectedOshiId)
            .onAppear {
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
