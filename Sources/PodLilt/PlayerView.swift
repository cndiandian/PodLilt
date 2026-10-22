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
            if #available(macOS 15.0, *) {
                playerBody
                    .gesture(WindowDragGesture())
                    .allowsWindowActivationEvents()
            } else {
                playerBody
            }
        }
        .alert(model.text(.currentControlUnavailable), isPresented: commandFailureBinding) {
            Button(model.text(.openPodcasts)) { model.openPodcasts() }
            Button(model.text(.ok), role: .cancel) {}
        } message: {
            Text(model.text(.controlUnavailableMessage))
        }
    }

    private var commandFailureBinding: Binding<Bool> {
        Binding(
            get: { model.commandFailed },
            set: { if !$0 { model.dismissCommandFailure() } }
        )
    }

    private var playerBody: some View {
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
                case .loading: message(symbol: "waveform", title: model.text(.connecting), detail: model.text(.readingPlayback))
                case .empty: message(symbol: "waveform", title: model.text(.emptyTitle), detail: model.text(.emptyDetail))
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
            Text("PodLilt")
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
            .help(model.text(.openPodcasts))
            .accessibilityLabel(model.text(.openPodcasts))
        }
        .frame(height: 26)
    }

    private var sizePicker: some View {
        Menu {
            ForEach(PlayerSize.allCases) { size in
                sizeOption(size)
            }
            Divider()
            languageMenu
            Divider()
            Button(model.text(.about)) { (NSApp.delegate as? AppDelegate)?.showAbout() }
            Divider()
            quitMenuItem
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
        .help(model.text(.settings))
        .accessibilityLabel(model.text(.settings))
    }

    private func sizeOption(_ size: PlayerSize) -> some View {
        Button {
            model.setSize(size)
        } label: {
            if model.playerSize == size {
                Label(model.text(size.titleKey), systemImage: "checkmark")
            } else {
                Text(model.text(size.titleKey))
            }
        }
    }

    private var languageMenu: some View {
        Menu(model.text(.language)) {
            ForEach(LanguagePreference.allCases) { preference in
                Button {
                    model.setLanguage(preference)
                } label: {
                    if model.languagePreference == preference {
                        Label(preference.title(using: model.language), systemImage: "checkmark")
                    } else {
                        Text(preference.title(using: model.language))
                    }
                }
            }
        }
    }

    private var quitMenuItem: some View {
        Button(model.text(.quit)) { NSApp.terminate(nil) }
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
                    .help(model.text(.openPodcasts))
                }
                HStack(spacing: 1) {
                    compactControl("gobackward.15", label: model.text(.back15), action: .backward)
                    compactControl(model.snapshot?.isPlaying == true ? "pause.fill" : "play.fill",
                                   label: model.text(model.snapshot?.isPlaying == true ? .pause : .play), action: .toggle)
                    compactControl("goforward.30", label: model.text(.forward30), action: .forward)
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
            Text(model.state == .permission ? model.text(.accessibilityRequired) :
                 model.state == .loading ? model.text(.connecting) : model.text(.emptyTitle))
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
            if model.state == .permission {
                Button(model.text(.enablePermission), action: model.requestAccessibility)
                    .font(.system(size: 10, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.accent)
            } else {
                Text(model.text(.openAndPlay))
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
        .accessibilityLabel(model.text(.playbackProgress))
        .accessibilityValue(position.map(formatTime) ?? model.text(.unknown))
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
            .accessibilityValue(model.text(model.snapshot?.isPlaying == true ? .playing : .notPlaying))
            .overlay {
                if hoveringSmallArtwork, model.state == .ready {
                    ZStack {
                        Color.black.opacity(0.42)
                        smallControl(
                            model.snapshot?.isPlaying == true ? "pause.fill" : "play.fill",
                            label: model.text(model.snapshot?.isPlaying == true ? .pause : .play),
                            action: .toggle,
                            isPrimary: true
                        )
                        VStack {
                            Spacer()
                            HStack {
                                smallControl("gobackward.15", label: model.text(.back15), action: .backward)
                                Spacer()
                                smallControl("goforward.30", label: model.text(.forward30), action: .forward)
                            }
                            .padding(.horizontal, 7)
                            .padding(.bottom, 7)
                        }
                        VStack {
                            Spacer()
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                smallProgress(at: context.date)
                            }
                        }
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
                    sizeOption(size)
                }
                Divider()
                languageMenu
                Button(model.text(.openPodcasts), action: model.openPodcasts)
                Divider()
                Button(model.text(.about)) { (NSApp.delegate as? AppDelegate)?.showAbout() }
                Divider()
                quitMenuItem
            }
            .onContinuousHover { phase in
                switch phase {
                case .active: hoveringSmallArtwork = true
                case .ended: hoveringSmallArtwork = false
                }
            }
    }

    private func smallProgress(at date: Date) -> some View {
        let position = model.position(at: date)
        let duration = model.duration
        let fraction = (position != nil && duration != nil && duration! > 0)
            ? min(1, max(0, position! / duration!)) : 0
        return GeometryReader { geometry in
            Rectangle()
                .fill(.white)
                .frame(width: geometry.size.width * fraction)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func smallControl(
        _ symbol: String,
        label: String,
        action: PlaybackAction,
        isPrimary: Bool = false
    ) -> some View {
        Button { model.perform(action) } label: {
            Image(systemName: symbol)
                .font(.system(size: isPrimary ? 23 : 14, weight: .semibold))
                .frame(width: isPrimary ? 46 : 16, height: isPrimary ? 46 : 16)
                .background(.black.opacity(0.68), in: Circle())
                .frame(width: isPrimary ? 46 : 26, height: isPrimary ? 46 : 26)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
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
                        Text(model.text(model.snapshot?.isPlaying == true ? .playing : .notPlaying))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Palette.muted)
                    }
                }
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                progress(at: context.date)
            }
            controls
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
        .accessibilityLabel(model.text(.artwork))
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
        .accessibilityLabel(model.text(.playbackProgress))
        .accessibilityValue(position.map(formatTime) ?? model.text(.unknown))
    }

    private var controls: some View {
        HStack(spacing: 28) {
            controlButton("gobackward.15", label: model.text(.back15), action: .backward)
            Button { model.perform(.toggle) } label: {
                Image(systemName: model.snapshot?.isPlaying == true ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 46, height: 36)
                    .background(Palette.accent, in: RoundedRectangle(cornerRadius: 11))
                    .foregroundStyle(Palette.background)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.text(model.snapshot?.isPlaying == true ? .pause : .play))
            controlButton("goforward.30", label: model.text(.forward30), action: .forward)
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
            Text(model.text(.accessibilityRequired))
                .font(.system(size: 14, weight: .semibold))
            Text(model.text(.accessibilityDetail))
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
            Button(model.text(.enableAccessibility), action: model.requestAccessibility)
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
