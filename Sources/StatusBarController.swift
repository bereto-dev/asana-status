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
    private var lastSummaries: PeriodSummaries?
    private var lastErrorMessage: String?
    private var selectedPeriod: StatsPeriod = .week

    override init() {
        super.init()

        if let btn = statusItem.button {
            btn.image = Self.statusBarIcon()
            btn.imagePosition = .imageLeft
            btn.title  = "—"
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

    private static func statusBarIcon() -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let image = NSImage(systemSymbolName: "deskclock", accessibilityDescription: "AsanaStatus")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    private func renderCachedStateIntoPopup() {
        if let summaries = lastSummaries {
            popup?.update(summaries.summary(for: selectedPeriod), period: selectedPeriod)
        } else if let message = lastErrorMessage {
            popup?.showError(message, period: selectedPeriod)
        } else {
            popup?.showLoading(period: selectedPeriod)
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
            popup?.onPeriodChanged = { [weak self] period in
                guard let self else { return }
                self.selectedPeriod = period
                self.renderCachedStateIntoPopup()
            }
        }

        let btnFrame = btn.window!.convertToScreen(btn.frame)
        let panelW: CGFloat = 260
        var x = btnFrame.midX - panelW / 2
        // PopupPanel insets its visible card 6pt from the panel's own top edge, so we push the
        // panel's frame up by that same amount to keep the *visible* gap to the menu bar at
        // just `visualGap`, instead of visualGap + 6.
        let visualGap: CGFloat = 4
        let cardTopInset: CGFloat = 6
        let y = btnFrame.minY - visualGap + cardTopInset

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

        let checkForUpdates = NSMenuItem(title: L.checkForUpdatesMenu, action: #selector(openRepo), keyEquivalent: "")
        checkForUpdates.target = self
        menu.addItem(checkForUpdates)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L.quitMenu, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func manualRefresh() {
        refresh()
    }

    @objc private func openRepo() {
        NSWorkspace.shared.open(URL(string: "https://github.com/bereto-dev/asana-status")!)
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
            firstWeekday: creds.firstWeekday,
            workDaysPerWeek: creds.workDaysPerWeek
        )
        goalHours = creds.weeklyGoalHours
        notifiedGoalThisWeek = false
        lastSummaries = nil
        lastErrorMessage = nil
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        guard let service, !isRefreshing else { return }
        isRefreshing = true
        if popup?.isVisible == true { popup?.showLoading(period: selectedPeriod) }

        Task {
            do {
                let summaries = try await service.fetchSummaries()
                await MainActor.run {
                    self.lastSummaries = summaries
                    self.lastErrorMessage = nil
                    let week = summaries.week
                    self.statusItem.button?.title = "\(String(format: "%.1f", week.totalHours))/\(String(format: "%.0f", self.goalHours))h"
                    if self.popup?.isVisible == true {
                        self.popup?.update(summaries.summary(for: self.selectedPeriod), period: self.selectedPeriod)
                    }
                    self.isRefreshing = false

                    if week.totalHours >= self.goalHours && !self.notifiedGoalThisWeek {
                        self.notifiedGoalThisWeek = true
                        Notifier.send(title: "AsanaStatus", body: L.goalReachedNotification(self.goalHours))
                    }
                }
            } catch {
                await MainActor.run {
                    self.lastErrorMessage = error.localizedDescription
                    self.statusItem.button?.title = "⚠︎"
                    if self.popup?.isVisible == true { self.popup?.showError(error.localizedDescription, period: self.selectedPeriod) }
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
