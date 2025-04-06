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
    init() {
        FirebaseApp.configure()
    }
    var body: some Scene {
        WindowGroup {
//            ContentView1()
//            TimelineView()
//            MapView()
//            AuthManager1(authManager: AuthManager())
            TopView()
        }
    }
}
