import AppKit
import SwiftUI

@main
struct PodMiniPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = PlayerModel()
    private var panel: PlayerPanel?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        makePanel()
        makeStatusItem()
        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    private func makePanel() {
        let size = NSSize(width: 360, height: 236)
        let panel = PlayerPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Pod Mini Player"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: PlayerView(model: model))

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - 24,
                                         y: visible.maxY - size.height - 24))
        } else {
            panel.center()
        }
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func makeStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Pod Mini Player")
        item.button?.toolTip = "Pod Mini Player"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示或隐藏播放器", action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "打开 Podcasts", action: #selector(openPodcasts), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible { panel.orderOut(nil) }
        else { panel.orderFrontRegardless(); model.refresh() }
    }

    @objc private func openPodcasts() { model.openPodcasts() }
    @objc private func quit() { NSApp.terminate(nil) }
}

private final class PlayerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
