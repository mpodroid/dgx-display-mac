import AppKit
import DGXDisplayCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    let store = Store()
    let session = HeadSession()
    let localNetwork = LocalNetworkProbe()
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var timer: Timer?
    var settingsWindow: NSWindow?
    private var showingMenu = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let hosting = NSHostingController(rootView: PanelView(store: store))
        hosting.sizingOptions = .preferredContentSize
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.black.cgColor
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentViewController = hosting
        popover.delegate = self

        store.onLive = { [weak self] in
            self?.session.noteLive()
        }
        store.onCommit = { [weak self] launch in
            self?.localNetwork.arm(launch.host)
            self?.session.retarget(launch)
        }
        localNetwork.onGranted = { [weak self] in
            self?.session.retryIfDown()
        }
        store.armClock()
        session.bind(store)
        localNetwork.arm(store.launch.host)
        session.start(store.launch)
        refreshIcon()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshIcon()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        session.stop()
    }

    func popoverDidClose(_ notification: Notification) {
        store.commitConnection()
    }

    @objc func statusClick(_ sender: Any?) {
        if showingMenu { return }
        let event = NSApp.currentEvent
        let right = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
        if right {
            showMenu()
            return
        }
        togglePopover(sender)
    }

    private func showMenu() {
        let menu = NSMenu()
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        showingMenu = true
        statusItem.menu = menu
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.statusItem.button?.performClick(nil)
            self.statusItem.menu = nil
            self.showingMenu = false
        }
    }

    @objc func openSettings() {
        popover.performClose(nil)
        let window: NSWindow
        if let settingsWindow {
            window = settingsWindow
        } else {
            window = makeSettingsWindow()
            settingsWindow = window
            window.center()
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeSettingsWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsView(store: store))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        return window
    }

    func windowDidResignKey(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        store.commitConnection()
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        store.commitConnection()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate()
        }
    }

    private var iconKey: String?

    private func refreshIcon() {
        let now = Date()
        let face = store.face(at: now)
        let mark = menuMark(face: face, sample: store.sample, now: now)
        guard mark.key != iconKey, let button = statusItem.button else { return }
        iconKey = mark.key
        let image: NSImage
        if mark.title.isEmpty {
            image = wordIcon(mark.state)
            button.imagePosition = .imageOnly
            button.title = ""
        } else {
            image = stateDot(mark.state.rgb)
            button.imagePosition = .imageLeading
            button.title = mark.title
        }
        image.isTemplate = false
        button.image = image
        button.image?.isTemplate = false
        button.toolTip = mark.tooltip
    }

    private func stateColor(_ rgb: RGB) -> NSColor {
        NSColor(
            srgbRed: Double(rgb.r) / 255,
            green: Double(rgb.g) / 255,
            blue: Double(rgb.b) / 255,
            alpha: 1
        )
    }

    /// Colored mark for SERVE and STALL. The rates are the button title.
    private func stateDot(_ rgb: RGB) -> NSImage {
        let side: CGFloat = 14
        let color = stateColor(rgb)
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    private func wordIcon(_ piece: MenuPiece) -> NSImage {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
        let text = NSAttributedString(string: piece.text, attributes: [
            .font: font,
            .foregroundColor: stateColor(piece.rgb),
        ])
        let image = NSImage(size: text.size(), flipped: false) { rect in
            text.draw(in: rect)
            return true
        }
        image.isTemplate = false
        return image
    }
}

@main
enum DGXDisplayMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
