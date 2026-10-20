import Foundation

enum AppLanguage: String {
    case english
    case simplifiedChinese
    case traditionalChinese
    case japanese

    static var systemPreferred: AppLanguage {
        let identifier = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if identifier.hasPrefix("zh-hant")
            || identifier.hasPrefix("zh-tw")
            || identifier.hasPrefix("zh-hk")
            || identifier.hasPrefix("zh-mo") {
            return .traditionalChinese
        }
        if identifier.hasPrefix("zh") { return .simplifiedChinese }
        if identifier.hasPrefix("ja") { return .japanese }
        return .english
    }
}

enum LanguagePreference: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese
    case traditionalChinese
    case japanese

    var id: String { rawValue }

    var resolvedLanguage: AppLanguage {
        switch self {
        case .system: .systemPreferred
        case .english: .english
        case .simplifiedChinese: .simplifiedChinese
        case .traditionalChinese: .traditionalChinese
        case .japanese: .japanese
        }
    }

    func title(using language: AppLanguage) -> String {
        switch self {
        case .system: L10n.text(.followSystem, language: language)
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        }
    }
}
