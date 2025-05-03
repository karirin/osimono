//
//  osimonoApp.swift
//  osimono
//
//  Created by Apple on 2025/03/20.
//

import SwiftUI
import FirebaseCore

@main
struct osimonoApp: App {
    @StateObject private var authManager = AuthManager()
    @State var isLoading = true
    init() {
        FirebaseApp.configure()
    }
    var body: some Scene {
        
        WindowGroup {
            Group {
                if isLoading {
                    StartLoadingView()
                } else {
                    TopView()
                        .environmentObject(authManager)
                }
            }
            .onAppear{
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        isLoading = false
                    }
                }
            }
        }
    }
}
