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

final class WorkspaceSidebar: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var onOpen: (() -> Void)?
    var onOpenRecent: ((String) -> Void)?
    var onInsertColumn: ((String) -> Void)?
    var onSelectTrace: (([String: Any]) -> Void)?
    var onRerunTrace: (([String: Any]) -> Void)?

    let historyTable = NSTableView()
    private let recentsTable = NSTableView()
    private let columnTable = NSTableView()
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
    private var traces: [[String: Any]] = []
    private var reloading = false
    private let maxRecents = 7

    override func loadView() {
        let root = DatasetDropView()
        root.openFile = { [weak self] url in self?.onOpenRecent?(url.path) }
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        nameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        nameLabel.lineBreakMode = .byTruncatingMiddle
        metaLabel.font = .systemFont(ofSize: 11)
        metaLabel.textColor = .secondaryLabelColor
        metaLabel.maximumNumberOfLines = 3
        openButton.bezelStyle = .rounded
        openButton.controlSize = .small
        openButton.target = self
        openButton.action = #selector(openClicked)
        recentsLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        recentsLabel.textColor = .secondaryLabelColor
        configure(recentsTable, identifier: "recent", rowHeight: 22, label: "Recent datasets")
        recentsTable.target = self
        recentsTable.action = #selector(openSelectedRecent)
        recentsScroll.documentView = recentsTable
        recentsScroll.hasVerticalScroller = true
        recentsScroll.drawsBackground = false
        recentsScroll.borderType = .noBorder
        recentsHeight = recentsScroll.heightAnchor.constraint(equalToConstant: 0)
        let columnsHeader = NSTextField(labelWithString: "Columns")
        columnsHeader.font = .systemFont(ofSize: 11, weight: .semibold)
        columnsHeader.textColor = .secondaryLabelColor
        columnFilter.placeholderString = "Filter columns"
        columnFilter.controlSize = .small
        columnFilter.target = self
        columnFilter.action = #selector(filterColumns)
        columnFilter.sendsSearchStringImmediately = true
        columnFilter.setAccessibilityLabel("Filter columns")
        let columnBar = NSStackView(views: [columnsHeader, columnFilter])
        columnBar.distribution = .fill
        columnFilter.widthAnchor.constraint(greaterThanOrEqualToConstant: 90).isActive = true
        configure(columnTable, identifier: "column", rowHeight: 38, label: "Dataset columns")
        columnTable.target = self
        columnTable.action = #selector(insertSelectedColumn)
        let columnScroll = NSScrollView()
        columnScroll.documentView = columnTable
        columnScroll.hasVerticalScroller = true
        columnScroll.drawsBackground = false
        columnScroll.borderType = .noBorder
        let historyLabel = NSTextField(labelWithString: "History")
        historyLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        historyLabel.textColor = .secondaryLabelColor
        configure(historyTable, identifier: "history", rowHeight: 24, label: "Recent queries")
        historyTable.target = self
        historyTable.doubleAction = #selector(rerunSelected)
        let historyScroll = NSScrollView()
        historyScroll.documentView = historyTable
        historyScroll.hasVerticalScroller = true
        historyScroll.drawsBackground = false
        historyScroll.borderType = .noBorder
        let footer = NSTextField(labelWithString: "Local · Read only")
        footer.font = .systemFont(ofSize: 10, weight: .medium)
        footer.textColor = NSColor(calibratedRed: 0.2, green: 0.43, blue: 0.38, alpha: 1)
        for view in [nameLabel, metaLabel, openButton, recentsLabel, recentsScroll, columnBar, columnScroll, historyLabel, historyScroll, footer] {
            stack.addArrangedSubview(view)
        }
        columnScroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        historyScroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        recentsScroll.setContentHuggingPriority(.required, for: .vertical)
        recentsScroll.setContentCompressionResistancePriority(.required, for: .vertical)
        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            recentsHeight,
            recentsScroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
            columnBar.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
            columnScroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
            historyScroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
            columnScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            historyScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            columnScroll.heightAnchor.constraint(equalTo: historyScroll.heightAnchor),
            nameLabel.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
            metaLabel.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24)
        ])
        view = root
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
            field.font = .systemFont(ofSize: 11)
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
            name.lineBreakMode = .byTruncatingTail
            let meta = NSTextField(labelWithString: item.meta)
            meta.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
            meta.textColor = .secondaryLabelColor
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
}
