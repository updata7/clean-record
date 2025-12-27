import Foundation

/// Manages localization and language preferences for CleanRecord
class LocalizationManager {
    static let shared = LocalizationManager()
    
    private let defaults = UserDefaults.standard
    private let kPreferredLanguage = "preferredLanguage"
    
    /// Current language code (e.g., "en", "zh-hans")
    var currentLanguage: String {
        get {
            // Check user preference first
            if let preferred = defaults.string(forKey: kPreferredLanguage) {
                print("LocalizationManager: Using preferred language: \(preferred)")
                return preferred
            }
            // Fall back to system language
            let systemLang = Locale.preferredLanguages.first ?? "en"
            // Note: Use lowercase "zh-hans" to match SPM's bundle naming
            let detectedLang = systemLang.hasPrefix("zh") ? "zh-hans" : "en"
            print("LocalizationManager: Using system language: \(detectedLang) (from \(systemLang))")
            return detectedLang
        }
        set {
            print("LocalizationManager: Setting language to: \(newValue)")
            defaults.set(newValue, forKey: kPreferredLanguage)
            defaults.synchronize() // Force save
            print("LocalizationManager: Language saved, posting notification")
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
            print("LocalizationManager: Notification posted")
        }
    }
    
    /// Get localized string for the given key
    func localized(_ key: String, comment: String = "") -> String {
        let lang = currentLanguage
        print("LocalizationManager: Looking up '\(key)' in language '\(lang)'")
        
        // For Swift Package Manager, resources are in Bundle.module
        // First try to find the specific language bundle
        if let bundlePath = Bundle.module.path(forResource: lang, ofType: "lproj") {
            print("LocalizationManager: Found bundle at: \(bundlePath)")
            if let bundle = Bundle(path: bundlePath) {
                let localizedString = bundle.localizedString(forKey: key, value: nil, table: nil)
                print("LocalizationManager: Got string: '\(localizedString)'")
                // If we got a valid translation (not the key itself), return it
                if localizedString != key {
                    return localizedString
                }
            }
        } else {
            print("LocalizationManager: WARNING - Could not find bundle for language: \(lang)")
        }
        
        // Fallback to Bundle.module's default localization
        let localizedString = Bundle.module.localizedString(forKey: key, value: nil, table: nil)
        if localizedString != key {
            print("LocalizationManager: Using fallback string: '\(localizedString)'")
            return localizedString
        }
        
        // Last resort: return the key itself
        print("LocalizationManager: WARNING - No translation found, returning key: '\(key)'")
        return key
    }
    
    /// Reset to system language
    func resetToSystemLanguage() {
        defaults.removeObject(forKey: kPreferredLanguage)
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }
}

// Convenience extension for easy access
extension String {
    var localized: String {
        LocalizationManager.shared.localized(self)
    }
    
    func localized(comment: String = "") -> String {
        LocalizationManager.shared.localized(self, comment: comment)
    }
}

// Notification for language changes
extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}
