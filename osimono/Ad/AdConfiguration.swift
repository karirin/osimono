//
//  AdConfiguration.swift
//  osimono
//
//  Created by Codex on 2026/05/22.
//

import Foundation

enum AdConfiguration {
    static var isDisabledForDevelopment: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static func shouldShowAds(isAdmin: Bool, isSubscribed: Bool) -> Bool {
        !isDisabledForDevelopment && !isAdmin && !isSubscribed
    }
}
