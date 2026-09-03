//
//  osimonoApp.swift
//  osimono
//
//  Created by Apple on 2025/03/20.
//

import SwiftUI
import FirebaseCore
import FirebaseAnalytics

@main
struct osimonoApp: App {
    @StateObject private var authManager = AuthManager()
    @State var isLoading = true
    init() {
        FirebaseApp.configure()
        Analytics.setAnalyticsCollectionEnabled(true)
        #if DEBUG
        Analytics.logEvent("debug_app_launch", parameters: nil)
        #endif
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
