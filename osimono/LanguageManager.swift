//
//  拡張可能な多言語対応システム
//  ローカライズファイルのみで言語追加可能
//

import Foundation

// MARK: - 言語管理クラス
class LanguageManager {
    static let shared = LanguageManager()
    
    private init() {}
    
    // 推しの言語設定から実際の言語コードを取得
    func getConversationLanguage(for oshi: Oshi) -> String {
        // デバッグ出力
        print("🔍 LanguageManager: 推し「\(oshi.name)」の言語設定取得")
        print("🔍 preferred_language: \(oshi.preferred_language ?? "nil")")
        print("🔍 デバイス言語: \(getCurrentDeviceLanguage())")
        
        // 推しの優先言語設定をチェック
        if let preferredLanguage = oshi.preferred_language, !preferredLanguage.isEmpty {
            print("🔍 優先言語が設定されています: \(preferredLanguage)")
            switch preferredLanguage {
            case "auto", "follow_device":
                let deviceLang = getCurrentDeviceLanguage()
                print("🔍 デバイス設定に従う -> \(deviceLang)")
                return deviceLang
            default:
                print("🔍 指定言語を使用: \(preferredLanguage)")
                return preferredLanguage
            }
        }
        
        // 設定がない場合はデバイスの言語を使用
        let deviceLang = getCurrentDeviceLanguage()
        print("🔍 設定なし、デバイス言語を使用: \(deviceLang)")
        return deviceLang
    }
    
    // 現在のデバイス言語を取得
    private func getCurrentDeviceLanguage() -> String {
        let deviceLanguage = Locale.current.languageCode ?? "en"
        
        // サポートしている言語のみを返す
        let supportedLanguages = getSupportedLanguages()
        if supportedLanguages.contains(deviceLanguage) {
            return deviceLanguage
        }
        
        // サポートしていない言語の場合は英語にフォールバック
        return "en"
    }
    
    // サポートしている言語のリストを取得
    private func getSupportedLanguages() -> Set<String> {
        var bundleLocalizations = Set(Bundle.main.localizations)
        bundleLocalizations.remove("Base") // Base.lprojを除外
        return bundleLocalizations
    }
    
    // 指定された言語のローカライズ文字列を取得
    func localizedString(_ key: String, language: String, fallback: String = "") -> String {
        guard let bundlePath = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: bundlePath) else {
            // フォールバック: 英語またはデフォルト値
            if language != "en" {
                return localizedString(key, language: "en", fallback: fallback)
            }
            return fallback.isEmpty ? NSLocalizedString(key, comment: "") : fallback
        }
        
        let localizedString = NSLocalizedString(key, bundle: bundle, comment: "")
        
        // キーがそのまま返された場合（翻訳が見つからない場合）はフォールバックを使用
        if localizedString == key && !fallback.isEmpty {
            return fallback
        }
        
        return localizedString
    }
    
    // 利用可能な言語リストを動的に取得
    func getAvailableLanguages() -> [(code: String, name: String)] {
        var languages: [(code: String, name: String)] = [
            ("auto", NSLocalizedString("follow_device_setting", value: "Follow device setting", comment: "Follow device setting"))
        ]
        
        // Bundle内のlprojファイルから言語を自動検出
        let availableLocalizations = getSupportedLanguages()
        
        for localization in availableLocalizations.sorted() {
            let displayName = getLanguageDisplayName(for: localization)
            languages.append((localization, displayName))
        }
        
        return languages
    }
    
    // 言語コードから表示名を取得
    private func getLanguageDisplayName(for languageCode: String) -> String {
        let locale = Locale.current
        return locale.localizedString(forLanguageCode: languageCode)?.capitalized ?? languageCode
    }
    
    // デバッグ用：現在の言語設定を出力
    func printLanguageDebugInfo(for oshi: Oshi) {
        print("=== 言語設定デバッグ情報 ===")
        print("推しの優先言語: \(oshi.preferred_language ?? "未設定")")
        print("デバイス言語: \(Locale.current.languageCode ?? "不明")")
        print("決定された会話言語: \(getConversationLanguage(for: oshi))")
        print("サポート言語: \(getSupportedLanguages())")
        print("========================")
    }
}
