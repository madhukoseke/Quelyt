import AppKit

enum SidebarDestination: String, CaseIterable {
    case databases
    case datasets
    case history
    case connections
    case settings
    case ai

    var title: String {
        switch self {
        case .databases: return "Databases"
        case .datasets: return "Datasets"
        case .history: return "History"
        case .connections: return "Connections"
        case .settings: return "Settings"
        case .ai: return "AI"
        }
    }

    var symbol: String {
        switch self {
        case .databases: return "cylinder.split.1x2"
        case .datasets: return "doc.text"
        case .history: return "clock"
        case .connections: return "link"
        case .settings: return "gearshape"
        case .ai: return "sparkles"
        }
    }
}

final class NavItemView: NSView {
    let destination: SidebarDestination
    var onSelect: ((SidebarDestination) -> Void)?
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private var selected = false
    private var hovering = false
    private var compact = false

    init(destination: SidebarDestination) {
        self.destination = destination
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = QuelytTheme.radiusSm
        icon.image = NSImage(systemSymbolName: destination.symbol, accessibilityDescription: destination.title)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        icon.contentTintColor = QuelytTheme.inkMuted
        icon.translatesAutoresizingMaskIntoConstraints = false
        label.stringValue = destination.title
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = QuelytTheme.ink
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(icon)
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 34),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10)
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(destination.title)
        setAccessibilityIdentifier("nav-" + destination.rawValue)
        toolTip = destination.title
        focusRingType = .exterior
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func becomeFirstResponder() -> Bool {
        hovering = true
        refresh()
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        hovering = false
        refresh()
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 || event.charactersIgnoringModifiers == " " {
            onSelect?(destination)
            return
        }
        super.keyDown(with: event)
    }

    override func accessibilityPerformPress() -> Bool {
        onSelect?(destination)
        return true
    }

    func setSelected(_ value: Bool) {
        selected = value
        refresh()
        setAccessibilityValue(value ? "selected" : nil)
    }

    func setCompact(_ value: Bool) {
        compact = value
        label.isHidden = value
        refresh()
        needsLayout = true
    }

    private func refresh() {
        if selected {
            layer?.backgroundColor = QuelytTheme.muted.cgColor
            icon.contentTintColor = QuelytTheme.accent
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            label.textColor = QuelytTheme.ink
        } else {
            layer?.backgroundColor = hovering ? QuelytTheme.muted.withAlphaComponent(0.55).cgColor : nil
            icon.contentTintColor = QuelytTheme.inkMuted
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.textColor = QuelytTheme.inkMuted
        }
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; refresh() }
    override func mouseExited(with event: NSEvent) { hovering = false; refresh() }
    override func mouseDown(with event: NSEvent) { onSelect?(destination) }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}

final class WorkspaceSidebar: NSViewController {
    var onNavigate: ((SidebarDestination) -> Void)?

    private(set) var selectedDestination: SidebarDestination = .databases
    private var navItems: [NavItemView] = []
    private var compact = false
    private let chrome = NSStackView()
    private let headerText = NSStackView()
    private let footerDetail = NSStackView()
    private var sectionLabels: [NSTextField] = []

    override func loadView() {
        let root = DatasetDropView()
        root.appearance = NSAppearance(named: .darkAqua)
        root.wantsLayer = true
        root.layer?.backgroundColor = QuelytTheme.surface.cgColor

        chrome.orientation = .vertical
        chrome.alignment = .leading
        chrome.spacing = 4
        chrome.translatesAutoresizingMaskIntoConstraints = false
        chrome.edgeInsets = NSEdgeInsets(top: 14, left: 10, bottom: 12, right: 10)

        chrome.addArrangedSubview(makeHeader())
        chrome.setCustomSpacing(16, after: chrome.arrangedSubviews.last!)
        let explore = QuelytTheme.sectionLabel("Explore")
        sectionLabels.append(explore)
        chrome.addArrangedSubview(explore)
        for destination in [SidebarDestination.databases, .datasets, .history] {
            chrome.addArrangedSubview(makeNav(destination))
        }
        chrome.setCustomSpacing(14, after: chrome.arrangedSubviews.last!)
        let workspace = QuelytTheme.sectionLabel("Workspace")
        sectionLabels.append(workspace)
        chrome.addArrangedSubview(workspace)
        for destination in [SidebarDestination.connections, .settings, .ai] {
            chrome.addArrangedSubview(makeNav(destination))
        }

        let spacer = NSView()
        spacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .vertical)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        chrome.addArrangedSubview(spacer)
        chrome.setCustomSpacing(12, after: spacer)
        chrome.addArrangedSubview(makeFooter())

        for item in chrome.arrangedSubviews {
            item.widthAnchor.constraint(equalTo: chrome.widthAnchor, constant: -20).isActive = true
        }
        root.addSubview(chrome)
        NSLayoutConstraint.activate([
            chrome.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            chrome.topAnchor.constraint(equalTo: root.topAnchor),
            chrome.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 8)
        ])
        view = root
        selectDestination(.databases)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        setCompact(view.bounds.width < 88)
    }

    func selectDestination(_ destination: SidebarDestination) {
        selectedDestination = destination
        navItems.forEach { $0.setSelected($0.destination == destination) }
        onNavigate?(destination)
    }

    var showsUnavailable: Bool { selectedDestination == .connections || selectedDestination == .ai }
    var navAcceptsFirstResponder: Bool { navItems.contains { $0.acceptsFirstResponder } }

    private func setCompact(_ value: Bool) {
        guard compact != value else { return }
        compact = value
        headerText.isHidden = value
        footerDetail.isHidden = value
        sectionLabels.forEach { $0.isHidden = value }
        navItems.forEach { $0.setCompact(value) }
    }

    private func makeNav(_ destination: SidebarDestination) -> NavItemView {
        let item = NavItemView(destination: destination)
        item.onSelect = { [weak self] selected in self?.selectDestination(selected) }
        navItems.append(item)
        return item
    }

    private func makeHeader() -> NSView {
        let mark = NSImageView()
        mark.image = NSImage(systemSymbolName: "cylinder.split.1x2", accessibilityDescription: "Quelyt")
        mark.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        mark.contentTintColor = QuelytTheme.primaryInk
        mark.wantsLayer = true
        mark.layer?.backgroundColor = QuelytTheme.primary.cgColor
        mark.layer?.cornerRadius = 8
        mark.imageAlignment = .alignCenter
        mark.translatesAutoresizingMaskIntoConstraints = false
        mark.widthAnchor.constraint(equalToConstant: 28).isActive = true
        mark.heightAnchor.constraint(equalToConstant: 28).isActive = true
        let title = NSTextField(labelWithString: "Quelyt")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = QuelytTheme.ink
        let meta = NSTextField(labelWithString: "Local workspace")
        meta.font = .systemFont(ofSize: 11)
        meta.textColor = QuelytTheme.inkMuted
        headerText.orientation = .vertical
        headerText.alignment = .leading
        headerText.spacing = 0
        headerText.addArrangedSubview(title)
        headerText.addArrangedSubview(meta)
        let row = NSStackView(views: [mark, headerText])
        row.spacing = 10
        row.alignment = .centerY
        row.wantsLayer = true
        row.layer?.cornerRadius = QuelytTheme.radius
        row.layer?.backgroundColor = QuelytTheme.muted.cgColor
        row.layer?.borderWidth = QuelytTheme.hairline
        row.layer?.borderColor = QuelytTheme.hairlineBorder.cgColor
        row.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        row.setAccessibilityElement(true)
        row.setAccessibilityRole(.staticText)
        row.setAccessibilityLabel("Local workspace")
        return row
    }

    private func makeFooter() -> NSView {
        let mark = NSImageView()
        mark.image = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "This Mac")
        mark.contentTintColor = QuelytTheme.inkMuted
        mark.translatesAutoresizingMaskIntoConstraints = false
        mark.widthAnchor.constraint(equalToConstant: 16).isActive = true
        mark.heightAnchor.constraint(equalToConstant: 16).isActive = true
        let account = NSTextField(labelWithString: "This Mac")
        account.font = .systemFont(ofSize: 13, weight: .medium)
        account.textColor = QuelytTheme.ink
        let detail = NSTextField(labelWithString: "No account · no network")
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = QuelytTheme.inkMuted
        footerDetail.orientation = .vertical
        footerDetail.alignment = .leading
        footerDetail.spacing = 0
        footerDetail.addArrangedSubview(account)
        footerDetail.addArrangedSubview(detail)
        let row = NSStackView(views: [mark, footerDetail])
        row.spacing = 8
        row.alignment = .centerY
        row.wantsLayer = true
        row.layer?.cornerRadius = QuelytTheme.radiusSm
        row.layer?.backgroundColor = QuelytTheme.muted.cgColor
        row.layer?.borderWidth = QuelytTheme.hairline
        row.layer?.borderColor = QuelytTheme.hairlineBorder.cgColor
        row.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        row.setAccessibilityElement(true)
        row.setAccessibilityRole(.staticText)
        row.setAccessibilityLabel("This Mac. No account. No network.")
        return row
    }
}
