import AppKit
import QuartzCore
import SwiftUI

enum StatusColors {
    static let healthy = NSColor(calibratedRed: 0.13, green: 0.63, blue: 0.42, alpha: 1.0)
    static let danger = NSColor.systemRed
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private enum PopoverFade {
        static let fadeInDuration: TimeInterval = 0.07
        static let fadeOutDuration: TimeInterval = 0.20
    }

    private static let statusIconWidth: CGFloat = 14
    private static let statusGap: CGFloat = 4
    private var statusItem: NSStatusItem!
    private var statusIconView: ServerStatusIconView!
    private var statusView: StatusPillView!
    private var statusBarsWidthConstraint: NSLayoutConstraint!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var nodeObservationTask: Task<Void, Never>?
    private var appDeactivationObserver: NSObjectProtocol?
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var localKeyMonitor: Any?
    private var isClosingPopover = false
    private var store: KomariStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configurePopover(store: nil)

        do {
            try startMonitor(config: Config.load())
        } catch {
            showConfigError(error)
            showSettingsWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopOutsideClickMonitoring()
        stopAppDeactivationMonitoring()
        nodeObservationTask?.cancel()
        store?.stop()
    }

    @objc private func statusClicked() {
        togglePopover()
    }

    private func startMonitor(config: Config) {
        nodeObservationTask?.cancel()
        store?.stop()
        let store = KomariStore(config: config)
        self.store = store
        configurePopover(store: store)

        nodeObservationTask = Task { @MainActor in
            for await nodes in store.$nodes.values {
                self.updateStatusTitle(nodes)
                self.updatePopoverSize(nodes)
            }
        }
        store.start()
        updateStatusTitle([])
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusIconView = ServerStatusIconView(frame: NSRect(x: 0, y: 0, width: Self.statusIconWidth, height: 22))
        statusIconView.onClick = { [weak self] in self?.togglePopover() }

        statusView = StatusPillView(frame: NSRect(x: 0, y: 0, width: 4, height: 22))
        statusView.onClick = { [weak self] in self?.togglePopover() }
        if let button = statusItem.button {
            button.title = ""
            button.target = self
            button.action = #selector(statusClicked)
            statusIconView.translatesAutoresizingMaskIntoConstraints = false
            statusView.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(statusIconView)
            button.addSubview(statusView)
            statusBarsWidthConstraint = statusView.widthAnchor.constraint(equalToConstant: 4)
            NSLayoutConstraint.activate([
                statusIconView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                statusIconView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                statusIconView.widthAnchor.constraint(equalToConstant: Self.statusIconWidth),
                statusIconView.heightAnchor.constraint(equalToConstant: 22),
                statusView.leadingAnchor.constraint(equalTo: statusIconView.trailingAnchor, constant: Self.statusGap),
                statusView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                statusView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                statusView.heightAnchor.constraint(equalToConstant: 22),
                statusBarsWidthConstraint
            ])
        }
        updateStatusTitle([])
    }

    private func configurePopover(store: KomariStore?) {
        popover?.performClose(nil)
        stopOutsideClickMonitoring()
        stopAppDeactivationMonitoring()
        popover = NSPopover()
        popover.delegate = self
        popover.behavior = .applicationDefined
        popover.animates = false
        popover.contentSize = NSSize(
            width: MonitorPopoverLayout.contentWidth(nodeCount: 1),
            height: MonitorPopoverLayout.contentHeight(nodeCount: 1)
        )
        if let store {
            popover.contentViewController = NSHostingController(
                rootView: MonitorPopover(
                    store: store,
                    onOpenSettings: { [weak self] in self?.showSettingsWindow() }
                )
            )
        } else {
            popover.contentViewController = NSHostingController(
                rootView: MissingConfigView(
                    onOpenSettings: { [weak self] in self?.showSettingsWindow() },
                    onQuit: { NSApplication.shared.terminate(nil) }
                )
            )
        }
    }

    private func updateStatusTitle(_ nodes: [NodeViewModel]) {
        statusView.nodes = nodes
        let barWidth = CGFloat(max(1, nodes.count) * 4)
        statusBarsWidthConstraint.constant = barWidth
        statusItem.length = Self.statusIconWidth + Self.statusGap + barWidth
        statusView.needsDisplay = true
    }

    private func updatePopoverSize(_ nodes: [NodeViewModel]) {
        let width = MonitorPopoverLayout.contentWidth(nodeCount: nodes.count)
        let height = MonitorPopoverLayout.contentHeight(nodeCount: nodes.count)
        popover.contentSize = NSSize(width: width, height: height)
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            closePopoverLightly()
        } else {
            showPopoverLightly(relativeTo: button.bounds, of: button)
        }
    }

    private func showPopoverLightly(relativeTo rect: NSRect, of button: NSView) {
        isClosingPopover = false
        guard let contentController = popover.contentViewController else { return }
        contentController.view.alphaValue = 0
        popover.show(relativeTo: rect, of: button, preferredEdge: .minY)

        guard let window = contentController.view.window else {
            contentController.view.alphaValue = 1
            startOutsideClickMonitoring()
            return
        }

        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.alphaValue = 0
        window.makeFirstResponder(contentController.view)
        window.makeKey()
        contentController.view.alphaValue = 1
        startOutsideClickMonitoring()
        startAppDeactivationMonitoring()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = PopoverFade.fadeInDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }

    private func closePopoverLightly() {
        guard popover.isShown, !isClosingPopover else { return }
        isClosingPopover = true

        guard let window = popover.contentViewController?.view.window else {
            popover.performClose(nil)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = PopoverFade.fadeOutDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.popover.performClose(nil)
            }
        }
    }

    private func startOutsideClickMonitoring() {
        stopOutsideClickMonitoring()

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePopoverLightly()
            }
        }

        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self, self.popover.isShown else { return event }
            if self.isStatusButtonClick(event) {
                return event
            }
            guard let popoverWindow = self.popover.contentViewController?.view.window else {
                self.closePopoverLightly()
                return event
            }
            if event.window !== popoverWindow {
                self.closePopoverLightly()
            }
            return event
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.popover.isShown, event.keyCode == 53 else { return event }
            self.closePopoverLightly()
            return nil
        }
    }

    private func stopOutsideClickMonitoring() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
    }

    private func startAppDeactivationMonitoring() {
        stopAppDeactivationMonitoring()
        appDeactivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.closePopoverLightly()
            }
        }
    }

    private func stopAppDeactivationMonitoring() {
        if let appDeactivationObserver {
            NotificationCenter.default.removeObserver(appDeactivationObserver)
            self.appDeactivationObserver = nil
        }
    }

    private func isStatusButtonClick(_ event: NSEvent) -> Bool {
        guard let button = statusItem.button, event.window === button.window else { return false }
        let location = button.convert(event.locationInWindow, from: nil)
        return button.bounds.contains(location)
    }

    func popoverDidClose(_ notification: Notification) {
        isClosingPopover = false
        popover.contentViewController?.view.window?.alphaValue = 1
        popover.contentViewController?.view.alphaValue = 1
        stopOutsideClickMonitoring()
        stopAppDeactivationMonitoring()
    }

    private func showConfigError(_ error: Error) {
        if let button = statusItem.button {
            button.toolTip = "Could not load Komari config: \(error.localizedDescription)"
        }
    }

    private func showSettingsWindow() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let config = (try? Config.load()) ?? .empty
        let rootView = SettingsView(
            config: config,
            onSave: { [weak self] next in
                self?.settingsWindow?.close()
                self?.settingsWindow = nil
                self?.startMonitor(config: next)
            },
            onCancel: { [weak self] in
                self?.settingsWindow?.close()
                self?.settingsWindow = nil
            }
        )
        let controller = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: controller)
        window.title = "VPSMonitor Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }
}

@MainActor
final class ServerStatusIconView: NSView {
    var onClick: (() -> Void)?

    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        let color = NSColor.white.withAlphaComponent(0.95)
        color.setStroke()
        color.setFill()

        let top = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 5, width: 11, height: 4.5), xRadius: 1.3, yRadius: 1.3)
        top.lineWidth = 1.2
        top.stroke()

        let bottom = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 12, width: 11, height: 4.5), xRadius: 1.3, yRadius: 1.3)
        bottom.lineWidth = 1.2
        bottom.stroke()

        NSBezierPath(ovalIn: NSRect(x: 3.2, y: 6.6, width: 1.4, height: 1.4)).fill()
        NSBezierPath(ovalIn: NSRect(x: 3.2, y: 13.6, width: 1.4, height: 1.4)).fill()

        let slotWidth: CGFloat = 4.2
        let topSlot = NSBezierPath(roundedRect: NSRect(x: 6.7, y: 6.8, width: slotWidth, height: 1), xRadius: 0.5, yRadius: 0.5)
        topSlot.fill()
        let bottomSlot = NSBezierPath(roundedRect: NSRect(x: 6.7, y: 13.8, width: slotWidth, height: 1), xRadius: 0.5, yRadius: 0.5)
        bottomSlot.fill()
    }
}

@MainActor
final class StatusPillView: NSView {
    var nodes: [NodeViewModel] = [] {
        didSet {
            let count = max(1, nodes.count)
            frame.size = NSSize(width: count * 4, height: 22)
        }
    }
    var onClick: (() -> Void)?

    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        let samples = nodes.isEmpty ? [false] : nodes.map { $0.currentLoss || !$0.status.online }
        let startX: CGFloat = 0
        for (idx, bad) in samples.enumerated() {
            let rect = NSRect(x: startX + CGFloat(idx) * 4, y: 7, width: 2, height: 8)
            let path = NSBezierPath(roundedRect: rect, xRadius: 1.2, yRadius: 1.2)
            (bad ? StatusColors.danger : StatusColors.healthy).setFill()
            path.fill()
        }
    }
}
