//
//  Untitled.swift
//  osimono
//
//  Created by Apple on 2025/04/07.
//

import SwiftUI
import FirebaseAuth
import FirebaseDatabase

struct EditUserProfileView: View {
    @Binding var userProfile: UserProfile
    @Environment(\.presentationMode) var presentationMode
    @State private var username: String
    @State private var favoriteOshi: String
    @State private var isLoading = false
    
    // テーマカラー
    let primaryColor = Color(.systemPink)
    
    init(userProfile: Binding<UserProfile>) {
        self._userProfile = userProfile
        self._username = State(initialValue: userProfile.wrappedValue.username ?? "")
        self._favoriteOshi = State(initialValue: userProfile.wrappedValue.favoriteOshi ?? "")
    }
    
    var body: some View {
        Form {
            Section {
                TextField(L10n.username, text: $username)
                    .padding(.vertical, 8)
                TextField(L10n.favoriteOshi, text: $favoriteOshi)
                    .padding(.vertical, 8)
            } header: {
                Text(LocalizedStringKey(L10n.profileInfo))
            } footer: {
                EmptyView()
            }
            
            Section {
                Button(action: saveProfile) {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text(L10n.save)
                                .fontWeight(.bold)
                        }
                        Spacer()
                    }
                }
                .disabled(isLoading)
                .padding(.vertical, 4)
                .foregroundColor(.white)
                .background(primaryColor)
                .cornerRadius(8)
                .padding(.vertical, 6)
            }
        }
        .navigationTitle(L10n.profileEdit)
        .navigationBarItems(
            leading: Button(L10n.cancel) {
                generateHapticFeedback()
                presentationMode.wrappedValue.dismiss()
            }
        )
    }
    
    func saveProfile() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isLoading = true
        
        let updatedProfileData: [String: Any] = [
            "username": username,
            "favoriteOshi": favoriteOshi
        ]
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.updateChildValues(updatedProfileData) { error, _ in
            DispatchQueue.main.async {
                isLoading = false
                generateHapticFeedback()
                if error == nil {
                    userProfile.username = username
                    userProfile.favoriteOshi = favoriteOshi
                    presentationMode.wrappedValue.dismiss()
                    
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                } else {
                    print("\(L10n.saveError): \(error?.localizedDescription ?? L10n.unknownError)")
                }
            }
        }
    }
}
