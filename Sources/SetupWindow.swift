import Cocoa

private let FIELD_W: CGFloat = 372

class SetupWindow: NSWindow {
    var onSave: ((Credentials) -> Void)?

    private let tokenField      = NSSecureTextField()
    private let workspaceField  = NSTextField()
    private let goalField       = NSTextField()
    private let weekdayPopup    = NSPopUpButton()
    private let workDaysPopup   = NSPopUpButton()
    private let languagePopup   = NSPopUpButton()
    private let statusLabel     = NSTextField(wrappingLabelWithString: "")
    private let saveBtn         = NSButton()
    private let helpBtn         = NSButton()

    private let subLabel         = NSTextField(wrappingLabelWithString: "")
    private let tokenLabelField  = NSTextField(labelWithString: "")
    private let workspaceLabelField = NSTextField(labelWithString: "")
    private let goalLabelField   = NSTextField(labelWithString: "")
    private let weekStartLabelField = NSTextField(labelWithString: "")
    private let workDaysLabelField  = NSTextField(labelWithString: "")
    private let languageLabelField  = NSTextField(labelWithString: "")

    private var stack: NSStackView!

    convenience init() {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 460),
            styleMask:   [.titled, .closable],
            backing:     .buffered,
            defer:       false
        )
        isReleasedWhenClosed = false
        center()
        buildUI()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        let v = NSView(frame: contentView!.bounds)
        contentView = v

        let title = NSTextField(labelWithString: "AsanaStatus")
        title.font = .boldSystemFont(ofSize: 18)

        subLabel.font = .systemFont(ofSize: 12)
        subLabel.textColor = .secondaryLabelColor
        subLabel.preferredMaxLayoutWidth = FIELD_W

        tokenField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        workspaceField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        goalField.font = .systemFont(ofSize: 12)

        for f in [tokenLabelField, workspaceLabelField, goalLabelField, weekStartLabelField, workDaysLabelField, languageLabelField] {
            f.font = .systemFont(ofSize: 13)
        }

        weekdayPopup.target = self
        workDaysPopup.target = self

        languagePopup.removeAllItems()
        languagePopup.addItem(withTitle: AppLanguage.en.displayName)
        languagePopup.lastItem?.tag = 0
        languagePopup.addItem(withTitle: AppLanguage.es.displayName)
        languagePopup.lastItem?.tag = 1
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged)

        if let c = CredentialsManager.load() {
            tokenField.stringValue = c.token
            workspaceField.stringValue = c.workspaceGid
            goalField.stringValue = String(format: "%.0f", c.weeklyGoalHours)
        } else {
            goalField.stringValue = "40"
        }

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.stringValue = ""
        statusLabel.preferredMaxLayoutWidth = FIELD_W

        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        saveBtn.target = self
        saveBtn.action = #selector(save)

        helpBtn.bezelStyle = .inline
        helpBtn.isBordered = false
        helpBtn.font = .systemFont(ofSize: 11)
        helpBtn.contentTintColor = .linkColor
        helpBtn.target = self
        helpBtn.action = #selector(openDocs)

        stack = NSStackView(views: [
            title, subLabel,
            tokenLabelField, tokenField,
            helpBtn,
            workspaceLabelField, workspaceField,
            goalLabelField, goalField,
            weekStartLabelField, weekdayPopup,
            workDaysLabelField, workDaysPopup,
            languageLabelField, languagePopup,
            statusLabel, saveBtn,
        ])
        stack.orientation = .vertical
        stack.alignment   = .leading
        stack.spacing     = 6
        stack.edgeInsets  = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        for f in [tokenField, workspaceField, goalField] {
            f.widthAnchor.constraint(equalToConstant: FIELD_W).isActive = true
        }
        weekdayPopup.widthAnchor.constraint(equalToConstant: 160).isActive = true
        workDaysPopup.widthAnchor.constraint(equalToConstant: 160).isActive = true
        languagePopup.widthAnchor.constraint(equalToConstant: 160).isActive = true
        subLabel.widthAnchor.constraint(equalToConstant: FIELD_W).isActive = true
        statusLabel.widthAnchor.constraint(equalToConstant: FIELD_W).isActive = true

        stack.setCustomSpacing(2, after: subLabel)
        stack.setCustomSpacing(12, after: saveBtn)

        v.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: v.topAnchor),
            stack.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: v.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: v.bottomAnchor),
        ])

        let creds = CredentialsManager.load()
        applyTexts(selectingWeekday: creds?.firstWeekday ?? 2, selectingWorkDays: creds?.workDaysPerWeek ?? 5)
    }

    /// (Re)applies all localized text. Rebuilds the weekday and work-days popups (titles change
    /// per language) while preserving the current selection.
    private func applyTexts(selectingWeekday: Int? = nil, selectingWorkDays: Int? = nil) {
        let weekdayToKeep = selectingWeekday ?? weekdayPopup.selectedItem?.tag ?? 2
        let workDaysToKeep = selectingWorkDays ?? workDaysPopup.selectedItem?.tag ?? 5

        title = L.setupWindowTitle
        subLabel.stringValue = L.setupSubtitle
        tokenField.placeholderString = L.tokenPlaceholder
        workspaceField.placeholderString = L.workspacePlaceholder
        goalField.placeholderString = L.goalPlaceholder
        tokenLabelField.stringValue = L.tokenLabel
        workspaceLabelField.stringValue = L.workspaceLabel
        goalLabelField.stringValue = L.goalLabel
        weekStartLabelField.stringValue = L.weekStartLabel
        workDaysLabelField.stringValue = L.workDaysLabel
        languageLabelField.stringValue = L.languageLabel
        saveBtn.title = L.saveButton
        helpBtn.title = L.generateTokenLink
        statusLabel.textColor = .systemRed

        weekdayPopup.removeAllItems()
        for (i, name) in L.weekdayNames.enumerated() {
            weekdayPopup.addItem(withTitle: name)
            weekdayPopup.lastItem?.tag = i + 1 // Calendar.firstWeekday: 1 = Sunday ... 7 = Saturday
        }
        weekdayPopup.selectItem(withTag: weekdayToKeep)

        workDaysPopup.removeAllItems()
        for n in 1...7 {
            workDaysPopup.addItem(withTitle: L.dayCount(n))
            workDaysPopup.lastItem?.tag = n
        }
        workDaysPopup.selectItem(withTag: workDaysToKeep)

        languagePopup.selectItem(withTag: AppLanguage.current == .es ? 1 : 0)

        resize()
    }

    private func resize() {
        contentView?.layoutSubtreeIfNeeded()
        let fit = stack.fittingSize
        setContentSize(NSSize(width: 420, height: fit.height))
    }

    @objc private func languageChanged() {
        let tag = languagePopup.selectedItem?.tag ?? 0
        AppLanguage.current = tag == 1 ? .es : .en
        applyTexts()
    }

    @objc private func save() {
        let token = tokenField.stringValue.trimmingCharacters(in: .whitespaces)
        let manualWorkspace = workspaceField.stringValue.trimmingCharacters(in: .whitespaces)
        let goalText = goalField.stringValue.trimmingCharacters(in: .whitespaces)
        let firstWeekday = weekdayPopup.selectedItem?.tag ?? 2
        let workDaysPerWeek = workDaysPopup.selectedItem?.tag ?? 5

        guard !token.isEmpty else {
            statusLabel.stringValue = L.tokenRequiredError
            return
        }
        guard let goal = Double(goalText), goal > 0 else {
            statusLabel.stringValue = L.goalInvalidError
            return
        }

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = L.connecting
        saveBtn.isEnabled = false

        Task { [weak self] in
            guard let self else { return }
            do {
                let api = AsanaAPI(token: token)
                let me = try await api.fetchMe()

                let workspace: AsanaWorkspaceRef
                if !manualWorkspace.isEmpty {
                    if let match = me.workspaces.first(where: { $0.gid == manualWorkspace }) {
                        workspace = match
                    } else {
                        workspace = AsanaWorkspaceRef(gid: manualWorkspace, name: manualWorkspace)
                    }
                } else if me.workspaces.count == 1 {
                    workspace = me.workspaces[0]
                } else if me.workspaces.isEmpty {
                    await self.showError(L.noWorkspacesError)
                    return
                } else {
                    let list = me.workspaces.map { "\($0.name) → \($0.gid)" }.joined(separator: "\n")
                    await self.showError("\(L.multipleWorkspacesError)\n\(list)")
                    return
                }

                let creds = Credentials(
                    token: token,
                    userGid: me.gid,
                    userName: me.name,
                    workspaceGid: workspace.gid,
                    workspaceName: workspace.name,
                    weeklyGoalHours: goal,
                    firstWeekday: firstWeekday,
                    workDaysPerWeek: workDaysPerWeek
                )
                CredentialsManager.save(creds)
                await MainActor.run {
                    self.saveBtn.isEnabled = true
                    self.statusLabel.stringValue = ""
                    self.onSave?(creds)
                    self.close()
                }
            } catch {
                await self.showError(error.localizedDescription)
            }
        }
    }

    @MainActor
    private func showError(_ message: String) {
        statusLabel.textColor = .systemRed
        statusLabel.stringValue = message
        saveBtn.isEnabled = true
        resize()
    }

    @objc private func openDocs() {
        NSWorkspace.shared.open(URL(string: "https://app.asana.com/0/developer-console")!)
    }

    /// Called every time the window is about to be shown again, in case it was left mid-save
    /// (e.g. closed with the red button while "Conectando…"/"Connecting…" was in flight), or
    /// the language changed elsewhere since it was last built.
    func resetTransientState() {
        saveBtn.isEnabled = true
        statusLabel.stringValue = ""
        applyTexts()
    }
}
