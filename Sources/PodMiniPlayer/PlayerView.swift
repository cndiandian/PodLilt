import AppKit
import SwiftUI

private enum Palette {
    static let background = Color(red: 0.105, green: 0.11, blue: 0.14)
    static let raised = Color(red: 0.17, green: 0.18, blue: 0.22)
    static let line = Color.white.opacity(0.12)
    static let muted = Color(red: 0.69, green: 0.70, blue: 0.74)
    static let accent = Color.white
    static let playingIndicator = Color(red: 0.20, green: 0.78, blue: 0.35)
}

struct PlayerView: View {
    @ObservedObject var model: PlayerModel
    @State private var hoveringSmallArtwork = false

    var body: some View {
        Group {
            switch model.playerSize {
            case .large: largeContent
            case .medium: mediumContent
            case .small: smallContent
            }
        }
        .frame(width: model.playerSize.dimensions.width,
               height: model.playerSize.dimensions.height)
        .background(Palette.background, in: RoundedRectangle(cornerRadius: model.playerSize == .small ? 16 : 20, style: .continuous))
        .overlay {
            if model.playerSize != .small {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Palette.line, lineWidth: 1)
            }
        }
        .foregroundStyle(.white)
        .onChange(of: model.playerSize) { _, _ in hoveringSmallArtwork = false }
    }

    private var largeContent: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch model.state {
                case .ready: playerContent
                case .loading: message(symbol: "waveform", title: "正在连接 Podcasts", detail: "读取当前播放内容…")
                case .empty: message(symbol: "waveform", title: "还没有播放内容", detail: "在 Podcasts 中播放一集，内容会出现在这里。")
                case .permission: permissionContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Circle().fill(Palette.accent).frame(width: 6, height: 6)
            Text("PODCASTS")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(Palette.muted)
            Spacer()
            sizePicker
            Button(action: model.openPodcasts) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.muted)
            .help("打开 Podcasts")
            .accessibilityLabel("打开 Podcasts")
        }
        .frame(height: 26)
    }

    private var sizePicker: some View {
        Menu {
            ForEach(PlayerSize.allCases) { size in
                Button {
                    model.setSize(size)
                } label: {
                    if model.playerSize == size {
                        Label(size.title, systemImage: "checkmark")
                    } else {
                        Text(size.title)
                    }
                }
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.muted)
                .frame(width: 26, height: 26)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 26, height: 26)
        .environment(\.colorScheme, .dark)
        .foregroundStyle(Palette.muted)
        .help("切换窗口尺寸")
        .accessibilityLabel("切换窗口尺寸")
    }

    private var mediumContent: some View {
        HStack(spacing: 9) {
            artwork(side: 58)
            Group {
                if model.state == .ready {
                    mediumPlaybackInfo
                } else {
                    mediumMessage
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    sizePicker
                    Button(action: model.openPodcasts) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.muted)
                    .help("打开 Podcasts")
                }
                HStack(spacing: 1) {
                    compactControl("gobackward.15", label: "后退 15 秒", action: .backward)
                    compactControl(model.snapshot?.isPlaying == true ? "pause.fill" : "play.fill",
                                   label: model.snapshot?.isPlaying == true ? "暂停" : "播放", action: .toggle)
                    compactControl("goforward.30", label: "前进 30 秒", action: .forward)
                }
                .disabled(model.state != .ready)
            }
        }
        .padding(.horizontal, 10)
    }

    private var mediumPlaybackInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            ScrollingTitle(title: model.title, fontSize: 12, height: 16)
            Text(model.show)
                .font(.system(size: 10))
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                compactProgress(at: context.date)
            }
        }
    }

    private var mediumMessage: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.state == .permission ? "需要辅助功能权限" :
                 model.state == .loading ? "正在连接 Podcasts" : "还没有播放内容")
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
            if model.state == .permission {
                Button("开启权限", action: model.requestAccessibility)
                    .font(.system(size: 10, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.accent)
            } else {
                Text("打开 Podcasts 播放一集")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
        }
    }

    private func compactProgress(at date: Date) -> some View {
        let position = model.position(at: date)
        let duration = model.duration
        let fraction = (position != nil && duration != nil && duration! > 0)
            ? min(1, max(0, position! / duration!)) : 0
        return VStack(spacing: 2) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.raised)
                    Capsule().fill(Palette.accent).frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: 3)
            HStack {
                Text(position.map(formatTime) ?? "--:--")
                Spacer(minLength: 2)
                Text(duration.map { "-" + formatTime(max(0, $0 - (position ?? 0))) } ?? "--:--")
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(Palette.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("播放进度")
        .accessibilityValue(position.map(formatTime) ?? "未知")
    }

    private func compactControl(_ symbol: String, label: String, action: PlaybackAction) -> some View {
        Button { model.perform(action) } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 27, height: 27)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    private var smallContent: some View {
        artwork(side: 96, cornerRadius: 16, showsBorder: false)
            .accessibilityValue(model.snapshot?.isPlaying == true ? "正在播放" : "已暂停")
            .overlay {
                if hoveringSmallArtwork, model.state == .ready {
                    ZStack {
                        Color.black.opacity(0.42)
                        Button { model.perform(.toggle) } label: {
                            Image(systemName: model.snapshot?.isPlaying == true ? "pause.fill" : "play.fill")
                                .font(.system(size: 23, weight: .semibold))
                                .frame(width: 46, height: 46)
                                .background(.black.opacity(0.65), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(model.snapshot?.isPlaying == true ? "暂停" : "播放")
                    }
                    .transition(.opacity)
                }
            }
            .overlay(alignment: .topTrailing) {
                if model.snapshot?.isPlaying == true {
                    Circle()
                        .fill(Palette.playingIndicator)
                        .frame(width: 6, height: 6)
                        .shadow(color: .black.opacity(0.8), radius: 1)
                        .padding(10)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contextMenu {
                ForEach(PlayerSize.allCases) { size in
                    Button(size.title) { model.setSize(size) }
                }
                Button("打开 Podcasts", action: model.openPodcasts)
            }
            .onContinuousHover { phase in
                switch phase {
                case .active: hoveringSmallArtwork = true
                case .ended: hoveringSmallArtwork = false
                }
            }
    }

    private var playerContent: some View {
        VStack(spacing: 13) {
            HStack(alignment: .center, spacing: 14) {
                artwork(side: 78)
                VStack(alignment: .leading, spacing: 6) {
                    ScrollingTitle(title: model.title, fontSize: 14, height: 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                    Text(model.show)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(model.snapshot?.isPlaying == true ? Palette.accent : Palette.muted)
                            .frame(width: 5, height: 5)
                        Text(model.snapshot?.isPlaying == true ? "正在播放" : "已暂停")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Palette.muted)
                    }
                }
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                progress(at: context.date)
            }
            controls
            if model.commandFailed {
                Text("控制未生效，请检查辅助功能权限")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.top, 8)
    }

    private func artwork(side: CGFloat, cornerRadius: CGFloat = 11, showsBorder: Bool = true) -> some View {
        Group {
            if let image = model.artwork {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Palette.raised
                    Image(systemName: "waveform")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(Palette.accent)
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            if showsBorder {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Palette.line, lineWidth: 1)
            }
        }
        .accessibilityLabel("节目封面")
    }

    private func progress(at date: Date) -> some View {
        let position = model.position(at: date)
        let duration = model.duration
        let fraction = (position != nil && duration != nil && duration! > 0)
            ? min(1, max(0, position! / duration!)) : 0
        return VStack(spacing: 5) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.raised)
                    Capsule().fill(Palette.accent).frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: 5)
            HStack {
                Text(position.map(formatTime) ?? "--:--")
                Spacer()
                Text(duration.map { "-" + formatTime(max(0, $0 - (position ?? 0))) } ?? "--:--")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Palette.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("播放进度")
        .accessibilityValue(position.map(formatTime) ?? "未知")
    }

    private var controls: some View {
        HStack(spacing: 28) {
            controlButton("gobackward.15", label: "后退 15 秒", action: .backward)
            Button { model.perform(.toggle) } label: {
                Image(systemName: model.snapshot?.isPlaying == true ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 46, height: 36)
                    .background(Palette.accent, in: RoundedRectangle(cornerRadius: 11))
                    .foregroundStyle(Palette.background)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.snapshot?.isPlaying == true ? "暂停" : "播放")
            controlButton("goforward.30", label: "前进 30 秒", action: .forward)
        }
        .frame(maxWidth: .infinity)
    }

    private func controlButton(_ symbol: String, label: String, action: PlaybackAction) -> some View {
        Button { model.perform(action) } label: {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .regular))
                .frame(width: 42, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .help(label)
        .accessibilityLabel(label)
    }

    private var permissionContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.tap")
                .font(.system(size: 25))
                .foregroundStyle(Palette.accent)
            Text("允许读取 Podcasts 控件")
                .font(.system(size: 14, weight: .semibold))
            Text("需要辅助功能权限来读取播放信息并控制播放。")
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
            Button("开启辅助功能权限", action: model.requestAccessibility)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(Palette.accent, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(Palette.background)
        }
        .padding(.horizontal, 14)
    }

    private func message(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Palette.accent)
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 18)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let seconds = Int(max(0, interval))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainder = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remainder)
            : String(format: "%d:%02d", minutes, remainder)
    }
}

private struct ScrollingTitle: View {
    let title: String
    let fontSize: CGFloat
    let height: CGFloat
    @State private var startedAt = Date()
    private let spacing: CGFloat = 24
    private let speed: CGFloat = 34

    private var textWidth: CGFloat {
        ceil((title as NSString).size(withAttributes: [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        ]).width)
    }

    var body: some View {
        GeometryReader { geometry in
            let overflow = max(0, textWidth - geometry.size.width)
            if overflow > 1 {
                TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
                    HStack(spacing: spacing) {
                        titleText.frame(width: textWidth, alignment: .leading)
                        titleText.frame(width: textWidth, alignment: .leading)
                    }
                        .fixedSize(horizontal: true, vertical: false)
                        .offset(x: offset(at: context.date, distance: textWidth + spacing))
                        .frame(width: geometry.size.width, height: height, alignment: .leading)
                        .clipped()
                }
            } else {
                titleText
                    .frame(width: geometry.size.width, height: height, alignment: .leading)
                    .clipped()
            }
        }
        .frame(height: height)
        .onChange(of: title) { _, _ in startedAt = Date() }
        .help(title)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    private var titleText: some View {
        Text(title)
            .font(.system(size: fontSize, weight: .semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func offset(at date: Date, distance: CGFloat) -> CGFloat {
        let pause = 2.0
        let travel = Double(distance / speed)
        let cycle = travel + pause
        let elapsed = max(0, date.timeIntervalSince(startedAt)).truncatingRemainder(dividingBy: cycle)
        return -min(CGFloat(elapsed) * speed, distance)
    }
}

struct PlayerSettingsView: View {
    @ObservedObject var model: PlayerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("窗口尺寸")
                .font(.system(size: 16, weight: .semibold))
            Picker("窗口尺寸", selection: Binding(
                get: { model.playerSize },
                set: { model.setSize($0) }
            )) {
                ForEach(PlayerSize.allCases) { size in
                    Text(size.title).tag(size)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text("大尺寸显示完整播放器；中尺寸保留全部控制；小尺寸只显示封面，悬停时可播放或暂停。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 360)
    }
}
