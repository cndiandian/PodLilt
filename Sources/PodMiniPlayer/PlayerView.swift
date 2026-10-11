import SwiftUI

private enum Palette {
    static let background = Color(red: 0.105, green: 0.11, blue: 0.14)
    static let raised = Color(red: 0.17, green: 0.18, blue: 0.22)
    static let line = Color.white.opacity(0.12)
    static let muted = Color(red: 0.69, green: 0.70, blue: 0.74)
    static let accent = Color(red: 0.75, green: 0.59, blue: 1.0)
}

struct PlayerView: View {
    @ObservedObject var model: PlayerModel

    var body: some View {
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
        .frame(width: 360, height: 236)
        .background(Palette.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Palette.line, lineWidth: 1))
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Circle().fill(Palette.accent).frame(width: 6, height: 6)
            Text("PODCASTS")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(Palette.muted)
            Spacer()
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

    private var playerContent: some View {
        VStack(spacing: 13) {
            HStack(alignment: .center, spacing: 14) {
                artwork
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
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

    private var artwork: some View {
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
        .frame(width: 78, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Palette.line, lineWidth: 1))
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
