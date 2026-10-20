import AppKit
import SwiftUI

struct AboutView: View {
    @ObservedObject var model: PlayerModel
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)

            VStack(spacing: 5) {
                Text("PodLilt")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text("\(model.text(.version)) \(version)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 9) {
                infoRow(model.text(.appName), value: "PodLilt")
                linkRow(model.text(.feedback), title: "support@podlilt.com", url: "mailto:support@podlilt.com")
                linkRow(model.text(.twitter), title: "@callmediandian", url: "https://x.com/callmediandian")
                linkRow(model.text(.github), title: "https://github.com/cndiandian/PodLilt", url: "https://github.com/cndiandian/PodLilt")
            }
            .font(.system(size: 12))

            Text("Copyright © 2026 diandian")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .frame(width: 420, height: 310)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }
    }

    private func linkRow(_ label: String, title: String, url: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            if let destination = URL(string: url) {
                Link(title, destination: destination)
            } else {
                Text(title)
            }
        }
    }
}
