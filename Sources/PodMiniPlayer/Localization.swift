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

enum L10nKey: String {
    case about
    case aboutPodLilt
    case accessibilityDetail
    case accessibilityRequired
    case appName
    case artwork
    case back15
    case compactMode
    case connecting
    case controlUnavailableMessage
    case coverMode
    case currentControlUnavailable
    case emptyDetail
    case emptyTitle
    case enableAccessibility
    case enablePermission
    case feedback
    case followSystem
    case forward30
    case fullMode
    case github
    case language
    case notPlaying
    case ok
    case openAndPlay
    case openPodcasts
    case pause
    case play
    case playbackProgress
    case playing
    case quit
    case readingPlayback
    case releaseNotes
    case settings
    case showHidePlayer
    case twitter
    case unknown
    case version
    case windowMode
}

enum L10n {
    static func text(_ key: L10nKey, language: AppLanguage) -> String {
        table[language]?[key] ?? table[.english]?[key] ?? key.rawValue
    }

    private static let table: [AppLanguage: [L10nKey: String]] = [
        .english: [
            .about: "About",
            .aboutPodLilt: "About PodLilt",
            .accessibilityDetail: "Accessibility permission is required to read playback information and control playback.",
            .accessibilityRequired: "Accessibility Permission Required",
            .appName: "APP Name:",
            .artwork: "Episode Artwork",
            .back15: "Back 15 Seconds",
            .compactMode: "Compact Mode",
            .connecting: "Connecting to Podcasts",
            .controlUnavailableMessage: "Due to system permission restrictions, PodLilt temporarily cannot control Podcasts. Open Podcasts, manually pause and resume playback, then try again.",
            .coverMode: "Cover Mode",
            .currentControlUnavailable: "Currently Unable to Control Podcasts",
            .emptyDetail: "Play an episode in Podcasts and it will appear here.",
            .emptyTitle: "Nothing Playing",
            .enableAccessibility: "Enable Accessibility Permission",
            .enablePermission: "Enable Permission",
            .feedback: "Feedback:",
            .followSystem: "Follow macOS",
            .forward30: "Forward 30 Seconds",
            .fullMode: "Full Mode",
            .github: "GitHub:",
            .language: "Language",
            .notPlaying: "Not Playing",
            .ok: "OK",
            .openAndPlay: "Open Podcasts and play an episode",
            .openPodcasts: "Open Podcasts",
            .pause: "Pause",
            .play: "Play",
            .playbackProgress: "Playback Progress",
            .playing: "Playing",
            .quit: "Quit",
            .readingPlayback: "Reading current playback…",
            .releaseNotes: "Release Notes",
            .settings: "Settings",
            .showHidePlayer: "Show or Hide Player",
            .twitter: "Twitter (X):",
            .unknown: "Unknown",
            .version: "Version:",
            .windowMode: "Window Mode"
        ],
        .simplifiedChinese: [
            .about: "关于",
            .aboutPodLilt: "关于 PodLilt",
            .accessibilityDetail: "需要辅助功能权限来读取播放信息并控制播放。",
            .accessibilityRequired: "需要辅助功能权限",
            .appName: "APP 名称：",
            .artwork: "节目封面",
            .back15: "后退 15 秒",
            .compactMode: "紧凑模式",
            .connecting: "正在连接 Podcasts",
            .controlUnavailableMessage: "因系统权限限制，PodLilt 暂时无法控制 Podcasts。请打开 Podcasts，手动暂停并重新播放一次后再试。",
            .coverMode: "封面模式",
            .currentControlUnavailable: "当前无法控制 Podcasts",
            .emptyDetail: "在 Podcasts 中播放一集，内容会出现在这里。",
            .emptyTitle: "还没有播放内容",
            .enableAccessibility: "开启辅助功能权限",
            .enablePermission: "开启权限",
            .feedback: "反馈：",
            .followSystem: "跟随 macOS",
            .forward30: "前进 30 秒",
            .fullMode: "完整模式",
            .github: "GitHub：",
            .language: "语言",
            .notPlaying: "未播放",
            .ok: "知道了",
            .openAndPlay: "打开 Podcasts 播放一集",
            .openPodcasts: "打开 Podcasts",
            .pause: "暂停",
            .play: "播放",
            .playbackProgress: "播放进度",
            .playing: "播放中",
            .quit: "退出",
            .readingPlayback: "读取当前播放内容…",
            .releaseNotes: "更新说明",
            .settings: "设置",
            .showHidePlayer: "显示或隐藏播放器",
            .twitter: "Twitter（X）：",
            .unknown: "未知",
            .version: "版本号：",
            .windowMode: "窗口模式"
        ],
        .traditionalChinese: [
            .about: "關於",
            .aboutPodLilt: "關於 PodLilt",
            .accessibilityDetail: "需要輔助使用權限來讀取播放資訊並控制播放。",
            .accessibilityRequired: "需要輔助使用權限",
            .appName: "APP 名稱：",
            .artwork: "節目封面",
            .back15: "倒退 15 秒",
            .compactMode: "緊湊模式",
            .connecting: "正在連接 Podcasts",
            .controlUnavailableMessage: "因系統權限限制，PodLilt 暫時無法控制 Podcasts。請開啟 Podcasts，手動暫停並重新播放一次後再試。",
            .coverMode: "封面模式",
            .currentControlUnavailable: "目前無法控制 Podcasts",
            .emptyDetail: "在 Podcasts 中播放單集後，內容會顯示在這裡。",
            .emptyTitle: "尚未播放內容",
            .enableAccessibility: "開啟輔助使用權限",
            .enablePermission: "開啟權限",
            .feedback: "意見回饋：",
            .followSystem: "跟隨 macOS",
            .forward30: "快轉 30 秒",
            .fullMode: "完整模式",
            .github: "GitHub：",
            .language: "語言",
            .notPlaying: "未播放",
            .ok: "知道了",
            .openAndPlay: "開啟 Podcasts 並播放一集",
            .openPodcasts: "開啟 Podcasts",
            .pause: "暫停",
            .play: "播放",
            .playbackProgress: "播放進度",
            .playing: "播放中",
            .quit: "結束",
            .readingPlayback: "正在讀取播放內容…",
            .releaseNotes: "更新說明",
            .settings: "設定",
            .showHidePlayer: "顯示或隱藏播放器",
            .twitter: "Twitter（X）：",
            .unknown: "未知",
            .version: "版本號：",
            .windowMode: "視窗模式"
        ],
        .japanese: [
            .about: "このアプリについて",
            .aboutPodLilt: "PodLiltについて",
            .accessibilityDetail: "再生情報の読み取りと再生操作には、アクセシビリティの権限が必要です。",
            .accessibilityRequired: "アクセシビリティの権限が必要です",
            .appName: "アプリ名：",
            .artwork: "エピソードのアートワーク",
            .back15: "15秒戻る",
            .compactMode: "コンパクトモード",
            .connecting: "Podcastsに接続中",
            .controlUnavailableMessage: "システムの権限制限により、PodLiltからPodcastsを一時的に操作できません。Podcastsを開き、手動で一度停止してから再生し、もう一度お試しください。",
            .coverMode: "カバーモード",
            .currentControlUnavailable: "現在Podcastsを操作できません",
            .emptyDetail: "Podcastsでエピソードを再生すると、ここに表示されます。",
            .emptyTitle: "再生中のコンテンツはありません",
            .enableAccessibility: "アクセシビリティの権限を有効にする",
            .enablePermission: "権限を有効にする",
            .feedback: "フィードバック：",
            .followSystem: "macOSの言語に従う",
            .forward30: "30秒進む",
            .fullMode: "フルモード",
            .github: "GitHub：",
            .language: "言語",
            .notPlaying: "未再生",
            .ok: "OK",
            .openAndPlay: "Podcastsを開いてエピソードを再生",
            .openPodcasts: "Podcastsを開く",
            .pause: "一時停止",
            .play: "再生",
            .playbackProgress: "再生の進行状況",
            .playing: "再生中",
            .quit: "終了",
            .readingPlayback: "現在の再生内容を読み取り中…",
            .releaseNotes: "リリースノート",
            .settings: "設定",
            .showHidePlayer: "プレーヤーを表示／非表示",
            .twitter: "Twitter（X）：",
            .unknown: "不明",
            .version: "バージョン：",
            .windowMode: "ウインドウモード"
        ]
    ]
}
