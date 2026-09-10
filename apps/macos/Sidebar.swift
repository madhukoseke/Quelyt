import AppKit

enum SidebarDestination: String, CaseIterable {
    case databases
    case history
    case connections
    case settings
    case ai

    var title: String {
        switch self {
        case .databases: return "Databases"
        case .history: return "History"
        case .connections: return "Connections"
        case .settings: return "Settings"
        case .ai: return "AI"
        }
    }

    var symbol: String {
        switch self {
        case .databases: return "cylinder.split.1x2"
        case .history: return "clock"
        case .connections: return "link"
        case .settings: return "gearshape"
        case .ai: return "sparkles"
        }
    }
}

struct SidebarColumn {
    var name: String
    var type: String
    var nullPct: NSNumber?
    var distinctCount: NSNumber?
    var minValue: Any?
    var maxValue: Any?
    var meta: String {
        var parts: [String] = [type]
        if let nullPct = nullPct { parts.append("null \(nullPct)%") }
        if let distinctCount = distinctCount { parts.append("distinct \(distinctCount)") }
        var range: [String] = []
        if let minValue = minValue, !(minValue is NSNull) { range.append("min \(minValue)") }
        if let maxValue = maxValue, !(maxValue is NSNull) { range.append("max \(maxValue)") }
        if !range.isEmpty { parts.append(range.joined(separator: " · ")) }
        return parts.joined(separator: " · ")
    }
}

final class NavItemView: NSView {
    let destination: SidebarDestination
    var onSelect: ((SidebarDestination) -> Void)?
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private var selected = false
    private var hovering = false

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
        addSubview(icon)
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 34),
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(destination.title)
        setAccessibilityIdentifier("nav-" + destination.rawValue)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSelected(_ value: Bool) {
        selected = value
        refresh()
        setAccessibilityValue(value ? "selected" : nil)
    }

    private func refresh() {
        if selected {
            layer?.backgroundColor = QuelytTheme.muted.cgColor
            icon.contentTintColor = QuelytTheme.ink
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            label.textColor = QuelytTheme.ink
        } else {
            layer?.backgroundColor = hovering ? QuelytTheme.muted.withAlphaComponent(0.55).cgColor : nil
            icon.contentTintColor = QuelytTheme.inkMuted
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.textColor = QuelytTheme.ink
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

final class WorkspaceSidebar: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var onOpen: (() -> Void)?
    var onOpenRecent: ((String) -> Void)?
    var onInsertColumn: ((String) -> Void)?
    var onSelectTrace: (([String: Any]) -> Void)?
    var onRerunTrace: (([String: Any]) -> Void)?
    var onNavigate: ((SidebarDestination) -> Void)?

    let historyTable = NSTableView()
    private(set) var selectedDestination: SidebarDestination = .databases
    private let recentsTable = NSTableView()
    private let columnTable = NSTableView()
    private let columnFilter = NSSearchField()
    private let nameLabel = NSTextField(labelWithString: "No dataset")
    private let metaLabel = NSTextField(wrappingLabelWithString: "Open or drop a CSV / Parquet file.")
    private let headerTitle = NSTextField(labelWithString: "Quelyt")
    private let headerMeta = NSTextField(labelWithString: "Local workspace")
    private let openButton = NSButton(title: "Open dataset…", target: nil, action: nil)
    private let recentsLabel = NSTextField(labelWithString: "Recents")
    private let recentsScroll = NSScrollView()
    private var recentsHeight: NSLayoutConstraint!
    private let databasesPane = NSView()
    private let historyPane = NSView()
    private let connectionsPane = NSView()
    private let settingsPane = NSView()
    private let aiPane = NSView()
    private var navItems: [NavItemView] = []
    private var columns: [SidebarColumn] = []
    private var visibleColumns: [SidebarColumn] = []
    private var recents: [[String: Any]] = []
    private var traces: [[String: Any]] = []
    private var reloading = false
    private let maxRecents = 7

    override func loadView() {
        let root = DatasetDropView()
        root.openFile = { [weak self] url in self?.onOpenRecent?(url.path) }
        root.appearance = NSAppearance(named: .darkAqua)
        root.wantsLayer = true
        root.layer?.backgroundColor = QuelytTheme.surface.cgColor

        let chrome = NSStackView()
        chrome.orientation = .vertical
        chrome.alignment = .leading
        chrome.spacing = 4
        chrome.translatesAutoresizingMaskIntoConstraints = false
        chrome.edgeInsets = NSEdgeInsets(top: 14, left: 10, bottom: 12, right: 10)

        chrome.addArrangedSubview(makeHeader())
        chrome.setCustomSpacing(16, after: chrome.arrangedSubviews.last!)
        chrome.addArrangedSubview(sectionLabel("Explore"))
        for destination in [SidebarDestination.databases, .history] {
            chrome.addArrangedSubview(makeNav(destination))
        }
        chrome.setCustomSpacing(14, after: chrome.arrangedSubviews.last!)
        chrome.addArrangedSubview(sectionLabel("Workspace"))
        for destination in [SidebarDestination.connections, .settings, .ai] {
            chrome.addArrangedSubview(makeNav(destination))
        }
        chrome.setCustomSpacing(12, after: chrome.arrangedSubviews.last!)

        buildDatabasesPane()
        buildHistoryPane()
        buildGatedPane(connectionsPane, symbol: "link", title: "Connections", body: "Remote database connections are not in this developer build. Open a local CSV or Parquet file from Databases. Source files stay on this Mac.")
        buildSettingsPane()
        buildGatedPane(aiPane, symbol: "sparkles", title: "AI is research-only", body: "Talk to Data stays out of the product. The held-out evaluation did not meet quality gates. This app makes no model or network calls.")

        let context = NSView()
        context.translatesAutoresizingMaskIntoConstraints = false
        context.setContentHuggingPriority(.defaultLow, for: .vertical)
        for pane in [databasesPane, historyPane, connectionsPane, settingsPane, aiPane] {
            pane.translatesAutoresizingMaskIntoConstraints = false
            context.addSubview(pane)
            NSLayoutConstraint.activate([
                pane.leadingAnchor.constraint(equalTo: context.leadingAnchor),
                pane.trailingAnchor.constraint(equalTo: context.trailingAnchor),
                pane.topAnchor.constraint(equalTo: context.topAnchor),
                pane.bottomAnchor.constraint(equalTo: context.bottomAnchor)
            ])
        }
        chrome.addArrangedSubview(context)
        chrome.setCustomSpacing(12, after: context)
        chrome.addArrangedSubview(makeFooter())

        for view in chrome.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: chrome.widthAnchor, constant: -20).isActive = true
        }
        root.addSubview(chrome)
        NSLayoutConstraint.activate([
            chrome.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            chrome.topAnchor.constraint(equalTo: root.topAnchor),
            chrome.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            context.heightAnchor.constraint(greaterThanOrEqualToConstant: 180)
        ])
        view = root
        setDataset(url: nil, rows: nil, columns: nil)
        setRecents([])
        selectDestination(.databases)
    }

    func selectDestination(_ destination: SidebarDestination) {
        selectedDestination = destination
        navItems.forEach { $0.setSelected($0.destination == destination) }
        databasesPane.isHidden = destination != .databases
        historyPane.isHidden = destination != .history
        connectionsPane.isHidden = destination != .connections
        settingsPane.isHidden = destination != .settings
        aiPane.isHidden = destination != .ai
        onNavigate?(destination)
    }

    var showsUnavailable: Bool { selectedDestination == .connections || selectedDestination == .ai }

    func setDataset(url: URL?, rows: Int?, columns: Int?) {
        if let url = url {
            nameLabel.stringValue = url.lastPathComponent
            headerTitle.stringValue = url.lastPathComponent
            let format = url.pathExtension.uppercased()
            var parts = [format]
            if let rows = rows { parts.append("\(rows.formatted()) rows") }
            if let columns = columns { parts.append("\(columns) columns") }
            parts.append("source unchanged")
            metaLabel.stringValue = parts.joined(separator: " · ")
            headerMeta.stringValue = "Local workspace"
            openButton.isHidden = true
        } else {
            nameLabel.stringValue = "No dataset"
            headerTitle.stringValue = "Quelyt"
            metaLabel.stringValue = "Open or drop a CSV / Parquet file."
            headerMeta.stringValue = "Local workspace"
            openButton.isHidden = false
        }
    }

    func resetColumns() {
        columns = []
        columnFilter.stringValue = ""
        reloadColumns()
    }

    func applySchema(_ fields: [[String: Any]]) {
        let previous = Dictionary(uniqueKeysWithValues: columns.map { ($0.name, $0) })
        columns = fields.compactMap { field in
            guard let name = field["name"] as? String else { return nil }
            var item = SidebarColumn(name: name, type: field["type"] as? String ?? "")
            if let old = previous[name] {
                item.nullPct = old.nullPct
                item.distinctCount = old.distinctCount
                item.minValue = old.minValue
                item.maxValue = old.maxValue
            }
            return item
        }
        reloadColumns()
    }

    func applyProfile(_ profile: [[String: Any]]) {
        columns = profile.compactMap { field in
            guard let name = field["name"] as? String else { return nil }
            return SidebarColumn(
                name: name,
                type: field["type"] as? String ?? "",
                nullPct: field["null_pct"] as? NSNumber,
                distinctCount: field["distinct_count"] as? NSNumber,
                minValue: field["min"],
                maxValue: field["max"]
            )
        }
        reloadColumns()
    }

    func setRecents(_ sources: [[String: Any]]) {
        recents = Array(sources.prefix(maxRecents))
        recentsTable.reloadData()
        recentsLabel.isHidden = recents.isEmpty
        recentsScroll.isHidden = recents.isEmpty
        recentsHeight.constant = recents.isEmpty ? 0 : CGFloat(min(recents.count, 5) * 22 + 4)
    }

    func setTraces(_ items: [[String: Any]]) {
        reloading = true
        traces = items
        historyTable.reloadData()
        historyTable.deselectAll(nil)
        reloading = false
    }

    func recentNames() -> [String] {
        recents.map { $0["name"] as? String ?? ($0["path"] as? String ?? "") }
    }

    func visibleColumnRows() -> [SidebarColumn] { visibleColumns }

    var columnFilterString: String {
        get { columnFilter.stringValue }
        set { columnFilter.stringValue = newValue; reloadColumns() }
    }

    func insertColumn(at row: Int) {
        guard row >= 0, row < visibleColumns.count else { return }
        onInsertColumn?(visibleColumns[row].name)
    }

    func selectedTrace() -> [String: Any]? {
        let row = historyTable.selectedRow
        guard row >= 0, row < traces.count else { return nil }
        return traces[row]
    }

    func rerunSelectedTrace() {
        let row = historyTable.clickedRow >= 0 ? historyTable.clickedRow : historyTable.selectedRow
        guard row >= 0, row < traces.count else { return }
        onRerunTrace?(traces[row])
    }

    @objc func filterColumns() { reloadColumns() }
    @objc func openClicked() { onOpen?() }
    @objc func insertSelectedColumn() { insertColumn(at: columnTable.selectedRow) }
    @objc func openSelectedRecent() {
        let row = recentsTable.selectedRow
        guard row >= 0, row < recents.count, let path = recents[row]["path"] as? String else { return }
        onOpenRecent?(path)
    }
    @objc func rerunSelected() { rerunSelectedTrace() }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === recentsTable { return recents.count }
        if tableView === columnTable { return visibleColumns.count }
        return traces.count
    }

    func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        if tableView === recentsTable {
            guard row < recents.count else { return nil }
            let field = NSTextField(labelWithString: recents[row]["name"] as? String ?? recents[row]["path"] as? String ?? "")
            field.font = .systemFont(ofSize: 12)
            field.textColor = .labelColor
            field.lineBreakMode = .byTruncatingMiddle
            field.toolTip = recents[row]["path"] as? String
            return field
        }
        if tableView === columnTable {
            guard row < visibleColumns.count else { return nil }
            let item = visibleColumns[row]
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 1
            let name = NSTextField(labelWithString: item.name)
            name.font = .systemFont(ofSize: 12, weight: .medium)
            name.textColor = .labelColor
            name.lineBreakMode = .byTruncatingTail
            let meta = NSTextField(labelWithString: item.meta)
            meta.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
            meta.textColor = QuelytTheme.inkMuted
            meta.lineBreakMode = .byTruncatingTail
            stack.addArrangedSubview(name)
            stack.addArrangedSubview(meta)
            stack.toolTip = item.name + " · " + item.meta
            return stack
        }
        guard row < traces.count else { return nil }
        let trace = traces[row]
        let sql = (trace["sql"] as? String ?? "").split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let mark = (trace["ok"] as? Bool) == true ? "" : "Error · "
        let field = NSTextField(labelWithString: mark + sql)
        field.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        field.textColor = .labelColor
        field.lineBreakMode = .byTruncatingTail
        field.toolTip = trace["sql"] as? String
        return field
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard notification.object as? NSTableView === historyTable, !reloading, let trace = selectedTrace() else { return }
        onSelectTrace?(trace)
    }

    private func reloadColumns() {
        let needle = columnFilter.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        visibleColumns = needle.isEmpty ? columns : columns.filter {
            $0.name.localizedCaseInsensitiveContains(needle) || $0.type.localizedCaseInsensitiveContains(needle)
        }
        columnTable.reloadData()
        columnTable.deselectAll(nil)
    }

    private func configure(_ table: NSTableView, identifier: String, rowHeight: CGFloat, label: String) {
        table.headerView = nil
        table.rowHeight = rowHeight
        table.delegate = self
        table.dataSource = self
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular
        table.setAccessibilityLabel(label)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.width = 200
        table.addTableColumn(column)
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 11, weight: .medium)
        field.textColor = QuelytTheme.faint
        return field
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
        mark.contentTintColor = .white
        mark.wantsLayer = true
        mark.layer?.backgroundColor = QuelytTheme.brand.cgColor
        mark.layer?.cornerRadius = 8
        mark.imageAlignment = .alignCenter
        mark.translatesAutoresizingMaskIntoConstraints = false
        mark.widthAnchor.constraint(equalToConstant: 28).isActive = true
        mark.heightAnchor.constraint(equalToConstant: 28).isActive = true
        headerTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        headerTitle.textColor = QuelytTheme.ink
        headerTitle.lineBreakMode = .byTruncatingMiddle
        headerMeta.font = .systemFont(ofSize: 11)
        headerMeta.textColor = QuelytTheme.inkMuted
        let text = NSStackView(views: [headerTitle, headerMeta])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 0
        let row = NSStackView(views: [mark, text])
        row.spacing = 10
        row.alignment = .centerY
        row.wantsLayer = true
        row.layer?.cornerRadius = QuelytTheme.radius
        row.layer?.backgroundColor = QuelytTheme.muted.cgColor
        row.layer?.borderWidth = QuelytTheme.hairline
        row.layer?.borderColor = QuelytTheme.line.cgColor
        row.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        row.setAccessibilityElement(true)
        row.setAccessibilityRole(.staticText)
        row.setAccessibilityLabel("Local workspace")
        return row
    }

    private func makeFooter() -> NSView {
        let badge = NSTextField(labelWithString: "Local · Read only")
        badge.font = .systemFont(ofSize: 11, weight: .medium)
        badge.textColor = QuelytTheme.success
        badge.alignment = .center
        badge.wantsLayer = true
        badge.layer?.cornerRadius = QuelytTheme.radiusSm
        badge.layer?.backgroundColor = QuelytTheme.muted.cgColor
        badge.setContentHuggingPriority(.required, for: .vertical)
        let mark = NSImageView()
        mark.image = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "This Mac")
        mark.contentTintColor = QuelytTheme.inkMuted
        mark.translatesAutoresizingMaskIntoConstraints = false
        mark.widthAnchor.constraint(equalToConstant: 16).isActive = true
        let account = NSTextField(labelWithString: "This Mac")
        account.font = .systemFont(ofSize: 13, weight: .medium)
        let detail = NSTextField(labelWithString: "No account · no network")
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = QuelytTheme.inkMuted
        let names = NSStackView(views: [account, detail])
        names.orientation = .vertical
        names.alignment = .leading
        names.spacing = 0
        let accountRow = NSStackView(views: [mark, names])
        accountRow.spacing = 8
        accountRow.alignment = .centerY
        let stack = NSStackView(views: [badge, accountRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        badge.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return stack
    }

    private func buildDatabasesPane() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        nameLabel.textColor = QuelytTheme.ink
        nameLabel.lineBreakMode = .byTruncatingMiddle
        metaLabel.font = .systemFont(ofSize: 11)
        metaLabel.textColor = QuelytTheme.inkMuted
        metaLabel.maximumNumberOfLines = 4
        openButton.bezelStyle = .rounded
        openButton.controlSize = .small
        openButton.target = self
        openButton.action = #selector(openClicked)
        recentsLabel.font = .systemFont(ofSize: 11, weight: .medium)
        recentsLabel.textColor = QuelytTheme.faint
        configure(recentsTable, identifier: "recent", rowHeight: 22, label: "Recent datasets")
        recentsTable.target = self
        recentsTable.action = #selector(openSelectedRecent)
        recentsScroll.documentView = recentsTable
        recentsScroll.hasVerticalScroller = true
        recentsScroll.drawsBackground = false
        recentsScroll.borderType = .noBorder
        recentsHeight = recentsScroll.heightAnchor.constraint(equalToConstant: 0)
        let columnsHeader = NSTextField(labelWithString: "Columns")
        columnsHeader.font = .systemFont(ofSize: 11, weight: .medium)
        columnsHeader.textColor = QuelytTheme.faint
        columnFilter.placeholderString = "Filter columns"
        columnFilter.controlSize = .small
        columnFilter.target = self
        columnFilter.action = #selector(filterColumns)
        columnFilter.sendsSearchStringImmediately = true
        columnFilter.setAccessibilityLabel("Filter columns")
        configure(columnTable, identifier: "column", rowHeight: 38, label: "Dataset columns")
        columnTable.target = self
        columnTable.action = #selector(insertSelectedColumn)
        let columnScroll = NSScrollView()
        columnScroll.documentView = columnTable
        columnScroll.hasVerticalScroller = true
        columnScroll.drawsBackground = false
        columnScroll.borderType = .noBorder
        for view in [nameLabel, metaLabel, openButton, recentsLabel, recentsScroll, columnsHeader, columnFilter, columnScroll] {
            stack.addArrangedSubview(view)
        }
        columnScroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        recentsScroll.setContentHuggingPriority(.required, for: .vertical)
        recentsScroll.setContentCompressionResistancePriority(.required, for: .vertical)
        databasesPane.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: databasesPane.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: databasesPane.trailingAnchor),
            stack.topAnchor.constraint(equalTo: databasesPane.topAnchor),
            stack.bottomAnchor.constraint(equalTo: databasesPane.bottomAnchor),
            recentsHeight,
            recentsScroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            columnFilter.widthAnchor.constraint(equalTo: stack.widthAnchor),
            columnScroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            columnScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            nameLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            metaLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func buildHistoryPane() {
        let title = NSTextField(labelWithString: "SQL history")
        title.font = .systemFont(ofSize: 11, weight: .medium)
        title.textColor = QuelytTheme.faint
        let hint = NSTextField(wrappingLabelWithString: "Click to load SQL. Double-click to rerun against its source file.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = QuelytTheme.inkMuted
        hint.maximumNumberOfLines = 3
        configure(historyTable, identifier: "history", rowHeight: 24, label: "Recent queries")
        historyTable.target = self
        historyTable.doubleAction = #selector(rerunSelected)
        let historyScroll = NSScrollView()
        historyScroll.documentView = historyTable
        historyScroll.hasVerticalScroller = true
        historyScroll.drawsBackground = false
        historyScroll.borderType = .noBorder
        let stack = NSStackView(views: [title, hint, historyScroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        historyScroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        historyPane.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: historyPane.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: historyPane.trailingAnchor),
            stack.topAnchor.constraint(equalTo: historyPane.topAnchor),
            stack.bottomAnchor.constraint(equalTo: historyPane.bottomAnchor),
            historyScroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            historyScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            hint.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func buildSettingsPane() {
        let items = [
            ("Scope", "Local CSV and Parquet on this Mac."),
            ("History", "SQL traces live in Application Support. Result grids are not stored."),
            ("Network", "The app makes no cloud or model calls."),
            ("Account", "None. There is no sign-in.")
        ]
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        let title = NSTextField(labelWithString: "Workspace")
        title.font = .systemFont(ofSize: 11, weight: .medium)
        title.textColor = QuelytTheme.faint
        stack.addArrangedSubview(title)
        for (name, body) in items {
            let heading = NSTextField(labelWithString: name)
            heading.font = .systemFont(ofSize: 12, weight: .semibold)
            let detail = NSTextField(wrappingLabelWithString: body)
            detail.font = .systemFont(ofSize: 11)
            detail.textColor = QuelytTheme.inkMuted
            detail.maximumNumberOfLines = 4
            stack.addArrangedSubview(heading)
            stack.addArrangedSubview(detail)
        }
        settingsPane.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: settingsPane.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: settingsPane.trailingAnchor),
            stack.topAnchor.constraint(equalTo: settingsPane.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: settingsPane.bottomAnchor)
        ])
        for view in stack.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }

    private func buildGatedPane(_ pane: NSView, symbol: String, title: String, body: String) {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .light)
        icon.contentTintColor = QuelytTheme.inkMuted
        let heading = NSTextField(labelWithString: title)
        heading.font = .systemFont(ofSize: 13, weight: .semibold)
        heading.setAccessibilityIdentifier(pane === aiPane ? "ai-unavailable" : "connections-unavailable")
        let detail = NSTextField(wrappingLabelWithString: body)
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = QuelytTheme.inkMuted
        detail.maximumNumberOfLines = 8
        let stack = NSStackView(views: [icon, heading, detail])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        pane.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: pane.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: pane.trailingAnchor),
            stack.topAnchor.constraint(equalTo: pane.topAnchor),
            detail.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }
}
