import AppKit
import Combine
import Foundation

@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var message: L10nKey?

    private struct Release: Decodable {
        let tag_name: String
        let assets: [Asset]
    }

    private struct Asset: Decodable {
        let name: String
        let browser_download_url: URL
    }

    func check() async {
        guard !busy else { return }
        busy = true
        message = .checkingUpdates
        defer { busy = false }
        do {
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/cndiandian/PodLilt/releases/latest")!)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("PodLilt", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 30
            let (data, response) = try await URLSession.shared.data(for: request)
            if (response as? HTTPURLResponse)?.statusCode == 404 {
                message = .noUpdates
                return
            }
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let release = try JSONDecoder().decode(Release.self, from: data)
            let latest = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
            guard latest.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil else { throw URLError(.cannotParseResponse) }
            guard latest.compare(current, options: .numeric) == .orderedDescending else {
                message = .noUpdates
                return
            }
            guard let asset = release.assets.first(where: { $0.name == "PodLilt-v\(latest).dmg" }),
                  asset.browser_download_url.scheme == "https",
                  asset.browser_download_url.host == "github.com",
                  asset.browser_download_url.path.hasPrefix("/cndiandian/PodLilt/releases/download/") else {
                message = .updateAssetUnavailable
                return
            }
            message = .downloadingUpdate
            let (temporary, downloadResponse) = try await URLSession.shared.download(from: asset.browser_download_url)
            defer { try? FileManager.default.removeItem(at: temporary) }
            guard (downloadResponse as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let directory = try FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("PodLilt-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appendingPathComponent(asset.name)
            try FileManager.default.moveItem(at: temporary, to: destination)
            guard NSWorkspace.shared.open(destination) else { throw URLError(.cannotOpenFile) }
            message = .updateReady
        } catch {
            message = .updateFailed
        }
    }
}
