//
//  Untitled.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth

// User Profile View
struct UserProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                // User avatar and info
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Color(hex: "6366F1"))
                    
                    Text(NSLocalizedString("username", comment: "Username"))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(NSLocalizedString("oshi_activity_status", comment: "Oshi activity: 10 spots visited"))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                // Stats
                HStack(spacing: 30) {
                    VStack {
                        Text("10")
                            .font(.title)
                            .fontWeight(.bold)
                        Text(NSLocalizedString("spots", comment: "Spots"))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    VStack {
                        Text("5")
                            .font(.title)
                            .fontWeight(.bold)
                        Text(NSLocalizedString("check_ins", comment: "Check-ins"))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    VStack {
                        Text("3")
                            .font(.title)
                            .fontWeight(.bold)
                        Text(NSLocalizedString("posts", comment: "Posts"))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 20)
                
                Divider()
                
                // Menu options
                List {
                    Button(action: {}) {
                        Label(NSLocalizedString("saved_spots", comment: "Saved Spots"), systemImage: "bookmark.fill")
                    }
                    
                    Button(action: {}) {
                        Label(NSLocalizedString("post_history", comment: "Post History"), systemImage: "photo.on.rectangle")
                    }
                    
                    Button(action: {}) {
                        Label(NSLocalizedString("settings", comment: "Settings"), systemImage: "gear")
                    }
                    
                    Button(action: {}) {
                        Label(NSLocalizedString("help", comment: "Help"), systemImage: "questionmark.circle")
                    }
                    
                    // Logout button with warning color
                    Button(action: {}) {
                        Label(NSLocalizedString("logout", comment: "Logout"), systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle(NSLocalizedString("profile_title", comment: "Profile"))
            .navigationBarItems(
                trailing: Button(NSLocalizedString("close", comment: "Close")) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}
