import AppKit
import SwiftUI

@main
struct PodMiniPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { PlayerSettingsView(model: delegate.model) }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = PlayerModel()
    private var panel: PlayerPanel?
    private var statusItem: NSStatusItem?
    private var sizeItems = [NSMenuItem]()
    private var moveTimer: Timer?
    private var isCorrectingPosition = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        makePanel()
        makeStatusItem()
        model.onSizeChanged = { [weak self] size in self?.applySize(size) }
        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        moveTimer?.invalidate()
    }

    private func makePanel() {
        let size = model.playerSize.dimensions
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
        panel.acceptsMouseMovedEvents = true
        panel.contentView = NSHostingView(rootView: PlayerView(model: model))
        panel.delegate = self

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
        let sizeMenu = NSMenu()
        for (index, size) in PlayerSize.allCases.enumerated() {
            let entry = NSMenuItem(title: size.title, action: #selector(selectSize(_:)), keyEquivalent: String(index + 1))
            entry.keyEquivalentModifierMask = [.command]
            entry.representedObject = size.rawValue
            entry.state = size == model.playerSize ? .on : .off
            entry.target = self
            sizeMenu.addItem(entry)
            sizeItems.append(entry)
        }
        let sizeItem = NSMenuItem(title: "窗口尺寸", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)
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

    @objc private func selectSize(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let size = PlayerSize(rawValue: rawValue) else { return }
        model.setSize(size)
    }

    private func applySize(_ size: PlayerSize) {
        guard let panel else { return }
        let topRight = NSPoint(x: panel.frame.maxX, y: panel.frame.maxY)
        panel.setContentSize(size.dimensions)
        panel.setFrameOrigin(NSPoint(x: topRight.x - panel.frame.width,
                                     y: topRight.y - panel.frame.height))
        for item in sizeItems {
            item.state = item.representedObject as? String == size.rawValue ? .on : .off
        }
    }

    func windowDidMove(_ notification: Notification) {
        guard !isCorrectingPosition,
              let movedWindow = notification.object as? NSWindow,
              movedWindow === panel,
              moveTimer == nil else { return }
        moveTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self,
                                         selector: #selector(checkDragFinished(_:)),
                                         userInfo: nil, repeats: true)
    }

    @objc private func checkDragFinished(_ timer: Timer) {
        guard NSEvent.pressedMouseButtons == 0 else { return }
        timer.invalidate()
        moveTimer = nil
        keepPanelOnScreen()
    }

    private func keepPanelOnScreen() {
        guard let panel else { return }
        let frame = panel.frame
        guard let screen = NSScreen.screens.min(by: { left, right in
            distanceSquared(from: frame, to: left.visibleFrame)
                < distanceSquared(from: frame, to: right.visibleFrame)
        }) else { return }
        let visible = screen.visibleFrame
        let maxX = max(visible.minX, visible.maxX - frame.width)
        let maxY = max(visible.minY, visible.maxY - frame.height)
        let origin = NSPoint(x: min(max(frame.minX, visible.minX), maxX),
                             y: min(max(frame.minY, visible.minY), maxY))
        guard origin != frame.origin else { return }
        isCorrectingPosition = true
        panel.setFrameOrigin(origin)
        isCorrectingPosition = false
    }

    private func distanceSquared(from window: NSRect, to screen: NSRect) -> CGFloat {
        let x = max(0, max(screen.minX - window.midX, window.midX - screen.maxX))
        let y = max(0, max(screen.minY - window.midY, window.midY - screen.maxY))
        return x * x + y * y
    }

    @objc private func openPodcasts() { model.openPodcasts() }
    @objc private func quit() { NSApp.terminate(nil) }
}

private final class PlayerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
