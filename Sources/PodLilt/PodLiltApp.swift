import AppKit
import SwiftUI

@main
@MainActor
enum PodLiltApp {
    private static let delegate = AppDelegate()

    static func main() {
        let application = NSApplication.shared
        application.delegate = delegate
        application.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = PlayerModel()
    private var panel: PlayerPanel?
    private var aboutWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var sizeItems = [NSMenuItem]()
    private var languageItems = [NSMenuItem]()
    private var moveTimer: Timer?
    private var isCorrectingPosition = false
    private let windowOriginKey = "playerWindowOrigin"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        makePanel()
        makeStatusItem()
        model.onSizeChanged = { [weak self] size in self?.applySize(size) }
        model.onLanguageChanged = { [weak self] in self?.applyLanguage() }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemLocaleDidChange),
            name: NSLocale.currentLocaleDidChangeNotification,
            object: nil
        )
        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        moveTimer?.invalidate()
        keepPanelOnScreen()
        savePanelOrigin()
    }

    private func makePanel() {
        let size = model.playerSize.dimensions
        let panel = PlayerPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "PodLilt"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.contentView = NSHostingView(rootView: PlayerView(model: model))
        panel.delegate = self

        if let savedOrigin = savedPanelOrigin {
            let savedFrame = NSRect(origin: savedOrigin, size: panel.frame.size)
            panel.setFrameOrigin(onScreenOrigin(for: savedFrame) ?? savedOrigin)
        } else if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - 24,
                                         y: visible.maxY - size.height - 24))
        } else {
            panel.center()
        }
        panel.orderFrontRegardless()
        self.panel = panel
        savePanelOrigin()
    }

    private func makeStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "PodLilt")
        item.button?.toolTip = "PodLilt"
        statusItem = item
        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        guard let statusItem else { return }
        sizeItems.removeAll()
        languageItems.removeAll()
        let menu = NSMenu()
        menu.addItem(actionItem(title: model.text(.showHidePlayer), action: #selector(togglePanel)))
        menu.addItem(actionItem(title: model.text(.openPodcasts), action: #selector(openPodcasts)))
        let sizeMenu = NSMenu()
        for (index, size) in PlayerSize.allCases.enumerated() {
            let entry = NSMenuItem(title: model.text(size.titleKey), action: #selector(selectSize(_:)), keyEquivalent: String(index + 1))
            entry.keyEquivalentModifierMask = [.command]
            entry.representedObject = size.rawValue
            entry.state = size == model.playerSize ? .on : .off
            entry.target = self
            sizeMenu.addItem(entry)
            sizeItems.append(entry)
        }
        let sizeItem = NSMenuItem(title: model.text(.windowMode), action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        let languageMenu = NSMenu()
        for preference in LanguagePreference.allCases {
            let entry = NSMenuItem(
                title: preference.title(using: model.language),
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            entry.representedObject = preference.rawValue
            entry.state = preference == model.languagePreference ? .on : .off
            entry.target = self
            languageMenu.addItem(entry)
            languageItems.append(entry)
        }
        let languageItem = NSMenuItem(title: model.text(.language), action: nil, keyEquivalent: "")
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)
        menu.addItem(.separator())
        menu.addItem(actionItem(title: model.text(.about), action: #selector(showAbout)))
        menu.addItem(.separator())
        menu.addItem(actionItem(title: model.text(.quit), action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func actionItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
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

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let preference = LanguagePreference(rawValue: rawValue) else { return }
        model.setLanguage(preference)
    }

    @objc private func systemLocaleDidChange() {
        model.refreshSystemLanguage()
    }

    private func applyLanguage() {
        rebuildStatusMenu()
        aboutWindow?.title = model.text(.aboutPodLilt)
    }

    private func applySize(_ size: PlayerSize) {
        guard let panel else { return }
        let topRight = NSPoint(x: panel.frame.maxX, y: panel.frame.maxY)
        isCorrectingPosition = true
        panel.setContentSize(size.dimensions)
        panel.setFrameOrigin(NSPoint(x: topRight.x - panel.frame.width,
                                     y: topRight.y - panel.frame.height))
        isCorrectingPosition = false
        keepPanelOnScreen()
        savePanelOrigin()
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
        savePanelOrigin()
    }

    private func keepPanelOnScreen() {
        guard let panel else { return }
        let frame = panel.frame
        guard let origin = onScreenOrigin(for: frame), origin != frame.origin else { return }
        isCorrectingPosition = true
        panel.setFrameOrigin(origin)
        isCorrectingPosition = false
    }

    private func onScreenOrigin(for frame: NSRect) -> NSPoint? {
        guard let screen = NSScreen.screens.min(by: { left, right in
            distanceSquared(from: frame, to: left.visibleFrame)
                < distanceSquared(from: frame, to: right.visibleFrame)
        }) else { return nil }
        let visible = screen.visibleFrame
        let maxX = max(visible.minX, visible.maxX - frame.width)
        let maxY = max(visible.minY, visible.maxY - frame.height)
        return NSPoint(x: min(max(frame.minX, visible.minX), maxX),
                       y: min(max(frame.minY, visible.minY), maxY))
    }

    private var savedPanelOrigin: NSPoint? {
        guard let coordinates = UserDefaults.standard.array(forKey: windowOriginKey) as? [NSNumber],
              coordinates.count == 2 else { return nil }
        let x = coordinates[0].doubleValue
        let y = coordinates[1].doubleValue
        guard x.isFinite, y.isFinite else { return nil }
        return NSPoint(x: x, y: y)
    }

    private func savePanelOrigin() {
        guard let origin = panel?.frame.origin else { return }
        UserDefaults.standard.set([Double(origin.x), Double(origin.y)], forKey: windowOriginKey)
    }

    private func distanceSquared(from window: NSRect, to screen: NSRect) -> CGFloat {
        let x = max(0, max(screen.minX - window.midX, window.midX - screen.maxX))
        let y = max(0, max(screen.minY - window.midY, window.midY - screen.maxY))
        return x * x + y * y
    }

    @objc func showAbout() {
        if aboutWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: NSSize(width: 420, height: 310)),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = model.text(.aboutPodLilt)
            window.isReleasedWhenClosed = false
            window.center()
            window.contentView = NSHostingView(rootView: AboutView(model: model))
            aboutWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openPodcasts() { model.openPodcasts() }
    @objc private func quit() { NSApp.terminate(nil) }
}

private final class PlayerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
