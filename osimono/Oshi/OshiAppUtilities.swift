//
//  OshiAppUtilities.swift
//  osimono
//
//  Created by Apple on 2025/04/13.
//

import SwiftUI
import Firebase
import CoreLocation
import FirebaseStorage
import FirebaseDatabase
import FirebaseAuth

class OshiAppUtilities {
    
    // ジオコーディングしてコールバックで座標を返す
    static func geocodeAddress(_ address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let error = error {
                print("ジオコーディングエラー: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if let placemark = placemarks?.first,
               let location = placemark.location {
                completion(location.coordinate)
            } else {
                completion(nil)
            }
        }
    }
    
    // OshiItemFomViewのカテゴリとEnhancedAddLocationViewのカテゴリを変換する
    static func convertOshiItemCategoryToLocationCategory(_ oshiCategory: String) -> String {
        switch oshiCategory {
        case "CD・DVD", "雑誌", "写真集":
            return "グッズショップ"
        case "ライブ記録":
            return "ライブ会場"
        case "聖地巡礼":
            return "聖地"
        case "アクリルスタンド", "ぬいぐるみ", "Tシャツ", "タオル", "グッズ":
            return "グッズショップ"
        default:
            return "その他"
        }
    }
    
    // EnhancedAddLocationViewのカテゴリをOshiItemFomViewのitemTypeに変換する
    static func convertLocationCategoryToOshiItemType(_ locationCategory: String) -> String {
        switch locationCategory {
        case "ライブ会場":
            return "ライブ記録"
        case "ロケ地", "聖地":
            return "聖地巡礼"
        case "カフェ・飲食店":
            return "聖地巡礼"
        case "グッズショップ":
            return "グッズ"
        case "撮影スポット":
            return "聖地巡礼"
        default:
            return "その他"
        }
    }
    
    // 評価の変換（お気に入り度からratingへ、またはその逆）
    static func convertFavoriteToRating(_ favorite: Int) -> Int {
        // OshiItemFormViewのお気に入り度は3がデフォルト(0〜5)
        // LocationViewModelのratingは1〜5
        if favorite <= 0 {
            return 3 // デフォルト値
        } else if favorite > 5 {
            return 5
        } else {
            return favorite
        }
    }
    
    // ユーザーIDを取得
    static func getCurrentUserId() -> String? {
        return Auth.auth().currentUser?.uid
    }
    
    // 画像ファイルフォーマットを判定
    static func getImageFormat(from data: Data) -> String {
        var headerBytes = [UInt8](repeating: 0, count: 8)
        data.copyBytes(to: &headerBytes, count: 8)
        
        // JPEG: FF D8 FF
        if headerBytes[0] == 0xFF && headerBytes[1] == 0xD8 && headerBytes[2] == 0xFF {
            return "jpeg"
        }
        
        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if headerBytes[0] == 0x89 && headerBytes[1] == 0x50 && headerBytes[2] == 0x4E && headerBytes[3] == 0x47 {
            return "png"
        }
        
        // WebP: RIFF ???? WEBP
        let riffHeader = Data(headerBytes[0..<4])
        if riffHeader.elementsEqual("RIFF".data(using: .ascii)!) {
            return "webp"
        }
        
        // デフォルト
        return "jpeg"
    }
    
    // ハプティックフィードバック（両方のViewで共通利用可）
    static func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // デバイスがスモールスクリーンか判定
    static func isSmallDevice() -> Bool {
        return UIScreen.main.bounds.height <= 667
    }
}
