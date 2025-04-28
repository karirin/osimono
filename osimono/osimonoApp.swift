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
    
        @State var isLoading = true
    init() {
        FirebaseApp.configure()
    }
    var body: some Scene {
        
        WindowGroup {
//            ContentView1()
//            TimelineView()
//            MapView()
//            AuthManager1(authManager: AuthManager())
            Group {
                if isLoading {
                    LoadingView4()
                } else {
                    TopView()
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
