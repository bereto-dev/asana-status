import Cocoa

class AboutWindow: NSWindow {

    convenience init() {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 220),
            styleMask:   [.titled, .closable],
            backing:     .buffered,
            defer:       false
        )
        title = L.aboutWindowTitle
        isReleasedWhenClosed = false
        center()
        buildUI()
    }

    private func buildUI() {
        let root = NSView(frame: contentView!.bounds)
        contentView = root

        let appName = NSTextField(labelWithString: "AsanaStatus")
        appName.font = .boldSystemFont(ofSize: 20)

        let appSub = NSTextField(wrappingLabelWithString: L.aboutSubtitle)
        appSub.font = .systemFont(ofSize: 12)
        appSub.textColor = .secondaryLabelColor

        let originHeader = sectionHeader(L.originHeader)
        let originBody = NSTextField(wrappingLabelWithString: L.originBody)
        originBody.font = .systemFont(ofSize: 12)
        originBody.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [
            appName, appSub,
            div(),
            originHeader, originBody,
        ])
        stack.orientation = .vertical
        stack.alignment   = .leading
        stack.spacing     = 8
        stack.edgeInsets  = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
            appSub.widthAnchor.constraint(equalToConstant: 332),
            originBody.widthAnchor.constraint(equalToConstant: 332),
        ])

        root.layoutSubtreeIfNeeded()
        let h = stack.fittingSize.height
        setContentSize(NSSize(width: 380, height: h))
    }

    private func sectionHeader(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text.uppercased())
        f.font = .systemFont(ofSize: 10, weight: .semibold)
        f.textColor = .tertiaryLabelColor
        return f
    }

    private func div() -> NSView {
        let v = NSBox()
        v.boxType = .separator
        v.widthAnchor.constraint(equalToConstant: 332).isActive = true
        return v
    }
}
