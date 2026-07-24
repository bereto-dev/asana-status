import Cocoa

private let PANEL_W: CGFloat = 260
private let PAD:     CGFloat = 12

class PopupPanel: NSPanel {

    private let headerLabel  = label("", size: 9, weight: .semibold, alpha: 0.45)
    private let hoursLabel   = label("—",  size: 26, weight: .bold, alpha: 1)
    private let goalLabel    = label("",   size: 11, weight: .regular, alpha: 0.5)
    private let progressBar  = ProgressBar()
    private let paceLabel    = label("",   size: 11, weight: .medium, alpha: 0.8)
    private let tasksHeader  = label("", size: 9, weight: .semibold, alpha: 0.4)
    private var taskRows: [NSStackView] = []
    private let tasksStack   = NSStackView()
    private let updatedLabel = label("", size: 10, weight: .regular, alpha: 0.4)
    private let refreshButton = NSButton()
    private var rootStack: NSStackView!
    private var card: CardView!

    var onRefreshRequested: (() -> Void)?

    convenience init() {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: PANEL_W, height: 200),
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        isFloatingPanel    = true
        level              = .popUpMenu
        backgroundColor    = .clear
        isOpaque           = false
        hasShadow          = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        buildUI()
    }

    private func buildUI() {
        let root = NSView(frame: contentView!.bounds)
        root.autoresizingMask = [.width, .height]
        contentView = root

        card = CardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: root.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 6),
            card.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -6),
            card.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -6),
        ])

        let hoursRow = hstack([hoursLabel, goalLabel], spacing: 6, align: .lastBaseline)

        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.heightAnchor.constraint(equalToConstant: 5).isActive = true

        tasksStack.orientation = .vertical
        tasksStack.alignment   = .leading
        tasksStack.spacing     = 3

        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: L.refreshNowMenu)
        refreshButton.image?.isTemplate = true
        refreshButton.contentTintColor = .white.withAlphaComponent(0.4)
        refreshButton.isBordered = false
        refreshButton.bezelStyle = .inline
        refreshButton.imageScaling = .scaleProportionallyUpOrDown
        refreshButton.target = self
        refreshButton.action = #selector(refreshTapped)
        refreshButton.toolTip = L.refreshNowMenu
        refreshButton.widthAnchor.constraint(equalToConstant: 14).isActive = true
        refreshButton.heightAnchor.constraint(equalToConstant: 14).isActive = true

        let updatedRow = hstack([refreshButton, updatedLabel], spacing: 5, align: .centerY)

        rootStack = NSStackView(views: [
            headerLabel,
            hoursRow,
            progressBar,
            paceLabel,
            Divider(),
            tasksHeader,
            tasksStack,
            Divider(),
            updatedRow,
        ])
        rootStack.orientation = .vertical
        rootStack.alignment   = .leading
        rootStack.spacing     = 6
        rootStack.edgeInsets  = NSEdgeInsets(top: PAD, left: PAD, bottom: PAD, right: PAD)
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(rootStack)
        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: card.topAnchor),
            rootStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            rootStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            progressBar.widthAnchor.constraint(equalTo: rootStack.widthAnchor, constant: -PAD * 2),
        ])
    }

    func showLoading() {
        headerLabel.stringValue = L.thisWeekHeader
        tasksHeader.stringValue = L.tasksHeader
        hoursLabel.stringValue = "…"
        paceLabel.textColor    = NSColor.white.withAlphaComponent(0.8)
        paceLabel.stringValue  = L.updatingNow
        resize()
    }

    func showError(_ message: String) {
        headerLabel.stringValue = L.thisWeekHeader
        tasksHeader.stringValue = L.tasksHeader
        hoursLabel.stringValue = "⚠︎"
        goalLabel.stringValue  = ""
        paceLabel.stringValue  = message
        paceLabel.textColor    = NSColor.systemRed.withAlphaComponent(0.9)
        clearTaskRows()
        resize()
    }

    func update(_ summary: WeeklySummary, goalHours: Double) {
        headerLabel.stringValue = L.thisWeekHeader
        tasksHeader.stringValue = L.tasksHeader

        hoursLabel.stringValue = String(format: "%.1fh", summary.totalHours)
        let percent = Int((summary.totalHours / max(goalHours, 1) * 100).rounded())
        goalLabel.stringValue  = L.ofGoal(goalHours, percent: percent)
        progressBar.progress   = min(summary.totalHours / max(goalHours, 1), 1.0)
        progressBar.isBehind   = !summary.isOnPace

        let diffMinutes = summary.totalMinutes - summary.expectedMinutesSoFar
        let diffHours = abs(Double(diffMinutes)) / 60
        if summary.isOnPace {
            paceLabel.textColor = NSColor.white.withAlphaComponent(0.8)
            paceLabel.stringValue = diffMinutes == 0 ? L.rightOnTrack : L.aheadOfGoal(diffHours)
        } else {
            paceLabel.textColor = NSColor.systemOrange
            paceLabel.stringValue = L.behindGoal(diffHours)
        }

        clearTaskRows()
        if summary.topTasks.isEmpty {
            let row = taskRow(name: L.noTimeLoggedYet, minutes: nil)
            tasksStack.addArrangedSubview(row)
            taskRows.append(row)
        } else {
            for t in summary.topTasks {
                let row = taskRow(name: t.name, minutes: t.minutes)
                tasksStack.addArrangedSubview(row)
                taskRows.append(row)
            }
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        updatedLabel.stringValue = L.updatedAt(fmt.string(from: summary.generatedAt))

        resize()
    }

    @objc private func refreshTapped() {
        onRefreshRequested?()
    }

    private func clearTaskRows() {
        for row in taskRows { tasksStack.removeArrangedSubview(row); row.removeFromSuperview() }
        taskRows.removeAll()
    }

    private func taskRow(name: String, minutes: Int?) -> NSStackView {
        let nameLabel = NSTextField(labelWithString: name)
        nameLabel.font = .systemFont(ofSize: 11)
        nameLabel.textColor = .white.withAlphaComponent(0.75)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let minLabel = NSTextField(labelWithString: minutes.map { String(format: "%.1fh", Double($0) / 60) } ?? "")
        minLabel.font = .systemFont(ofSize: 11, weight: .medium)
        minLabel.textColor = .white.withAlphaComponent(0.5)

        let row = NSStackView(views: [nameLabel, spacer, minLabel])
        row.orientation = .horizontal
        row.alignment   = .centerY
        row.spacing     = 4
        row.widthAnchor.constraint(equalToConstant: PANEL_W - PAD * 2 - 12).isActive = true
        return row
    }

    private func resize() {
        contentView?.layoutSubtreeIfNeeded()
        let fit = contentView!.fittingSize
        setContentSize(NSSize(width: PANEL_W, height: fit.height))
    }
}

// MARK: – Helpers

private func label(_ s: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat) -> NSTextField {
    let f = NSTextField(labelWithString: s)
    f.font      = .systemFont(ofSize: size, weight: weight)
    f.textColor = NSColor.white.withAlphaComponent(alpha)
    return f
}

private func hstack(_ views: [NSView], spacing: CGFloat, align: NSLayoutConstraint.Attribute) -> NSStackView {
    let s = NSStackView(views: views)
    s.orientation = .horizontal
    s.alignment   = align == .lastBaseline ? .lastBaseline : .centerY
    s.spacing     = spacing
    return s
}

// MARK: – CardView / ProgressBar / Divider

private class CardView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12)
        NSColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 0.97).setFill()
        path.fill()
    }
}

class ProgressBar: NSView {
    var progress: Double = 0 { didSet { needsDisplay = true } }
    var isBehind: Bool = false { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        let bg = NSBezierPath(roundedRect: bounds, xRadius: 3, yRadius: 3)
        NSColor.white.withAlphaComponent(0.12).setFill()
        bg.fill()
        let w = bounds.width * CGFloat(min(max(progress, 0), 1))
        if w > 0 {
            let fill = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: w, height: bounds.height), xRadius: 3, yRadius: 3)
            let color = isBehind
                ? NSColor(red: 0.95, green: 0.55, blue: 0.20, alpha: 1)
                : NSColor(red: 0.25, green: 0.85, blue: 0.45, alpha: 1)
            color.setFill()
            fill.fill()
        }
    }
}

private class Divider: NSView {
    override var intrinsicContentSize: NSSize { NSSize(width: -1, height: 1) }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.withAlphaComponent(0.1).setFill()
        bounds.fill()
    }
}
