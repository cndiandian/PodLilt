enum L10n {
    static func text(_ key: L10nKey, language: AppLanguage) -> String {
        translations[language]?[key]
            ?? EnglishTranslations.values[key]
            ?? key.rawValue
    }

    private static let translations: [AppLanguage: [L10nKey: String]] = [
        .english: EnglishTranslations.values,
        .simplifiedChinese: SimplifiedChineseTranslations.values,
        .traditionalChinese: TraditionalChineseTranslations.values,
        .japanese: JapaneseTranslations.values
    ]
}
