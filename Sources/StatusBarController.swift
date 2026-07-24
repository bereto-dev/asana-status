import Cocoa

class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var popup:    PopupPanel?
    private var timer:    Timer?
    private var service:  WeeklyTimeService?
    private var goalHours: Double = 40
    private var setupWin:  SetupWindow?
    private var aboutWin:  AboutWindow?
    private var isRefreshing = false
    private var notifiedGoalThisWeek = false
    private var lastSummary: WeeklySummary?
    private var lastErrorMessage: String?

    override init() {
        super.init()

        if let btn = statusItem.button {
            btn.title  = "⏱ —"
            btn.action = #selector(togglePopup)
            btn.target = self
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        if let creds = CredentialsManager.load() {
            connect(creds)
        } else {
            showSetup()
        }

        NotificationCenter.default.addObserver(forName: .appLanguageChanged, object: nil, queue: .main) { [weak self] _ in
            self?.aboutWin = nil
            self?.renderCachedStateIntoPopup()
        }
    }

    private func renderCachedStateIntoPopup() {
        if let summary = lastSummary {
            popup?.update(summary, goalHours: goalHours)
        } else if let message = lastErrorMessage {
            popup?.showError(message)
        } else {
            popup?.showLoading()
        }
    }

    // MARK: – Popup

    @objc private func togglePopup() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
            return
        }

        if let p = popup, p.isVisible {
            p.orderOut(nil)
            return
        }

        guard let btn = statusItem.button,
              let screen = btn.window?.screen ?? NSScreen.main else { return }

        if popup == nil {
            popup = PopupPanel()
            popup?.onRefreshRequested = { [weak self] in self?.refresh() }
        }

        let btnFrame = btn.window!.convertToScreen(btn.frame)
        let panelW: CGFloat = 260
        var x = btnFrame.midX - panelW / 2
        let y = btnFrame.minY - 8

        x = min(x, screen.visibleFrame.maxX - panelW - 8)
        x = max(x, screen.visibleFrame.minX + 8)

        renderCachedStateIntoPopup()

        popup?.setFrameTopLeftPoint(NSPoint(x: x, y: y))
        popup?.orderFrontRegardless()
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let refreshItem = NSMenuItem(title: L.refreshNowMenu, action: #selector(manualRefresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        let settings = NSMenuItem(title: L.settingsMenu, action: #selector(showSetup), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let about = NSMenuItem(title: L.aboutMenu, action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L.quitMenu, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func manualRefresh() {
        refresh()
    }

    @objc private func showAbout() {
        if aboutWin == nil { aboutWin = AboutWindow() }
        NSApp.activate(ignoringOtherApps: true)
        aboutWin?.makeKeyAndOrderFront(nil)
    }

    // MARK: – Polling

    private func connect(_ creds: Credentials) {
        service = WeeklyTimeService(
            token: creds.token,
            userGid: creds.userGid,
            workspaceGid: creds.workspaceGid,
            goalHours: creds.weeklyGoalHours,
            firstWeekday: creds.firstWeekday
        )
        goalHours = creds.weeklyGoalHours
        notifiedGoalThisWeek = false
        lastSummary = nil
        lastErrorMessage = nil
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        guard let service, !isRefreshing else { return }
        isRefreshing = true
        if popup?.isVisible == true { popup?.showLoading() }

        Task {
            do {
                let summary = try await service.fetchWeeklySummary()
                await MainActor.run {
                    self.lastSummary = summary
                    self.lastErrorMessage = nil
                    self.statusItem.button?.title = "⏱ \(String(format: "%.1f", summary.totalHours))/\(String(format: "%.0f", self.goalHours))h"
                    if self.popup?.isVisible == true { self.popup?.update(summary, goalHours: self.goalHours) }
                    self.isRefreshing = false

                    if summary.totalHours >= self.goalHours && !self.notifiedGoalThisWeek {
                        self.notifiedGoalThisWeek = true
                        Notifier.send(title: "AsanaStatus", body: L.goalReachedNotification(self.goalHours))
                    }
                }
            } catch {
                await MainActor.run {
                    self.lastErrorMessage = error.localizedDescription
                    self.statusItem.button?.title = "⏱ ⚠︎"
                    if self.popup?.isVisible == true { self.popup?.showError(error.localizedDescription) }
                    self.isRefreshing = false
                }
            }
        }
    }

    // MARK: – Setup

    @objc func showSetup() {
        if setupWin == nil {
            setupWin = SetupWindow()
            setupWin?.onSave = { [weak self] creds in
                self?.timer?.invalidate()
                self?.timer = nil
                self?.connect(creds)
            }
        }
        setupWin?.resetTransientState()
        NSApp.activate(ignoringOtherApps: true)
        setupWin?.makeKeyAndOrderFront(nil)
    }
}
