import AppKit
import ApplicationServices
import Combine
import Foundation

enum PlayerSize: String, CaseIterable, Hashable, Identifiable {
    case large, medium, small

    var id: String { rawValue }

    var titleKey: L10nKey {
        switch self {
        case .large: .fullMode
        case .medium: .compactMode
        case .small: .coverMode
        }
    }

    var dimensions: NSSize {
        switch self {
        case .large: NSSize(width: 360, height: 236)
        case .medium: NSSize(width: 360, height: 80)
        case .small: NSSize(width: 96, height: 96)
        }
    }
}

@MainActor
final class PlayerModel: ObservableObject {
    enum DisplayState { case loading, permission, empty, ready }

    @Published private(set) var playerSize: PlayerSize
    @Published private(set) var languagePreference: LanguagePreference
    @Published private(set) var language: AppLanguage
    @Published private(set) var state: DisplayState = .loading
    @Published private(set) var snapshot: PlaybackSnapshot?
    @Published private(set) var catalog: CatalogMetadata?
    @Published private(set) var commandFailed = false

    private var timer: Timer?
    private var fetching = false
    private var catalogTitle: String?
    var onSizeChanged: ((PlayerSize) -> Void)?
    var onLanguageChanged: (() -> Void)?

    init() {
        let defaults = UserDefaults.standard
        playerSize = PlayerSize(rawValue: defaults.string(forKey: "playerSize") ?? "") ?? .large
        let preference = LanguagePreference(rawValue: defaults.string(forKey: "languagePreference") ?? "") ?? .system
        languagePreference = preference
        language = preference.resolvedLanguage
    }

    func setSize(_ size: PlayerSize) {
        guard playerSize != size else { return }
        playerSize = size
        UserDefaults.standard.set(size.rawValue, forKey: "playerSize")
        onSizeChanged?(size)
    }

    func setLanguage(_ preference: LanguagePreference) {
        guard languagePreference != preference else { return }
        languagePreference = preference
        language = preference.resolvedLanguage
        UserDefaults.standard.set(preference.rawValue, forKey: "languagePreference")
        onLanguageChanged?()
    }

    func refreshSystemLanguage() {
        guard languagePreference == .system else { return }
        let preferred = LanguagePreference.system.resolvedLanguage
        guard language != preferred else { return }
        language = preferred
        onLanguageChanged?()
    }

    func text(_ key: L10nKey) -> String {
        L10n.text(key, language: language)
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard !fetching else { return }
        fetching = true
        Task {
            let result = await Task.detached(priority: .userInitiated) { PlaybackProbe.fetch() }.value
            fetching = false
            switch result {
            case .playing(let latest):
                let titleChanged = snapshot?.title != latest.title
                snapshot = latest
                state = .ready
                commandFailed = false
                if titleChanged {
                    catalog = nil
                    catalogTitle = latest.title
                    if latest.artwork == nil || latest.duration == nil || latest.show == nil {
                        Task {
                            let metadata = await ArtworkLookup.fetch(title: latest.title, episodeID: latest.episodeID)
                            guard catalogTitle == latest.title else { return }
                            catalog = metadata
                        }
                    }
                }
            case .otherPlayerActive:
                if let snapshot {
                    self.snapshot = snapshot.cached(at: Date())
                    state = .ready
                } else {
                    state = .empty
                }
            case .permissionNeeded:
                if let snapshot {
                    self.snapshot = snapshot.cached(at: Date())
                    state = .ready
                } else {
                    catalog = nil
                    state = .permission
                }
            case .noPlayback:
                snapshot = nil
                catalog = nil
                state = .empty
            }
        }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    func perform(_ action: PlaybackAction) {
        guard let snapshot else { return }
        if snapshot.requiresAccessibilityControl, !AXIsProcessTrusted() {
            commandFailed = true
            return
        }
        Task {
            let didPerform = await Task.detached(priority: .userInitiated) {
                PlaybackProbe.perform(action, snapshot: snapshot)
            }.value
            commandFailed = !didPerform
            if didPerform { refresh() }
        }
    }

    func dismissCommandFailure() {
        commandFailed = false
    }

    func openPodcasts() {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.podcasts").first {
            app.activate()
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Podcasts.app"))
        }
    }

    var title: String { snapshot?.title ?? "" }
    var show: String { snapshot?.show ?? catalog?.show ?? "Apple Podcasts" }
    var artwork: NSImage? {
        (snapshot?.artwork ?? catalog?.artwork).flatMap(NSImage.init(data:))
    }
    var duration: TimeInterval? { snapshot?.duration ?? catalog?.duration }

    func position(at date: Date) -> TimeInterval? {
        snapshot?.position(at: date)
    }
}
