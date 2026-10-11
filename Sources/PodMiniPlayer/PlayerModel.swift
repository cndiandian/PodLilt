import AppKit
import ApplicationServices
import Combine
import Foundation

enum PlayerSize: String, CaseIterable, Hashable, Identifiable {
    case large, medium, small

    var id: String { rawValue }

    var title: String {
        switch self {
        case .large: "大尺寸"
        case .medium: "中尺寸"
        case .small: "小尺寸"
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

    @Published private(set) var playerSize: PlayerSize =
        PlayerSize(rawValue: UserDefaults.standard.string(forKey: "playerSize") ?? "") ?? .large
    @Published private(set) var state: DisplayState = .loading
    @Published private(set) var snapshot: PlaybackSnapshot?
    @Published private(set) var catalog: CatalogMetadata?
    @Published private(set) var commandFailed = false

    private var timer: Timer?
    private var fetching = false
    private var catalogTitle: String?
    var onSizeChanged: ((PlayerSize) -> Void)?

    func setSize(_ size: PlayerSize) {
        guard playerSize != size else { return }
        playerSize = size
        UserDefaults.standard.set(size.rawValue, forKey: "playerSize")
        onSizeChanged?(size)
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
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
            case .permissionNeeded:
                snapshot = nil
                catalog = nil
                state = .permission
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
        Task {
            let didPerform = await Task.detached(priority: .userInitiated) {
                PlaybackProbe.perform(action, snapshot: snapshot)
            }.value
            commandFailed = !didPerform
            if didPerform { refresh() }
        }
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
