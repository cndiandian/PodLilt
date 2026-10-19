import AppKit
import ApplicationServices
import Foundation

struct PlaybackSnapshot {
    let title: String
    let show: String?
    let artwork: Data?
    let episodeID: String?
    let duration: TimeInterval?
    let elapsed: TimeInterval?
    let capturedAt: Date
    let playbackRate: Double
    let isPlaying: Bool
    let source: Source

    enum Source { case mediaRemote, accessibility, cached }

    var requiresAccessibilityControl: Bool {
        switch source {
        case .mediaRemote: false
        case .accessibility, .cached: true
        }
    }

    func position(at date: Date) -> TimeInterval? {
        guard let elapsed else { return nil }
        let estimate = elapsed + (isPlaying ? max(0, date.timeIntervalSince(capturedAt)) * max(0, playbackRate) : 0)
        return min(max(0, estimate), duration ?? estimate)
    }

    func cached(at date: Date) -> PlaybackSnapshot {
        PlaybackSnapshot(
            title: title,
            show: show,
            artwork: artwork,
            episodeID: episodeID,
            duration: duration,
            elapsed: position(at: date),
            capturedAt: date,
            playbackRate: playbackRate,
            isPlaying: isPlaying,
            source: .cached
        )
    }
}

enum ProbeResult {
    case playing(PlaybackSnapshot)
    case otherPlayerActive
    case permissionNeeded
    case noPlayback
}

enum PlaybackAction { case toggle, backward, forward }

enum PlaybackProbe {
    static func fetch() -> ProbeResult {
        switch MediaRemoteProbe.fetch() {
        case .podcasts(let snapshot):
            return .playing(snapshot)
        case .otherPlayer:
            if case .playing(let snapshot) = AccessibilityProbe.fetch() {
                return .playing(snapshot)
            }
            return .otherPlayerActive
        case .unavailable:
            return AccessibilityProbe.fetch()
        }
    }

    static func perform(_ action: PlaybackAction, snapshot: PlaybackSnapshot) -> Bool {
        if AccessibilityProbe.press(action) { return true }
        guard snapshot.source == .mediaRemote else { return false }
        return MediaRemoteProbe.perform(action, snapshot: snapshot)
    }
}

private enum MediaRemoteProbe {
    enum FetchResult {
        case podcasts(PlaybackSnapshot)
        case otherPlayer
        case unavailable
    }

    private static var resources: URL? { Bundle.main.resourceURL }

    private static func run(_ arguments: [String]) -> Data? {
        guard let resources else { return nil }
        let script = resources.appendingPathComponent("mediaremote-adapter.pl")
        let framework = resources.appendingPathComponent("MediaRemoteAdapter.framework")
        guard FileManager.default.fileExists(atPath: script.path),
              FileManager.default.fileExists(atPath: framework.path) else { return nil }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        task.arguments = [script.path, framework.path] + arguments
        let output = Pipe()
        task.standardOutput = output
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return task.terminationStatus == 0 ? data : nil
        } catch {
            return nil
        }
    }

    static func fetch() -> FetchResult {
        guard let data = run(["get", "--now", "--allow-missing-title"]),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return .unavailable }
        guard raw["bundleIdentifier"] as? String == "com.apple.podcasts" else {
            return .otherPlayer
        }
        guard let title = raw["title"] as? String, !title.isEmpty else { return .unavailable }
        let artwork = (raw["artworkData"] as? String).flatMap { Data(base64Encoded: $0) }
        return .podcasts(PlaybackSnapshot(
            title: title,
            show: (raw["artist"] as? String) ?? (raw["album"] as? String),
            artwork: artwork,
            episodeID: nil,
            duration: (raw["duration"] as? NSNumber)?.doubleValue,
            elapsed: (raw["elapsedTimeNow"] as? NSNumber)?.doubleValue
                ?? (raw["elapsedTime"] as? NSNumber)?.doubleValue,
            capturedAt: Date(),
            playbackRate: (raw["playbackRate"] as? NSNumber)?.doubleValue ?? 1,
            isPlaying: (raw["playing"] as? Bool) ?? false,
            source: .mediaRemote
        ))
    }

    static func perform(_ action: PlaybackAction, snapshot: PlaybackSnapshot) -> Bool {
        switch action {
        case .toggle:
            return run(["send", snapshot.isPlaying ? "1" : "0"]) != nil
        case .backward:
            return run(["send", "12"]) != nil
        case .forward:
            guard let position = snapshot.position(at: Date()) else { return false }
            let next = min(snapshot.duration ?? position + 30, position + 30)
            return run(["seek", String(Int(next * 1_000_000))]) != nil
        }
    }
}

private enum AccessibilityProbe {
    private static let podcastBundleID = "com.apple.podcasts"

    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func string(_ element: AXUIElement, _ name: String) -> String? {
        attribute(element, name) as? String
    }

    private static func number(_ element: AXUIElement, _ name: String) -> Double? {
        (attribute(element, name) as? NSNumber)?.doubleValue
    }

    private static func elements(below root: AXUIElement, limit: Int = 1200) -> [AXUIElement] {
        var queue = [root]
        var result = [AXUIElement]()
        while !queue.isEmpty && result.count < limit {
            let element = queue.removeFirst()
            result.append(element)
            if let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] {
                queue.append(contentsOf: children)
            }
        }
        return result
    }

    private static func identifier(_ element: AXUIElement) -> String {
        string(element, kAXIdentifierAttribute) ?? ""
    }

    private static func matching(_ id: String, in elements: [AXUIElement]) -> AXUIElement? {
        elements.first { identifier($0).hasPrefix(id) }
    }

    static func fetch() -> ProbeResult {
        guard let application = NSRunningApplication.runningApplications(withBundleIdentifier: podcastBundleID).first else {
            return .noPlayback
        }
        guard AXIsProcessTrusted() else { return .permissionNeeded }
        let root = AXUIElementCreateApplication(application.processIdentifier)
        guard let windows = attribute(root, kAXWindowsAttribute) as? [AXUIElement] else { return .noPlayback }

        for window in windows {
            let all = elements(below: window)
            guard let mini = matching("podcasts.miniPlayer.contentView", in: all) else { continue }
            let player = elements(below: mini, limit: 100)
            guard let metadata = matching("podcasts.miniPlayer.metadataRegion", in: player),
                  let control = matching("podcasts.miniPlayer.playbackTransportControl", in: player) else { continue }
            let metadataElements = elements(below: metadata, limit: 30)
            let title = metadataElements.compactMap { element -> String? in
                let id = identifier(element)
                guard id.isEmpty, string(element, kAXRoleAttribute) != kAXButtonRole else { return nil }
                let description = string(element, kAXDescriptionAttribute) ?? ""
                return description.isEmpty ? nil : description
            }.first ?? string(window, kAXTitleAttribute)
            guard let title, !title.isEmpty else { continue }

            let controlLabel = string(control, kAXDescriptionAttribute) ?? ""
            let isPlaying = controlLabel.localizedCaseInsensitiveContains("pause")
                || controlLabel.contains("暂停")
            let slider = matching("podcasts.miniPlayer.playbackSlider", in: player)
            let sliderValue = slider.flatMap { number($0, kAXValueAttribute) }
            let sliderMin = slider.flatMap { number($0, kAXMinValueAttribute) } ?? 0
            let sliderMax = slider.flatMap { number($0, kAXMaxValueAttribute) }

            var episodeID: String?
            var duration: TimeInterval?
            var show: String?
            if string(window, kAXTitleAttribute) == title {
                for element in all {
                    let id = identifier(element)
                    if id.hasPrefix("podcasts.shelfItem.episodeHeaderRegular") {
                        episodeID = capture("id=([0-9]+)", from: id)
                        duration = capture("duration=([0-9.]+)", from: id).flatMap(Double.init)
                    }
                    if id.hasPrefix("podcasts.productPage.showProvider") {
                        show = string(element, kAXDescriptionAttribute)
                    }
                }
            }

            var elapsed: TimeInterval?
            if let sliderValue, let sliderMax, sliderMax > sliderMin,
               !(sliderValue == 0 && (slider.flatMap { string($0, kAXValueDescriptionAttribute) } ?? "").localizedCaseInsensitiveContains("not playing")) {
                if sliderMax > 1 { elapsed = sliderValue }
                else if let duration { elapsed = (sliderValue - sliderMin) / (sliderMax - sliderMin) * duration }
            }

            return .playing(PlaybackSnapshot(
                title: title,
                show: show,
                artwork: nil,
                episodeID: episodeID,
                duration: duration,
                elapsed: elapsed,
                capturedAt: Date(),
                playbackRate: 1,
                isPlaying: isPlaying,
                source: .accessibility
            ))
        }
        return .noPlayback
    }

    static func press(_ action: PlaybackAction) -> Bool {
        guard AXIsProcessTrusted(),
              let application = NSRunningApplication.runningApplications(withBundleIdentifier: podcastBundleID).first else { return false }
        let target: String
        switch action {
        case .toggle: target = "podcasts.miniPlayer.playbackTransportControl"
        case .backward: target = "podcasts.miniPlayer.leadingTransportControl"
        case .forward: target = "podcasts.miniPlayer.trailingTransportControl"
        }
        let root = AXUIElementCreateApplication(application.processIdentifier)
        guard let windows = attribute(root, kAXWindowsAttribute) as? [AXUIElement] else { return false }
        for window in windows {
            if let button = matching(target, in: elements(below: window)) {
                return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
            }
        }
        return false
    }

    private static func capture(_ pattern: String, from text: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
}
