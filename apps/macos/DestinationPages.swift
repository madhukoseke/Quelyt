import AppKit

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

final class SchemaInspector: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var onOpen: (() -> Void)?
    var onOpenRecent: ((String) -> Void)?
    var onInsertColumn: ((String) -> Void)?

    let view = DatasetDropView()
    private let recentsTable = KeyActionTableView()
    private let columnTable = KeyActionTableView()
    private let columnFilter = NSSearchField()
    private let nameLabel = NSTextField(labelWithString: "No dataset")
    private let metaLabel = NSTextField(wrappingLabelWithString: "Open or drop a CSV / Parquet file.")
    private let openButton = NSButton(title: "Open dataset…", target: nil, action: nil)
    private let recentsLabel = NSTextField(labelWithString: "Recents")
    private let recentsScroll = NSScrollView()
    private var recentsHeight: NSLayoutConstraint!
    private var columns: [SidebarColumn] = []
    private var visibleColumns: [SidebarColumn] = []
    private var recents: [[String: Any]] = []
    private let maxRecents = 7

    override init() {
        super.init()
        view.wantsLayer = true
        QuelytTheme.cardLayer(view, radius: QuelytTheme.radius)
        view.appearance = NSAppearance(named: .darkAqua)
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
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
        recentsTable.onReturn = { [weak self] in self?.openSelectedRecent() }
        recentsScroll.documentView = recentsTable
        recentsScroll.hasVerticalScroller = true
        recentsScroll.drawsBackground = false
        recentsScroll.borderType = .noBorder
        recentsHeight = recentsScroll.heightAnchor.constraint(equalToConstant: 0)
        let columnsHeader = QuelytTheme.sectionLabel("Columns")
        columnFilter.placeholderString = "Filter columns"
        columnFilter.controlSize = .small
        columnFilter.target = self
        columnFilter.action = #selector(filterColumns)
        columnFilter.sendsSearchStringImmediately = true
        columnFilter.setAccessibilityLabel("Filter columns")
        configure(columnTable, identifier: "column", rowHeight: 38, label: "Dataset columns")
        columnTable.target = self
        columnTable.action = #selector(insertSelectedColumn)
        columnTable.onReturn = { [weak self] in self?.insertSelectedColumn() }
        let columnScroll = NSScrollView()
        columnScroll.documentView = columnTable
        columnScroll.hasVerticalScroller = true
        columnScroll.drawsBackground = false
        columnScroll.borderType = .noBorder
        for item in [nameLabel, metaLabel, openButton, recentsLabel, recentsScroll, columnsHeader, columnFilter, columnScroll] {
            stack.addArrangedSubview(item)
        }
        columnScroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        recentsScroll.setContentHuggingPriority(.required, for: .vertical)
        recentsScroll.setContentCompressionResistancePriority(.required, for: .vertical)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            recentsHeight,
            recentsScroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
            columnFilter.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
            columnScroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
            columnScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            nameLabel.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
            metaLabel.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24)
        ])
        setDataset(url: nil, rows: nil, columns: nil)
        setRecents([])
    }

    func setDataset(url: URL?, rows: Int?, columns: Int?) {
        if let url = url {
            nameLabel.stringValue = url.lastPathComponent
            let format = url.pathExtension.uppercased()
            var parts = [format]
            if let rows = rows { parts.append("\(rows.formatted()) rows") }
            if let columns = columns { parts.append("\(columns) columns") }
            parts.append("source unchanged")
            metaLabel.stringValue = parts.joined(separator: " · ")
            openButton.isHidden = true
        } else {
            nameLabel.stringValue = "No dataset"
            metaLabel.stringValue = "Open or drop a CSV / Parquet file."
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

    func selectColumn(at row: Int) {
        guard row >= 0, row < visibleColumns.count else { return }
        columnTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }

    func selectRecent(at row: Int) {
        guard row >= 0, row < recents.count else { return }
        recentsTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }

    func performColumnReturn() { insertSelectedColumn() }
    func performRecentReturn() { openSelectedRecent() }

    @objc func filterColumns() { reloadColumns() }
    @objc func openClicked() { onOpen?() }
    @objc func insertSelectedColumn() { insertColumn(at: columnTable.selectedRow) }
    @objc func openSelectedRecent() {
        let row = recentsTable.selectedRow
        guard row >= 0, row < recents.count, let path = recents[row]["path"] as? String else { return }
        onOpenRecent?(path)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === recentsTable ? recents.count : visibleColumns.count
    }

    func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        if tableView === recentsTable {
            guard row < recents.count else { return nil }
            let field = NSTextField(labelWithString: recents[row]["name"] as? String ?? recents[row]["path"] as? String ?? "")
            field.font = .systemFont(ofSize: 12)
            field.textColor = QuelytTheme.ink
            field.lineBreakMode = .byTruncatingMiddle
            field.toolTip = recents[row]["path"] as? String
            return field
        }
        guard row < visibleColumns.count else { return nil }
        let item = visibleColumns[row]
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 1
        let name = NSTextField(labelWithString: item.name)
        name.font = .systemFont(ofSize: 12, weight: .medium)
        name.textColor = QuelytTheme.ink
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
}

final class HistoryPage: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var onSelectTrace: (([String: Any]) -> Void)?
    var onRerunTrace: (([String: Any]) -> Void)?

    let view = NSView()
    let table = KeyActionTableView()
    private var traces: [[String: Any]] = []
    private var reloading = false

    override init() {
        super.init()
        view.wantsLayer = true
        view.layer?.backgroundColor = QuelytTheme.canvas.cgColor
        let title = NSTextField(labelWithString: "SQL history")
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.textColor = QuelytTheme.ink
        let hint = NSTextField(wrappingLabelWithString: "Arrow keys load SQL. Return or double-click reruns against its source file.")
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = QuelytTheme.inkMuted
        hint.maximumNumberOfLines = 3
        table.headerView = nil
        table.rowHeight = 44
        table.delegate = self
        table.dataSource = self
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular
        table.setAccessibilityLabel("Recent queries")
        table.target = self
        table.doubleAction = #selector(rerunSelected)
        table.onReturn = { [weak self] in self?.rerunSelectedTrace() }
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("history"))
        column.width = 480
        table.addTableColumn(column)
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        QuelytTheme.cardLayer(scroll)
        let stack = NSStackView(views: [title, hint, scroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            hint.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    func setTraces(_ items: [[String: Any]]) {
        reloading = true
        traces = items
        table.reloadData()
        table.deselectAll(nil)
        reloading = false
    }

    func selectTrace(at row: Int) {
        guard row >= 0, row < traces.count else { return }
        reloading = true
        table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        reloading = false
    }

    func performHistoryReturn() { rerunSelectedTrace() }

    func selectedTrace() -> [String: Any]? {
        let row = table.selectedRow
        guard row >= 0, row < traces.count else { return nil }
        return traces[row]
    }

    func rerunSelectedTrace() {
        let row = table.selectedRow >= 0 ? table.selectedRow : table.clickedRow
        guard row >= 0, row < traces.count else { return }
        onRerunTrace?(traces[row])
    }

    @objc func rerunSelected() { rerunSelectedTrace() }

    func numberOfRows(in tableView: NSTableView) -> Int { traces.count }

    func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        guard row < traces.count else { return nil }
        let trace = traces[row]
        let sql = (trace["sql"] as? String ?? "").split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let ok = (trace["ok"] as? Bool) == true
        let path = (trace["path"] as? String).map { URL(fileURLWithPath: $0).lastPathComponent } ?? ""
        let title = NSTextField(labelWithString: sql)
        title.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        title.textColor = QuelytTheme.ink
        title.lineBreakMode = .byTruncatingTail
        let mark = ok ? "Ran" : "Error"
        let detail = NSTextField(labelWithString: [mark, path].filter { !$0.isEmpty }.joined(separator: " · "))
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = ok ? QuelytTheme.inkMuted : QuelytTheme.danger
        detail.lineBreakMode = .byTruncatingMiddle
        let stack = NSStackView(views: [title, detail])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.toolTip = trace["sql"] as? String
        return stack
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !reloading, let trace = selectedTrace() else { return }
        onSelectTrace?(trace)
    }
}

final class HonestPage: NSView {
    init(symbol: String, title: String, body: String, accessibilityID: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = QuelytTheme.canvas.cgColor
        let card = NSView()
        QuelytTheme.cardLayer(card)
        card.translatesAutoresizingMaskIntoConstraints = false
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 22, weight: .light)
        icon.contentTintColor = QuelytTheme.accent
        let heading = NSTextField(labelWithString: title)
        heading.font = .systemFont(ofSize: 18, weight: .semibold)
        heading.textColor = QuelytTheme.ink
        heading.setAccessibilityIdentifier(accessibilityID)
        let detail = NSTextField(wrappingLabelWithString: body)
        detail.font = .systemFont(ofSize: 13)
        detail.textColor = QuelytTheme.inkMuted
        detail.alignment = .center
        detail.maximumNumberOfLines = 8
        let stack = NSStackView(views: [icon, heading, detail])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        addSubview(card)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -48),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 460),
            card.widthAnchor.constraint(greaterThanOrEqualToConstant: 280),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -28),
            detail.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class SettingsPage: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = QuelytTheme.canvas.cgColor
        let items = [
            ("Scope", "Local CSV and Parquet on this Mac."),
            ("History", "SQL traces live in Application Support. Result grids are not stored."),
            ("Network", "The app makes no cloud or model calls."),
            ("Account", "None. There is no sign-in.")
        ]
        let card = NSView()
        QuelytTheme.cardLayer(card)
        card.translatesAutoresizingMaskIntoConstraints = false
        let title = NSTextField(labelWithString: "Workspace")
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.textColor = QuelytTheme.ink
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(title)
        for (name, body) in items {
            let heading = NSTextField(labelWithString: name)
            heading.font = .systemFont(ofSize: 12, weight: .semibold)
            heading.textColor = QuelytTheme.ink
            let detail = NSTextField(wrappingLabelWithString: body)
            detail.font = .systemFont(ofSize: 12)
            detail.textColor = QuelytTheme.inkMuted
            detail.maximumNumberOfLines = 4
            stack.addArrangedSubview(heading)
            stack.addArrangedSubview(detail)
        }
        card.addSubview(stack)
        addSubview(card)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            card.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 520),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
        for item in stack.arrangedSubviews {
            item.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
