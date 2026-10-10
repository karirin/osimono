//
//  osimonoApp.swift
//  osimono
//
//  Created by Apple on 2025/03/20.
//

import SwiftUI
import FirebaseAppCheck
import FirebaseCore
import FirebaseAnalytics
import UserNotifications

@main
struct osimonoApp: App {
    @StateObject private var authManager = AuthManager()
    @State var isLoading = true
    init() {
        #if DEBUG
        // DeviceCheck はシミュレータでは使えないため、Firebase Console に登録した
        // デバッグトークンで App Check を通す。
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #endif
        FirebaseApp.configure()
        Analytics.setAnalyticsCollectionEnabled(true)
        PaywallConfig.shared.fetch()
        // 推しからの朝・夜メッセージ（プレミアム）をアプリ使用中にも表示・履歴に反映する
        UNUserNotificationCenter.current().delegate = PremiumGreetingManager.shared
        #if DEBUG
        Analytics.logEvent("debug_app_launch", parameters: nil)
        #endif
    }
    var body: some Scene {
        
        WindowGroup {
            AppLockRoot {
                // 匿名ログインが終わる前に TopView を出すと、推し一覧の読み込みや推し登録が何もせずに終わってしまう
                if isLoading || authManager.user == nil {
                    StartLoadingView()
                        .overlay(alignment: .bottom) {
                            if !isLoading && authManager.signInFailed {
                                signInErrorBanner
                            }
                        }
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
    
    private var signInErrorBanner: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("auth_connection_error", comment: "Sign-in failed"))
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Button {
                authManager.signInAnonymously()
            } label: {
                Text(NSLocalizedString("retry", comment: "Retry"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(hex: "FF2D92")))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.6)))
        .padding(.horizontal, 16)
        .padding(.bottom, 48)
    }
}
