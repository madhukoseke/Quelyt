import AppKit
import UniformTypeIdentifiers
import Darwin

final class DatasetDropView: NSView {
    var openFile: ((URL) -> Void)?
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) ? .copy : []
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], urls.count == 1 else { return false }
        openFile?(urls[0]); return true
    }
}

extension NSToolbarItem.Identifier {
    static let openDataset = NSToolbarItem.Identifier("openDataset")
    static let runQuery = NSToolbarItem.Identifier("runQuery")
    static let cancelQuery = NSToolbarItem.Identifier("cancelQuery")
    static let profileDataset = NSToolbarItem.Identifier("profileDataset")
    static let copyRows = NSToolbarItem.Identifier("copyRows")
    static let localBadge = NSToolbarItem.Identifier("localBadge")
}

final class ResultsTableView: NSTableView {
    var selectedText: (() -> String?)?
    @objc func copy(_ sender: Any?) {
        guard let text = selectedText?() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

final class ResultChartView: NSView {
    var kind = "none"
    var labels: [String] = []
    var numbers: [Double] = []
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        QuelytTheme.surface.setFill(); dirtyRect.fill()
        QuelytTheme.line.setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)); border.lineWidth = 1; border.stroke()
        guard kind == "bar" || kind == "line", numbers.count >= 2, numbers.count == labels.count else { return }
        let plot = NSRect(x: 36, y: 28, width: max(bounds.width - 48, 8), height: max(bounds.height - 54, 8))
        let low = min(0, numbers.min() ?? 0)
        let high = max(0, max(numbers.max() ?? 1, low + 1))
        let span = high - low
        let count = CGFloat(numbers.count)
        QuelytTheme.lineStrong.setStroke()
        let axes = NSBezierPath(); axes.lineWidth = 1
        axes.move(to: NSPoint(x: plot.minX, y: plot.maxY)); axes.line(to: NSPoint(x: plot.maxX, y: plot.maxY))
        axes.move(to: NSPoint(x: plot.minX, y: plot.minY)); axes.line(to: NSPoint(x: plot.minX, y: plot.maxY))
        axes.stroke()
        let series = QuelytTheme.chart
        if kind == "bar" {
            let slot = plot.width / count
            let width = slot * 0.62
            for (index, value) in numbers.enumerated() {
                let zeroY = plot.maxY - CGFloat((0 - low) / span) * plot.height
                let valueY = plot.maxY - CGFloat((value - low) / span) * plot.height
                let height = max(abs(zeroY - valueY), 1)
                let x = plot.minX + slot * CGFloat(index) + (slot - width) / 2
                series.withAlphaComponent(0.88).setFill()
                NSBezierPath(roundedRect: NSRect(x: x, y: min(zeroY, valueY), width: width, height: height), xRadius: 2, yRadius: 2).fill()
            }
        } else {
            let line = NSBezierPath(); line.lineWidth = 2; line.lineJoinStyle = .round
            for (index, value) in numbers.enumerated() {
                let point = NSPoint(
                    x: plot.minX + plot.width * CGFloat(index) / max(count - 1, 1),
                    y: plot.maxY - CGFloat((value - low) / span) * plot.height
                )
                if index == 0 { line.move(to: point) } else { line.line(to: point) }
            }
            series.setStroke(); line.stroke(); series.setFill()
            for (index, value) in numbers.enumerated() {
                let x = plot.minX + plot.width * CGFloat(index) / max(count - 1, 1)
                let y = plot.maxY - CGFloat((value - low) / span) * plot.height
                NSBezierPath(ovalIn: NSRect(x: x - 3, y: y - 3, width: 6, height: 6)).fill()
            }
        }
        let caption: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: QuelytTheme.inkMuted]
        let slot = plot.width / count
        for (index, label) in labels.enumerated() {
            let text = String(label.prefix(12)) as NSString
            let size = text.size(withAttributes: caption)
            let x = kind == "line"
                ? plot.minX + plot.width * CGFloat(index) / max(count - 1, 1) - size.width / 2
                : plot.minX + slot * CGFloat(index) + (slot - size.width) / 2
            text.draw(at: NSPoint(x: x, y: bounds.height - 18), withAttributes: caption)
        }
        (String(format: "%g", high) as NSString).draw(at: NSPoint(x: 4, y: plot.minY - 2), withAttributes: caption)
        let title = ((kind == "bar" ? "Bar" : "Line") + " chart · from this query") as NSString
        title.draw(at: NSPoint(x: plot.minX, y: 6), withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: QuelytTheme.inkMuted])
    }
}

final class QuelytApp: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSToolbarDelegate, NSSplitViewDelegate {
    var window: NSWindow!
    let editor = SQLEditor()
    let table = ResultsTableView()
    let status = NSTextField(wrappingLabelWithString: "Open a dataset to run a query.")
    let sidebar = WorkspaceSidebar()
    let schema = SchemaInspector()
    let historyPage = HistoryPage()
    let insetHeader = InsetHeader()
    let connectionsPage = HonestPage(
        symbol: "link",
        title: "Connections",
        body: "Remote database connections are not in this developer build. Open a local CSV or Parquet file from Databases. Source files stay on this Mac.",
        accessibilityID: "connections-unavailable"
    )
    let settingsPage = SettingsPage()
    let aiPage = HonestPage(
        symbol: "sparkles",
        title: "AI is research-only",
        body: "Talk to Data stays out of the product. The held-out evaluation did not meet quality gates. This app makes no model or network calls.",
        accessibilityID: "ai-unavailable"
    )
    let databasesPage = NSView()
    var workspaceSplit: NSSplitView!
    var split: NSSplitViewController!
    var dataSplit: NSSplitView!
    let palette = CommandPalette()
    var runItem: NSToolbarItem!
    var cancelItem: NSToolbarItem!
    var profileItem: NSToolbarItem!
    var copyItem: NSToolbarItem!
    let chartView = ResultChartView()
    var chartHeight: NSLayoutConstraint!
    var lastResponse: [String: Any]?
    var lastResponseData: Data?
    var allRows: [[Any]] = []
    let resultFilter = NSSearchField()
    let chartToggle = NSButton(checkboxWithTitle: "Chart", target: nil, action: nil)
    let exportButton = NSButton(title: "Export…", target: nil, action: #selector(exportResults))
    let resultContainer = NSView()
    let resultScroll = NSScrollView()
    let resultSummary = NSTextField(labelWithString: "")
    let statePanel = NSStackView()
    let stateIcon = NSImageView()
    let stateSpinner = NSProgressIndicator()
    let stateTitle = NSTextField(labelWithString: "")
    let stateDescription = NSTextField(wrappingLabelWithString: "")
    let stateOpenButton = NSButton(title: "Open dataset…", target: nil, action: nil)
    var openingDataset = false
    var selectedURL: URL?
    var rows: [[Any]] = []
    var columns: [[String: Any]] = []
    var process: Process?
    var activeID: UUID?
    var cancelled = false
    var timedOut = false
    var smokeStage = 0
    var smokeResults: [[String: Any]] = []
    var workerStarted: TimeInterval = 0
    var compareStage = 0
    var previewTimes: [Double] = []
    var aggregateTimes: [Double] = []
    var compareWriteRejected = false
    var compareCancelled = false
    var recentMenu: NSMenu!

    func skipHistory() -> Bool {
        compareOutput() != nil || CommandLine.arguments.contains("--smoke-test") || CommandLine.arguments.contains("--ui-checks") || ProcessInfo.processInfo.environment["QUELYT_BENCHMARK"] == "1"
    }

    func label(_ text: String, size: CGFloat = 12, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
        let view = NSTextField(labelWithString: text)
        view.font = .systemFont(ofSize: size, weight: weight); view.textColor = color == .labelColor ? QuelytTheme.ink : color
        return view
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        setupMenu()
        wireSidebar()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 790), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Quelyt"; window.minSize = NSSize(width: 980, height: 720)
        QuelytTheme.applyChrome(to: window)
        let contentRoot = DatasetDropView()
        contentRoot.wantsLayer = true; contentRoot.layer?.backgroundColor = QuelytTheme.canvas.cgColor
        contentRoot.openFile = { [weak self] url in self?.openDataset(url) }
        if let drop = sidebar.view as? DatasetDropView { drop.openFile = { [weak self] url in self?.openDataset(url) } }
        schema.view.openFile = { [weak self] url in self?.openDataset(url) }
        editor.font = .monospacedSystemFont(ofSize: 13, weight: .regular); editor.string = "-- Open a CSV or Parquet file to start.\n-- Your table will be available as dataset."
        editor.isRichText = false; editor.allowsUndo = true; editor.isAutomaticQuoteSubstitutionEnabled = false; editor.isAutomaticDashSubstitutionEnabled = false; editor.isAutomaticTextReplacementEnabled = false
        editor.drawsBackground = true; editor.backgroundColor = QuelytTheme.surface; editor.insertionPointColor = QuelytTheme.ink
        editor.textContainerInset = NSSize(width: 15, height: 14); editor.setAccessibilityLabel("SQL query")
        let editorScroll = NSScrollView(); editorScroll.documentView = editor; editorScroll.hasVerticalScroller = true; editorScroll.drawsBackground = true; editorScroll.backgroundColor = QuelytTheme.surface
        QuelytTheme.cardLayer(editorScroll)
        editor.minSize = NSSize(width: 0, height: 80); editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude); editor.isVerticallyResizable = true; editor.autoresizingMask = [.width]; editor.textContainer?.widthTracksTextView = true
        table.delegate = self; table.dataSource = self; table.allowsMultipleSelection = true; table.rowHeight = QuelytTheme.row; table.usesAlternatingRowBackgroundColors = false; table.columnAutoresizingStyle = .noColumnAutoresizing; table.setAccessibilityLabel("Query results")
        table.backgroundColor = QuelytTheme.surface; table.gridStyleMask = .solidVerticalGridLineMask; table.gridColor = QuelytTheme.line
        table.selectedText = { [weak self] in
            guard let self = self, !self.table.selectedRowIndexes.isEmpty else { return nil }
            func quote(_ text: String) -> String {
                if text.contains("\t") || text.contains("\n") || text.contains("\r") || text.contains("\"") { return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
                return text
            }
            let header = self.columns.map { quote($0["name"] as? String ?? "") }.joined(separator: "\t")
            let selected = self.table.selectedRowIndexes.filter { $0 < self.rows.count }.map { index in self.rows[index].map { quote($0 is NSNull ? "NULL" : String(describing: $0)) }.joined(separator: "\t") }
            return ([header] + selected).joined(separator: "\n")
        }
        let grid = resultScroll; grid.documentView = table; grid.hasVerticalScroller = true; grid.hasHorizontalScroller = true
        QuelytTheme.cardLayer(resultContainer, radius: QuelytTheme.radiusSm)
        resultContainer.addSubview(grid); grid.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([grid.leadingAnchor.constraint(equalTo: resultContainer.leadingAnchor),grid.trailingAnchor.constraint(equalTo: resultContainer.trailingAnchor),grid.topAnchor.constraint(equalTo: resultContainer.topAnchor),grid.bottomAnchor.constraint(equalTo: resultContainer.bottomAnchor)])
        statePanel.orientation = .vertical; statePanel.alignment = .centerX; statePanel.spacing = 12; statePanel.translatesAutoresizingMaskIntoConstraints = false
        stateIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 27, weight: .light); stateIcon.contentTintColor = QuelytTheme.accent
        stateTitle.font = .systemFont(ofSize: 18, weight: .medium); stateTitle.textColor = QuelytTheme.ink; stateDescription.font = .systemFont(ofSize: 12); stateDescription.textColor = QuelytTheme.inkMuted; stateDescription.alignment = .center; stateDescription.maximumNumberOfLines = 7
        stateOpenButton.target = self; stateOpenButton.action = #selector(openPanel); stateOpenButton.bezelStyle = .rounded
        stateSpinner.style = .spinning; stateSpinner.controlSize = .small; stateSpinner.isDisplayedWhenStopped = false
        for view in [stateIcon,stateSpinner,stateTitle,stateDescription,stateOpenButton] { statePanel.addArrangedSubview(view) }
        resultContainer.addSubview(statePanel)
        NSLayoutConstraint.activate([
            statePanel.centerXAnchor.constraint(equalTo: resultContainer.centerXAnchor),
            statePanel.centerYAnchor.constraint(equalTo: resultContainer.centerYAnchor),
            stateDescription.widthAnchor.constraint(lessThanOrEqualTo: resultContainer.widthAnchor, constant: -32),
            stateDescription.widthAnchor.constraint(lessThanOrEqualToConstant: 350)
        ])
        resultSummary.font = .systemFont(ofSize: 11); resultSummary.textColor = QuelytTheme.inkMuted
        resultSummary.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        resultFilter.placeholderString = "Filter returned rows"; resultFilter.target = self; resultFilter.action = #selector(filterResults); resultFilter.sendsSearchStringImmediately = true; resultFilter.setAccessibilityLabel("Filter returned results")
        resultFilter.controlSize = .small
        resultFilter.appearance = NSAppearance(named: .darkAqua)
        resultFilter.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        resultFilter.widthAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
        chartToggle.target = self; chartToggle.action = #selector(toggleChart); chartToggle.state = .on; chartToggle.isEnabled = false
        chartToggle.controlSize = .small
        chartToggle.setContentHuggingPriority(.required, for: .horizontal)
        exportButton.target = self; exportButton.bezelStyle = .roundRect; exportButton.isEnabled = false
        exportButton.controlSize = .small
        exportButton.appearance = NSAppearance(named: .darkAqua)
        exportButton.setContentHuggingPriority(.required, for: .horizontal)
        let queryMeta = label("SQL · ⌘ Return · Esc complete · ⌘K", size: 10, color: QuelytTheme.inkMuted)
        let queryHeader = NSStackView(views: [label("Query", size: 12, weight: .semibold), queryMeta]); queryHeader.spacing = 12
        queryHeader.alignment = .centerY
        let resultHeader = NSStackView(views: [label("Results", size: 12, weight: .semibold), resultSummary, resultFilter, chartToggle, exportButton]); resultHeader.spacing = 8
        resultHeader.alignment = .centerY
        chartHeight = chartView.heightAnchor.constraint(equalToConstant: 0); chartHeight.isActive = true
        chartView.isHidden = true
        QuelytTheme.cardLayer(chartView)
        resultScroll.drawsBackground = true; resultScroll.backgroundColor = QuelytTheme.surface
        status.font = .systemFont(ofSize: 11); status.textColor = QuelytTheme.inkMuted
        status.translatesAutoresizingMaskIntoConstraints = false
        resultContainer.setContentHuggingPriority(.defaultLow, for: .vertical)
        let resultsPane = NSStackView(views: [resultHeader, resultContainer, chartView])
        resultsPane.orientation = .vertical
        resultsPane.alignment = .leading
        resultsPane.spacing = 8
        for pane in [resultHeader, resultContainer, chartView] {
            pane.widthAnchor.constraint(equalTo: resultsPane.widthAnchor).isActive = true
        }
        let editorPane = NSStackView(views: [queryHeader, editorScroll])
        editorPane.orientation = .vertical
        editorPane.alignment = .leading
        editorPane.spacing = 8
        queryHeader.widthAnchor.constraint(equalTo: editorPane.widthAnchor).isActive = true
        editorScroll.widthAnchor.constraint(equalTo: editorPane.widthAnchor).isActive = true
        dataSplit = NSSplitView()
        dataSplit.isVertical = false
        dataSplit.dividerStyle = .thin
        dataSplit.delegate = self
        dataSplit.addSubview(editorPane)
        dataSplit.addSubview(resultsPane)
        let queryColumn = NSView()
        dataSplit.translatesAutoresizingMaskIntoConstraints = false
        queryColumn.addSubview(dataSplit)
        queryColumn.addSubview(status)
        NSLayoutConstraint.activate([
            dataSplit.topAnchor.constraint(equalTo: queryColumn.topAnchor, constant: 12),
            dataSplit.leadingAnchor.constraint(equalTo: queryColumn.leadingAnchor, constant: 12),
            dataSplit.trailingAnchor.constraint(equalTo: queryColumn.trailingAnchor, constant: -16),
            dataSplit.bottomAnchor.constraint(equalTo: status.topAnchor, constant: -10),
            status.leadingAnchor.constraint(equalTo: queryColumn.leadingAnchor, constant: 12),
            status.trailingAnchor.constraint(equalTo: queryColumn.trailingAnchor, constant: -16),
            status.bottomAnchor.constraint(equalTo: queryColumn.bottomAnchor, constant: -12)
        ])
        let schemaPane = NSView()
        schemaPane.wantsLayer = true
        schemaPane.layer?.backgroundColor = QuelytTheme.canvas.cgColor
        schema.view.translatesAutoresizingMaskIntoConstraints = false
        schemaPane.addSubview(schema.view)
        NSLayoutConstraint.activate([
            schema.view.leadingAnchor.constraint(equalTo: schemaPane.leadingAnchor, constant: 12),
            schema.view.trailingAnchor.constraint(equalTo: schemaPane.trailingAnchor, constant: -8),
            schema.view.topAnchor.constraint(equalTo: schemaPane.topAnchor, constant: 12),
            schema.view.bottomAnchor.constraint(equalTo: schemaPane.bottomAnchor, constant: -12)
        ])
        workspaceSplit = NSSplitView()
        workspaceSplit.isVertical = true
        workspaceSplit.dividerStyle = .thin
        workspaceSplit.delegate = self
        workspaceSplit.addSubview(schemaPane)
        workspaceSplit.addSubview(queryColumn)
        workspaceSplit.translatesAutoresizingMaskIntoConstraints = false
        databasesPage.wantsLayer = true
        databasesPage.layer?.backgroundColor = QuelytTheme.canvas.cgColor
        databasesPage.addSubview(workspaceSplit)
        NSLayoutConstraint.activate([
            workspaceSplit.leadingAnchor.constraint(equalTo: databasesPage.leadingAnchor),
            workspaceSplit.trailingAnchor.constraint(equalTo: databasesPage.trailingAnchor),
            workspaceSplit.topAnchor.constraint(equalTo: databasesPage.topAnchor),
            workspaceSplit.bottomAnchor.constraint(equalTo: databasesPage.bottomAnchor)
        ])
        let pageHost = NSView()
        pageHost.translatesAutoresizingMaskIntoConstraints = false
        pageHost.wantsLayer = true
        pageHost.layer?.backgroundColor = QuelytTheme.canvas.cgColor
        for page in [databasesPage, historyPage.view, connectionsPage, settingsPage, aiPage] {
            page.translatesAutoresizingMaskIntoConstraints = false
            pageHost.addSubview(page)
            NSLayoutConstraint.activate([
                page.leadingAnchor.constraint(equalTo: pageHost.leadingAnchor),
                page.trailingAnchor.constraint(equalTo: pageHost.trailingAnchor),
                page.topAnchor.constraint(equalTo: pageHost.topAnchor),
                page.bottomAnchor.constraint(equalTo: pageHost.bottomAnchor)
            ])
        }
        contentRoot.addSubview(insetHeader)
        contentRoot.addSubview(pageHost)
        NSLayoutConstraint.activate([
            insetHeader.topAnchor.constraint(equalTo: contentRoot.topAnchor),
            insetHeader.leadingAnchor.constraint(equalTo: contentRoot.leadingAnchor),
            insetHeader.trailingAnchor.constraint(equalTo: contentRoot.trailingAnchor),
            pageHost.topAnchor.constraint(equalTo: insetHeader.bottomAnchor),
            pageHost.leadingAnchor.constraint(equalTo: contentRoot.leadingAnchor),
            pageHost.trailingAnchor.constraint(equalTo: contentRoot.trailingAnchor),
            pageHost.bottomAnchor.constraint(equalTo: contentRoot.bottomAnchor)
        ])
        let contentController = NSViewController(); contentController.view = contentRoot
        split = NSSplitViewController()
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
        sidebarItem.minimumThickness = QuelytTheme.sidebarCompact
        sidebarItem.maximumThickness = 260
        sidebarItem.canCollapse = true
        let contentItem = NSSplitViewItem(viewController: contentController)
        contentItem.minimumThickness = 520
        split.addSplitViewItem(sidebarItem)
        split.addSplitViewItem(contentItem)
        window.contentViewController = split
        let toolbar = NSToolbar(identifier: "dev.quelyt.desktop.toolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
        window.center(); window.makeKeyAndOrderFront(nil)
        split.splitView.setPosition(QuelytTheme.sidebarDefault, ofDividerAt: 0)
        workspaceSplit.setPosition(220, ofDividerAt: 0)
        dataSplit.setPosition(180, ofDividerAt: 0)
        showDestination(.databases)
        setBusy(false)
        showState("Open a dataset", message: "Choose a CSV or Parquet file, or drop one onto the workspace. Your data stays on this Mac.", symbol: "tablecells", canOpen: true)
        NSApp.activate(ignoringOtherApps: true); window.makeFirstResponder(editor)
        if CommandLine.arguments.count > 1 && !CommandLine.arguments[1].hasPrefix("--") { openDataset(URL(fileURLWithPath: CommandLine.arguments[1])) }
        if !skipHistory() {
            reloadHistory()
            if selectedURL == nil, !CommandLine.arguments.contains("--snapshot"), let last = lastReadableSource() { openDataset(last) }
        }
        capturePreview()
        if let flag = CommandLine.arguments.firstIndex(of: "--ui-checks"), CommandLine.arguments.count > flag + 1 { runUIChecks(output: CommandLine.arguments[flag + 1]) }
    }
    func wireSidebar() {
        schema.onOpen = { [weak self] in self?.openPanel() }
        schema.onOpenRecent = { [weak self] path in
            guard let self = self, self.process == nil else { return }
            self.openDataset(URL(fileURLWithPath: path))
        }
        schema.onInsertColumn = { [weak self] name in
            guard let self = self else { return }
            self.sidebar.selectDestination(.databases)
            self.window.makeFirstResponder(self.editor)
            self.editor.insertIdentifier(name)
        }
        historyPage.onSelectTrace = { [weak self] trace in
            guard let self = self, self.process == nil, let sql = trace["sql"] as? String else { return }
            self.editor.string = sql
            if let path = trace["path"] as? String, self.selectedURL?.path != path, ["csv", "parquet"].contains(URL(fileURLWithPath: path).pathExtension.lowercased()) {
                self.status.stringValue = "History SQL loaded. Open that dataset to run it."
            }
        }
        historyPage.onRerunTrace = { [weak self] trace in self?.runHistory(trace) }
        sidebar.onNavigate = { [weak self] destination in
            self?.showDestination(destination)
        }
    }
    func showDestination(_ destination: SidebarDestination) {
        databasesPage.isHidden = destination != .databases
        historyPage.view.isHidden = destination != .history
        connectionsPage.isHidden = destination != .connections
        settingsPage.isHidden = destination != .settings
        aiPage.isHidden = destination != .ai
        updateBreadcrumbs()
        switch destination {
        case .connections:
            status.stringValue = "Remote connections are not available. Open a local CSV or Parquet file from Databases."
        case .ai:
            status.stringValue = "Talk to Data stays out of the app until evaluation gates pass. No model calls are made."
        case .settings:
            status.stringValue = "Local workspace. No account. No network connection."
        case .history:
            status.stringValue = "Arrow keys load SQL. Return reruns against its source file."
        case .databases:
            break
        }
    }
    func updateBreadcrumbs() {
        var crumbs = ["Quelyt", sidebar.selectedDestination.title]
        if sidebar.selectedDestination == .databases, let name = selectedURL?.lastPathComponent {
            crumbs.append(name)
        }
        insetHeader.setCrumbs(crumbs)
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .openDataset, .runQuery, .cancelQuery, .profileDataset, .copyRows, .flexibleSpace, .localBadge]
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .openDataset, .runQuery, .cancelQuery, .profileDataset, .copyRows, .flexibleSpace, .localBadge]
    }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .toggleSidebar:
            return NSToolbarItem(itemIdentifier: .toggleSidebar)
        case .openDataset:
            return toolbarItem(.openDataset, title: "Open", symbol: "folder", action: #selector(openPanel), toolTip: "Open a CSV or Parquet file")
        case .runQuery:
            let button = NSButton(title: "Run", target: self, action: #selector(runQuery))
            button.bezelStyle = .rounded
            button.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Run query")
            button.imagePosition = .imageLeading
            button.bezelColor = QuelytTheme.primary
            button.contentTintColor = QuelytTheme.primaryInk
            runItem = NSToolbarItem(itemIdentifier: .runQuery)
            runItem.label = "Run"
            runItem.paletteLabel = "Run"
            runItem.toolTip = "Run query (⌘ Return)"
            runItem.view = button
            return runItem
        case .cancelQuery:
            cancelItem = toolbarItem(.cancelQuery, title: "Cancel", symbol: "stop.fill", action: #selector(cancelQuery), toolTip: "Cancel the running query")
            return cancelItem
        case .profileDataset:
            profileItem = toolbarItem(.profileDataset, title: "Profile", symbol: "chart.bar", action: #selector(profile), toolTip: "Profile dataset")
            return profileItem
        case .copyRows:
            copyItem = toolbarItem(.copyRows, title: "Copy", symbol: "doc.on.doc", action: #selector(ResultsTableView.copy(_:)), toolTip: "Copy selected result rows with headers (⌘C)")
            copyItem.target = table
            return copyItem
        case .localBadge:
            let item = NSToolbarItem(itemIdentifier: .localBadge)
            let badge = label("Local · Read only", size: 11, weight: .medium, color: QuelytTheme.inkMuted)
            item.view = badge
            item.label = "Local"
            return item
        default:
            return nil
        }
    }
    func toolbarItem(_ identifier: NSToolbarItem.Identifier, title: String, symbol: String, action: Selector, toolTip: String) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = title
        item.paletteLabel = title
        item.toolTip = toolTip
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        item.action = action
        item.target = self
        item.isBordered = true
        return item
    }
    func showState(_ title: String, message: String, symbol: String, canOpen: Bool = false, loading: Bool = false) {
        resultScroll.isHidden = true; statePanel.isHidden = false; stateTitle.stringValue = title; stateDescription.stringValue = message
        stateIcon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil); stateIcon.isHidden = loading
        stateOpenButton.isHidden = !canOpen
        stateSpinner.isHidden = !loading
        if loading { stateSpinner.startAnimation(nil) } else { stateSpinner.stopAnimation(nil) }
    }
    func capturePreview() {
        guard let flag = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > flag + 1 else { return }
        let output = CommandLine.arguments[flag + 1]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard let view = self.window.contentView else { return }
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()
            let bounds = view.bounds
            let pdf = view.dataWithPDF(inside: bounds)
            let image = NSImage(data: pdf) ?? NSImage(size: bounds.size)
            guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else { return }
            try? png.write(to: URL(fileURLWithPath: output))
        }
    }
    

    func setupMenu() {
        let main = NSMenu(); let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu(); appMenu.addItem(withTitle: "Quit Quelyt", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); appItem.submenu = appMenu
        let fileItem = NSMenuItem(); main.addItem(fileItem); let file = NSMenu(title: "File"); fileItem.submenu = file
        let open = file.addItem(withTitle: "Open dataset…", action: #selector(openPanel), keyEquivalent: "o"); open.target = self
        let recentItem = file.addItem(withTitle: "Open Recent", action: nil, keyEquivalent: "")
        recentMenu = NSMenu(title: "Open Recent"); recentItem.submenu = recentMenu
        let clear = file.addItem(withTitle: "Clear History…", action: #selector(clearHistory), keyEquivalent: ""); clear.target = self
        let remove = file.addItem(withTitle: "Delete Selected Trace", action: #selector(deleteSelectedTrace), keyEquivalent: ""); remove.target = self
        let editItem = NSMenuItem(); main.addItem(editItem); let edit = NSMenu(title: "Edit"); editItem.submenu = edit
        for (title, selector, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] { edit.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key) }
        for (title, action, key) in [("Save Query…", #selector(saveQuery), "s"), ("Open Query…", #selector(loadQuery), ""), ("Export Returned Results…", #selector(exportResults), "")] { let item = file.addItem(withTitle: title, action: action, keyEquivalent: key); item.target = self }
        let queryItem = NSMenuItem(); main.addItem(queryItem); let queryMenu = NSMenu(title: "Workspace"); queryItem.submenu = queryMenu
        let run = queryMenu.addItem(withTitle: "Run Query", action: #selector(runQuery), keyEquivalent: "\r"); run.target = self; run.keyEquivalentModifierMask = .command
        let paletteItem = queryMenu.addItem(withTitle: "Command Palette", action: #selector(showPalette), keyEquivalent: "k"); paletteItem.target = self
        for (title, action, key) in [("Focus SQL Editor", #selector(focusEditor), "1"), ("Focus Results", #selector(focusResults), "2"), ("Focus History", #selector(focusHistory), "3"), ("Complete SQL", #selector(completeSQL), ""), ("Run Selected History Query", #selector(rerunHistory), "")] { let item = queryMenu.addItem(withTitle: title, action: action, keyEquivalent: key); item.target = self }
        let viewItem = NSMenuItem(); main.addItem(viewItem); let view = NSMenu(title: "View"); viewItem.submenu = view
        let sidebarItem = view.addItem(withTitle: "Hide Sidebar", action: #selector(toggleSidebar(_:)), keyEquivalent: "b")
        sidebarItem.target = self; sidebarItem.keyEquivalentModifierMask = .control
        NSApp.mainMenu = main
    }

    @objc func openPanel() {
        guard process == nil else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.commaSeparatedText, UTType(filenameExtension: "parquet") ?? .data]
        panel.beginSheetModal(for: window) { [weak self] result in
            if result == .OK, let url = panel.url { self?.openDataset(url) }
        }
    }
    func openDataset(_ url: URL, sql: String? = nil) {
        guard process == nil else { return }
        guard ["csv", "parquet"].contains(url.pathExtension.lowercased()) else { status.stringValue = "Choose one CSV or Parquet file."; return }
        openingDataset = true
        selectedURL = url
        window.title = url.lastPathComponent
        sidebar.selectDestination(.databases)
        schema.resetColumns()
        schema.setDataset(url: url, rows: nil, columns: nil)
        updateBreadcrumbs()
        editor.string = sql ?? "SELECT *\nFROM dataset\nLIMIT 200;"
        runQuery()
    }
    func setBusy(_ busy: Bool) {
        let canRun = !busy && selectedURL != nil
        runItem?.isEnabled = canRun
        (runItem?.view as? NSButton)?.isEnabled = canRun
        profileItem?.isEnabled = canRun
        cancelItem?.isEnabled = busy
        editor.isEditable = !busy
        copyItem?.isEnabled = !busy && !table.selectedRowIndexes.isEmpty
    }
    @objc func profile() {
        guard let url = selectedURL else { return }
        startWorker(["path": url.path, "action": "profile", "timeout_seconds": 15])
    }
    @objc func cancelQuery() {
        guard let process = process else { return }; cancelled = true; status.stringValue = "Cancelling…"; stop(process)
    }
    func stop(_ p: Process) {
        if p.isRunning { p.terminate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { if p.isRunning { kill(p.processIdentifier, SIGKILL) } }
    }
    @objc func runQuery() {
        guard let url = selectedURL else { return }
        startWorker(["path": url.path, "sql": editor.string, "timeout_seconds": 15])
    }
    func bundledPython() -> URL? {
        let bin = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/runtime/bin")
        for name in ["python3", "python"] {
            let url = bin.appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: url.path) { return url }
        }
        return nil
    }
    func bundledScript(_ name: String) -> URL? {
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/python/\(name).py")
        return FileManager.default.isReadableFile(atPath: url.path) ? url : nil
    }
    func makePythonProcess(_ script: String, extra: [String] = []) -> Process? {
        guard let python = bundledPython(), let scriptURL = bundledScript(script) else { return nil }
        let p = Process()
        p.executableURL = python
        p.arguments = ["-I", "-B", scriptURL.path] + extra
        p.environment = ["PATH": "/usr/bin:/bin", "PYTHONIOENCODING": "utf-8", "PYTHONDONTWRITEBYTECODE": "1"]
        return p
    }
    func rebuildResultColumns() {
        for col in table.tableColumns { table.removeTableColumn(col) }
        for (index, column) in columns.enumerated() {
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(String(index)))
            let name = column["name"] as? String ?? "Column"
            let type = column["type"] as? String ?? ""
            col.title = name
            col.width = 160
            col.sortDescriptorPrototype = NSSortDescriptor(key: String(index), ascending: true)
            let cell = TypedHeaderCell()
            cell.stringValue = name
            cell.typeName = type
            cell.symbolName = ColumnTypeGlyph.symbol(for: type)
            col.headerCell = cell
            table.addTableColumn(col)
        }
    }
    func startWorker(_ body: [String: Any]) {
        guard process == nil, selectedURL != nil else { return }
        guard let input = try? JSONSerialization.data(withJSONObject: body) else { return }
        guard let p = makePythonProcess("worker") else {
            status.stringValue = "Cannot start worker: bundled Python runtime is missing. Rebuild with apps/macos/build.sh."
            setBusy(false)
            showState("Worker unavailable", message: "The local query worker could not start. See the status message below.", symbol: "exclamationmark.circle")
            return
        }
        let stdin = Pipe(); let stdout = Pipe(); let stderr = Pipe(); p.standardInput = stdin; p.standardOutput = stdout; p.standardError = stderr
        let id = UUID(); activeID = id; cancelled = false; timedOut = false
        lastResponse = nil; lastResponseData = nil; allRows = []; resultFilter.stringValue = ""; resultFilter.isEnabled = false; exportButton.isEnabled = false; chartToggle.isEnabled = false
        rows = []; table.reloadData(); setChartVisible(false); chartView.kind = "none"
        resultSummary.stringValue = ""
        showState(openingDataset ? "Opening dataset…" : "Running query…", message: "Working locally. You can cancel at any time.", symbol: "", loading: true)
        openingDataset = false
        workerStarted = Date.timeIntervalSinceReferenceDate
        status.stringValue = "Reading selected data and running query…"; setBusy(true)
        do { try p.run() } catch { status.stringValue = "Cannot start worker: \(error.localizedDescription). Rebuild with apps/macos/build.sh."; setBusy(false); showState("Worker unavailable", message: "The local query worker could not start. See the status message below.", symbol: "exclamationmark.circle"); return }
        process = p
        stdin.fileHandleForWriting.write(input); try? stdin.fileHandleForWriting.close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self = self, self.activeID == id, p.isRunning else { return }; self.timedOut = true; self.stop(p)
        }
        // Drain stderr concurrently, so an error cannot fill a pipe and deadlock the worker.
        DispatchQueue.global().async { _ = stderr.fileHandleForReading.readDataToEndOfFile() }
        let recordedSQL = body["sql"] as? String ?? editor.string
        let recordedAction = body["action"] as? String ?? "query"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let data = stdout.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
            let response = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            DispatchQueue.main.async {
                guard let self = self, self.activeID == id else { return }
                self.process = nil; self.activeID = nil; self.setBusy(false)
                let roundTrip = (Date.timeIntervalSinceReferenceDate - self.workerStarted) * 1000
                self.recordSmoke(response)
                self.recordCompare(response, roundTrip: roundTrip)
                self.persistTrace(sql: (response?["sql"] as? String) ?? recordedSQL, action: recordedAction, response: response, cancelled: self.cancelled, timedOut: self.timedOut)
                if self.cancelled { self.status.stringValue = "Cancelled. Your source file is unchanged."; self.setChartVisible(false); self.showState(self.cancelled ? "Query cancelled" : "Query stopped", message: self.status.stringValue, symbol: "exclamationmark.circle"); self.capturePreview(); return }
                if self.timedOut { self.status.stringValue = "Stopped after the 30-second operation limit."; self.setChartVisible(false); self.showState(self.cancelled ? "Query cancelled" : "Query stopped", message: self.status.stringValue, symbol: "exclamationmark.circle"); self.capturePreview(); return }
                guard let response = response else { self.status.stringValue = "Worker stopped without a result (exit \(p.terminationStatus)). Try a smaller query."; self.setChartVisible(false); self.showState(self.cancelled ? "Query cancelled" : "Query stopped", message: self.status.stringValue, symbol: "exclamationmark.circle"); self.capturePreview(); return }
                guard response["ok"] as? Bool == true else { self.selectErrorLocation(response); self.status.stringValue = response["error"] as? String ?? "Query failed."; self.setChartVisible(false); self.showState(self.cancelled ? "Query cancelled" : "Query stopped", message: self.status.stringValue, symbol: "exclamationmark.circle"); self.capturePreview(); return }
                if response["action"] as? String == "profile", let sql = response["sql"] as? String { self.editor.string = sql }
                self.lastResponse = response; self.lastResponseData = data; self.exportButton.isEnabled = true; self.resultFilter.isEnabled = true
                self.rows = response["rows"] as? [[Any]] ?? []; self.columns = response["columns"] as? [[String: Any]] ?? []
                self.rebuildResultColumns()
                self.allRows = self.rows; self.table.sortDescriptors = []
                self.stateSpinner.stopAnimation(nil); self.statePanel.isHidden = true; self.resultScroll.isHidden = false
                self.table.reloadData()
                let fields = response["schema"] as? [[String: Any]] ?? []
                if let profile = response["profile"] as? [[String: Any]], !profile.isEmpty {
                    self.schema.applyProfile(profile)
                } else {
                    self.schema.applySchema(fields)
                }
                self.editor.schemaColumns = fields.compactMap { $0["name"] as? String }; self.editor.highlight()
                let datasetCount = (response["dataset_rows"] as? NSNumber)?.intValue ?? 0
                self.schema.setDataset(url: self.selectedURL, rows: datasetCount, columns: fields.count)
                self.updateBreadcrumbs()
                self.window.title = self.selectedURL?.lastPathComponent ?? "Quelyt"
                self.updateChart(response)
                self.resultSummary.stringValue = self.rows.count == 1 ? "1 row" : "\(self.rows.count.formatted()) rows"
                if self.rows.isEmpty { self.showState("No rows returned", message: "The query ran successfully. Try changing your filters or selecting a wider range.", symbol: "line.3.horizontal.decrease.circle") }
                let clipped = response["truncated"] as? Bool == true || response["cells_truncated"] as? Bool == true
                let elapsed = (response["elapsed_ms"] as? NSNumber)?.doubleValue ?? 0
                let chart = (response["chart"] as? [String: Any])?["kind"] as? String
                var message = "\(self.resultSummary.stringValue) · \(String(format: "%.1f", elapsed)) ms including import"
                if clipped { message += " · Result truncated to display limits" }
                if chart == "bar" || chart == "line" { message += " · \(chart!) chart from this query" }
                self.status.stringValue = message
                if ProcessInfo.processInfo.environment["QUELYT_BENCHMARK"] == "1" {
                    DispatchQueue.main.async {
                        self.window.displayIfNeeded()
                        FileHandle.standardOutput.write(Data("QUELYT_READY\n".utf8))
                    }
                }
                self.capturePreview()
            }
        }
    }
    // Integration harness invokes the same action methods; it does not synthesize OS input.
    func recordSmoke(_ response: [String: Any]?) {
        guard let flag = CommandLine.arguments.firstIndex(of: "--smoke-test"), CommandLine.arguments.count > flag + 1 else { return }
        let names = ["native_open_preview", "native_profile_action", "native_write_rejection", "native_cancel_action"]
        let passed: Bool
        switch smokeStage {
        case 0: passed = response?["ok"] as? Bool == true && (response?["rows"] as? [[Any]])?.count == 200
        case 1:
            let profile = response?["profile"] as? [[String: Any]] ?? []
            let count = (response?["dataset_rows"] as? NSNumber)?.intValue
            passed = response?["ok"] as? Bool == true && count == 1_000_000 && !profile.isEmpty
        case 2: passed = response?["ok"] as? Bool == false && response?["kind"] as? String == "PolicyError"
        default: passed = cancelled && process == nil
        }
        smokeResults.append(["case": names[min(smokeStage, 3)], "passed": passed])
        smokeStage += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            switch self.smokeStage {
            case 1: self.profile()
            case 2: self.editor.string = "DELETE FROM dataset"; self.runQuery()
            case 3:
                self.editor.string = "SELECT SUM(a.amount * b.amount) FROM dataset a CROSS JOIN dataset b"; self.runQuery()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.cancelQuery() }
            default:
                let output = CommandLine.arguments[flag + 1]
                if let data = try? JSONSerialization.data(withJSONObject: self.smokeResults, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: URL(fileURLWithPath: output)) }
                NSApp.terminate(nil)
            }
        }
    }
    func compareOutput() -> String? {
        guard let flag = CommandLine.arguments.firstIndex(of: "--compare"), CommandLine.arguments.count > flag + 1 else { return nil }
        return CommandLine.arguments[flag + 1]
    }
    func sampleStats(_ xs: [Double]) -> [String: Any] {
        let rounded = xs.map { ($0 * 100).rounded() / 100 }
        let sorted = rounded.sorted()
        let median = sorted.isEmpty ? 0 : sorted[sorted.count / 2]
        let p95 = sorted.isEmpty ? 0 : sorted[Int(Double(sorted.count - 1) * 0.95)]
        return ["runs_ms": rounded, "median_ms": median, "p95_ms": p95]
    }
    func showSyntheticGrid() {
        columns = [["name": "synthetic_id"], ["name": "region"], ["name": "amount"]]
        rows.removeAll(keepingCapacity: true)
        rows.reserveCapacity(100_000)
        for i in 0..<100_000 {
            let region: String = i % 3 == 0 ? "West" : "East"
            rows.append([String(i), region, String(i % 100)])
        }
        for col in table.tableColumns { table.removeTableColumn(col) }
        rebuildResultColumns()
        table.reloadData(); window.displayIfNeeded()
    }
    func finishCompare() {
        guard let output = compareOutput() else { return }
        let createStart = Date.timeIntervalSinceReferenceDate
        showSyntheticGrid()
        let createMs = (Date.timeIntervalSinceReferenceDate - createStart) * 1000
        var scroll: [Double] = []
        for index in 0..<120 {
            let started = Date.timeIntervalSinceReferenceDate
            table.scrollRowToVisible(min(index * 64, rows.count - 1))
            table.displayIfNeeded()
            scroll.append((Date.timeIntervalSinceReferenceDate - started) * 1000)
        }
        let editStart = Date.timeIntervalSinceReferenceDate
        editor.string = String(repeating: "SELECT region, SUM(amount) FROM dataset GROUP BY region;\n", count: 2000)
        window.displayIfNeeded()
        let editMs = (Date.timeIntervalSinceReferenceDate - editStart) * 1000
        editor.string = "SELECT region, SUM(amount) AS revenue\nFROM dataset\nGROUP BY region\nORDER BY region;"
        var stream: [Double] = []
        var last = Date.timeIntervalSinceReferenceDate
        for _ in 0..<120 {
            window.displayIfNeeded()
            let now = Date.timeIntervalSinceReferenceDate
            stream.append((now - last) * 1000)
            last = now
        }
        let metrics: [String: Any] = [
            "host": "native",
            "kind": "disposable framework probe",
            "query": ["preview": sampleStats(previewTimes), "aggregate": sampleStats(aggregateTimes)],
            "write_rejected": compareWriteRejected,
            "cancelled": compareCancelled,
            "synthetic_grid_create_ms": (createMs * 100).rounded() / 100,
            "synthetic_grid_scroll_frames": sampleStats(scroll),
            "live_table_rows": table.numberOfRows,
            "editor_112k_chars_ms": (editMs * 100).rounded() / 100,
            "stream_frame_intervals": sampleStats(stream),
            "stream_note": "Native stream samples are displayIfNeeded polling, not vsync requestAnimationFrame."
        ]
        if let data = try? JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: output))
        }
        NSApp.terminate(nil)
    }
    func recordCompare(_ response: [String: Any]?, roundTrip: Double) {
        guard compareOutput() != nil else { return }
        switch compareStage {
        case 0:
            previewTimes.append(roundTrip)
            if previewTimes.count < 5 {
                editor.string = "SELECT *\nFROM dataset\nLIMIT 200;"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.runQuery() }
            } else {
                compareStage = 1
                editor.string = "SELECT region, SUM(amount) AS revenue FROM dataset GROUP BY region ORDER BY region;"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.runQuery() }
            }
        case 1:
            let values = response?["rows"] as? [[Any]] ?? []
            let ok = response?["ok"] as? Bool == true && values.count == 2
            if ok { aggregateTimes.append(roundTrip) }
            if aggregateTimes.count < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.runQuery() }
            } else {
                compareStage = 2
                editor.string = "DELETE FROM dataset"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.runQuery() }
            }
        case 2:
            compareWriteRejected = response?["ok"] as? Bool == false && response?["kind"] as? String == "PolicyError"
            compareStage = 3
            editor.string = "SELECT SUM(a.amount * b.amount) FROM dataset a CROSS JOIN dataset b"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.runQuery()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.cancelQuery() }
            }
        default:
            compareCancelled = cancelled
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.finishCompare() }
        }
    }
    func updateChart(_ response: [String: Any]) {
        let kind = (response["chart"] as? [String: Any])?["kind"] as? String ?? "none"
        let values = response["values"] as? [[Any]] ?? []
        let labels = values.map { row -> String in
            guard let value = row.first else { return "" }
            return value is NSNull ? "" : String(describing: value)
        }
        let numbers = values.compactMap { row -> Double? in
            guard row.count > 1, let number = row[1] as? NSNumber else { return nil }
            return number.doubleValue
        }
        let visible = (kind == "bar" || kind == "line") && numbers.count == labels.count && numbers.count >= 2
        chartView.kind = visible ? kind : "none"
        chartView.labels = visible ? labels : []
        chartView.numbers = visible ? numbers : []
        chartToggle.isEnabled = visible
        setChartVisible(visible && chartToggle.state == .on)
        chartView.setAccessibilityElement(true); chartView.setAccessibilityRole(.image)
        chartView.setAccessibilityValue(zip(labels, numbers).map { "\($0): \($1)" }.joined(separator: "; "))
        chartView.setAccessibilityLabel(visible ? "\(kind) chart of the current query result" : "No chart")
        chartView.needsDisplay = true
    }
    func setChartVisible(_ visible: Bool) {
        chartView.isHidden = !visible
        chartHeight.constant = visible ? 125 : 0
        window?.contentView?.layoutSubtreeIfNeeded()
        chartView.needsDisplay = true
    }
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
    func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        guard let column = column, let index = Int(column.identifier.rawValue), row < rows.count, index < rows[row].count else { return nil }
        let reuse = NSUserInterfaceItemIdentifier("cell")
        let field = tableView.makeView(withIdentifier: reuse, owner: self) as? NSTextField ?? NSTextField(labelWithString: "")
        field.identifier = reuse; let value = rows[row][index]; field.stringValue = value is NSNull ? "NULL" : String(describing: value)
        field.font = .monospacedSystemFont(ofSize: 12, weight: .regular); field.textColor = value is NSNull ? QuelytTheme.faint : QuelytTheme.ink; field.lineBreakMode = .byTruncatingTail; field.toolTip = field.stringValue
        return field
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        copyItem?.isEnabled = process == nil && !table.selectedRowIndexes.isEmpty
    }
    func historyJSON(_ arguments: [String], input: Data? = nil) -> [String: Any]? {
        guard let p = makePythonProcess("history", extra: arguments) else { return nil }
        let stdin = Pipe(); let stdout = Pipe(); let stderr = Pipe()
        p.standardInput = stdin; p.standardOutput = stdout; p.standardError = stderr
        do { try p.run() } catch { return nil }
        if let input = input { stdin.fileHandleForWriting.write(input) }
        try? stdin.fileHandleForWriting.close()
        DispatchQueue.global().async { _ = stderr.fileHandleForReading.readDataToEndOfFile() }
        let data = stdout.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
    func reloadHistory() {
        let listed = historyJSON(["list"])
        historyPage.setTraces(listed?["traces"] as? [[String: Any]] ?? [])
        rebuildRecentMenu(listed?["sources"] as? [[String: Any]] ?? [])
    }
    func rebuildRecentMenu(_ sources: [[String: Any]]) {
        schema.setRecents(sources)
        recentMenu.removeAllItems()
        if sources.isEmpty {
            let empty = recentMenu.addItem(withTitle: "No recent datasets", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            return
        }
        for source in sources {
            guard let path = source["path"] as? String else { continue }
            let item = recentMenu.addItem(withTitle: source["name"] as? String ?? path, action: #selector(openRecent(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = path; item.toolTip = path
        }
    }
    func lastReadableSource() -> URL? {
        let listed = historyJSON(["list"])
        historyPage.setTraces(listed?["traces"] as? [[String: Any]] ?? [])
        rebuildRecentMenu(listed?["sources"] as? [[String: Any]] ?? [])
        guard let path = (listed?["sources"] as? [[String: Any]])?.first?["path"] as? String else { return nil }
        return FileManager.default.isReadableFile(atPath: path) ? URL(fileURLWithPath: path) : nil
    }
    func persistTrace(sql: String, action: String, response: [String: Any]?, cancelled: Bool, timedOut: Bool) {
        guard !skipHistory(), let url = selectedURL, !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var payload: [String: Any] = ["path": url.path, "sql": sql, "action": action]
        if cancelled { payload["ok"] = false; payload["error"] = "Cancelled"; payload["kind"] = "Cancelled" }
        else if timedOut { payload["ok"] = false; payload["error"] = "Stopped after the 30-second operation limit."; payload["kind"] = "Timeout" }
        else if let response = response {
            payload["ok"] = response["ok"] as? Bool ?? false
            payload["error"] = response["error"] as? String ?? NSNull()
            payload["kind"] = response["kind"] as? String ?? NSNull()
            payload["row_count"] = (response["rows"] as? [Any])?.count ?? 0
            payload["dataset_rows"] = response["dataset_rows"] ?? NSNull()
            payload["elapsed_ms"] = response["elapsed_ms"] ?? NSNull()
            payload["truncated"] = response["truncated"] as? Bool ?? false
            payload["chart_kind"] = (response["chart"] as? [String: Any])?["kind"] ?? "none"
        } else {
            payload["ok"] = false; payload["error"] = "Worker stopped without a result."
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        DispatchQueue.global(qos: .utility).async {
            _ = self.historyJSON(["record"], input: data)
            DispatchQueue.main.async { self.reloadHistory() }
        }
    }
    @objc func openRecent(_ sender: NSMenuItem) {
        guard process == nil, let path = sender.representedObject as? String else { return }
        openDataset(URL(fileURLWithPath: path))
    }
    @objc func rerunHistory() { historyPage.rerunSelectedTrace() }
    func runHistory(_ trace: [String: Any]) {
        guard process == nil, let sql = trace["sql"] as? String else { return }
        sidebar.selectDestination(.databases)
        editor.string = sql
        guard let path = trace["path"] as? String, FileManager.default.isReadableFile(atPath: path) else {
            status.stringValue = "This query’s dataset is unavailable. Open the source file before rerunning."; return
        }
        if selectedURL?.path != path { openDataset(URL(fileURLWithPath: path), sql: sql); return }
        runQuery()
    }
    @objc func deleteSelectedTrace() {
        guard !skipHistory(), let id = historyPage.selectedTrace()?["id"] else { return }
        DispatchQueue.global(qos: .utility).async {
            _ = self.historyJSON(["delete", String(describing: id)])
            DispatchQueue.main.async { self.reloadHistory() }
        }
    }
    @objc func clearHistory() {
        guard !skipHistory() else { return }
        let alert = NSAlert(); alert.messageText = "Clear local history?"
        alert.informativeText = "This removes saved SQL traces and recent datasets from this Mac. Source files are not changed."
        alert.addButton(withTitle: "Clear History"); alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        DispatchQueue.global(qos: .utility).async {
            _ = self.historyJSON(["clear"])
            DispatchQueue.main.async { self.reloadHistory() }
        }
    }
    func selectErrorLocation(_ response: [String: Any]) {
        guard let location = response["location"] as? [String: Int], let line = location["line"], let column = location["column"], line > 0, column > 0 else { return }
        let lines = editor.string.components(separatedBy: "\n")
        guard line <= lines.count else { return }
        let preceding = lines.prefix(line - 1).joined(separator: "\n")
        let prefix = String(lines[line - 1].unicodeScalars.prefix(column - 1))
        let offset = (preceding as NSString).length + (line > 1 ? 1 : 0) + (prefix as NSString).length
        let range = NSRange(location: min(offset, (editor.string as NSString).length), length: 0)
        window.makeFirstResponder(editor); editor.setSelectedRange(range); editor.scrollRangeToVisible(range)
    }
    func runUIChecks(output: String) {
        var checks: [[String: Any]] = []
        func check(_ name: String, _ passed: Bool) { checks.append(["case": name, "passed": passed]) }
        editor.string = "SELECT 'FROM' -- WHERE\nFROM dataset"; editor.setSelectedRange(NSRange(location: 4, length: 0)); editor.highlight()
        check("highlight_preserves_SQL_and_selection", editor.string == "SELECT 'FROM' -- WHERE\nFROM dataset" && editor.selectedRange().location == 4)
        editor.schemaColumns = ["revenue", "region name", "odd\"name"]
        editor.string = "reg"; var selected = 0
        let completions = editor.completions(forPartialWordRange: NSRange(location: 0, length: 3), indexOfSelectedItem: &selected) ?? []
        check("schema_completion_quotes_names", completions.contains("\"region name\""))
        allRows = [["East", "10"], ["West", "2"], ["East", "-1"]]; rows = allRows
        resultFilter.stringValue = "east"; filterResults(); check("filter_case_insensitive", rows.count == 2)
        resultFilter.stringValue = ""; filterResults(); table.sortDescriptors = [NSSortDescriptor(key: "1", ascending: true)]
        tableView(table, sortDescriptorsDidChange: []); check("numeric_sort", rows.map { $0[1] as! String } == ["-1", "2", "10"])
        editor.string = "SELECT *\nFROM dataset"; selectErrorLocation(["location": ["line": 2, "column": 3]])
        check("error_location", editor.selectedRange().location == 11)
        updateChart(["chart": ["kind": "bar"], "values": [["East", -10], ["West", 20]]])
        check("chart_accessible_values", chartView.accessibilityValue() as? String == "East: -10.0; West: 20.0")
        chartToggle.state = .off; toggleChart(); check("chart_toggle", chartView.isHidden)
        editor.string = "SELECT "; editor.setSelectedRange(NSRange(location: 7, length: 0))
        schema.applySchema([["name": "region name", "type": "VARCHAR"], ["name": "amount", "type": "DOUBLE"], ["name": "sale_date", "type": "DATE"]])
        schema.insertColumn(at: 0)
        check("column_insert_quotes_names", editor.string == "SELECT \"region name\"")
        schema.applyProfile([["name": "amount", "type": "DOUBLE", "null_pct": 0, "distinct_count": 3, "min": 1, "max": 9]])
        schema.applySchema([["name": "amount", "type": "DOUBLE"], ["name": "region", "type": "VARCHAR"]])
        let amountMeta = schema.visibleColumnRows().first { $0.name == "amount" }?.meta ?? ""
        check("profile_survives_later_query", amountMeta.contains("distinct 3") && amountMeta.contains("null 0"))
        schema.applySchema([["name": "revenue", "type": "DOUBLE"], ["name": "region", "type": "VARCHAR"]])
        schema.columnFilterString = "rev"
        check("column_filter", schema.visibleColumnRows().map(\.name) == ["revenue"])
        schema.columnFilterString = ""
        let extras = (1...8).map { ["name": "file\($0).csv", "path": "/tmp/file\($0).csv"] }
        schema.setRecents(extras)
        check("recents_capped", schema.recentNames() == ["file1.csv", "file2.csv", "file3.csv", "file4.csv", "file5.csv", "file6.csv", "file7.csv"])
        check("nav_default_databases", sidebar.selectedDestination == .databases && !databasesPage.isHidden)
        sidebar.selectDestination(.connections)
        check("nav_connections_unavailable", sidebar.selectedDestination == .connections && !connectionsPage.isHidden)
        sidebar.selectDestination(.ai)
        check("nav_ai_unavailable", sidebar.selectedDestination == .ai && !aiPage.isHidden)
        sidebar.selectDestination(.history)
        check("nav_history_selected", sidebar.selectedDestination == .history && !historyPage.view.isHidden)
        sidebar.selectDestination(.settings)
        check("nav_settings_local", sidebar.selectedDestination == .settings && !settingsPage.isHidden)
        sidebar.selectDestination(.databases)
        check("nav_databases_restored", sidebar.selectedDestination == .databases && !databasesPage.isHidden)
        let item = split.splitViewItems[0]
        let restored = item.isCollapsed
        item.isCollapsed = true
        let collapsed = item.isCollapsed
        item.isCollapsed = restored
        check("sidebar_collapse_restores", collapsed && item.isCollapsed == restored)
        check("palette_filters_run", palette.matchingTitles("run").contains("Run Query"))
        columns = [["name": "amount", "type": "DOUBLE"]]
        rebuildResultColumns()
        let headerLabel = table.tableColumns.first?.headerCell.accessibilityLabel() as? String ?? ""
        check("header_type_accessibility", headerLabel.contains("amount") && headerLabel.contains("DOUBLE"))
        allRows = [["East", "10"], ["West", "2"]]; rows = allRows
        table.reloadData(); table.deselectAll(nil)
        focusResults()
        check("keyboard_selects_first_result", table.selectedRow == 0)
        var reran = false
        historyPage.onRerunTrace = { _ in reran = true }
        sidebar.selectDestination(.history)
        historyPage.setTraces([["sql": "SELECT 1", "ok": true, "path": "/tmp/x.csv"]])
        historyPage.selectTrace(at: 0)
        historyPage.performHistoryReturn()
        check("history_return_reruns", reran)
        check("nav_accepts_first_responder", sidebar.navAcceptsFirstResponder)
        check("bundled_python_runtime", (bundledPython()?.path ?? "").contains("Contents/Resources/runtime"))
        window.setContentSize(NSSize(width: 980, height: 720))
        window.contentView?.layoutSubtreeIfNeeded()
        check("min_window_layout", window.frame.width >= 980 && dataSplit.bounds.height > 160)
        if let data = try? JSONSerialization.data(withJSONObject: checks, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: URL(fileURLWithPath: output)) }
        NSApp.terminate(nil)
    }
    @objc func exportResults() {
        guard process == nil, let data = lastResponseData else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "quelyt-results.json"
        panel.message = "Export the returned rows with types, SQL and truncation flags. Display limits apply."
        panel.beginSheetModal(for: window) { result in
            guard result == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
                self.status.stringValue = "Exported returned results to \(url.lastPathComponent)."
            } catch { self.status.stringValue = "Export failed: \(error.localizedDescription)" }
        }
    }
    @objc func saveQuery() {
        let sql = editor.string
        let panel = NSSavePanel(); panel.allowedContentTypes = [UTType(filenameExtension: "sql") ?? .plainText]; panel.nameFieldStringValue = "query.sql"
        panel.beginSheetModal(for: window) { result in
            guard result == .OK, let url = panel.url else { return }
            do { try sql.write(to: url, atomically: true, encoding: .utf8); self.status.stringValue = "Saved \(url.lastPathComponent)." }
            catch { self.status.stringValue = "Save failed: \(error.localizedDescription)" }
        }
    }
    @objc func loadQuery() {
        guard process == nil else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [UTType(filenameExtension: "sql") ?? .plainText]; panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { result in
            guard result == .OK, let url = panel.url else { return }
            do {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 1_048_576 else { self.status.stringValue = "Choose a SQL file smaller than 1 MiB."; return }
                self.editor.string = try String(contentsOf: url, encoding: .utf8)
                self.window.makeFirstResponder(self.editor); self.status.stringValue = "Query loaded. Review it, then run against the current dataset."
            } catch { self.status.stringValue = "Open query failed: \(error.localizedDescription)" }
        }
    }
    @objc func focusEditor() {
        sidebar.selectDestination(.databases)
        window.makeFirstResponder(editor)
    }
    @objc func focusResults() {
        sidebar.selectDestination(.databases)
        window.makeFirstResponder(table)
        if table.selectedRow < 0, table.numberOfRows > 0 {
            table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }
    @objc func focusHistory() {
        sidebar.selectDestination(.history)
        window.makeFirstResponder(historyPage.table)
    }
    @objc func showPalette() { palette.present(from: window, target: self) }
    @objc func copySelectedRows() { table.copy(nil) }
    @objc func goDatabases() { sidebar.selectDestination(.databases) }
    @objc func goHistory() { focusHistory() }
    @objc func goConnections() { sidebar.selectDestination(.connections) }
    @objc func goSettings() { sidebar.selectDestination(.settings) }
    @objc func goAI() { sidebar.selectDestination(.ai) }
    @objc func toggleSidebar(_ sender: Any?) { split.toggleSidebar(sender) }
    @objc func completeSQL() { window.makeFirstResponder(editor); editor.complete(nil) }
    @objc func toggleChart() { setChartVisible(chartToggle.state == .on && chartView.kind != "none") }
    @objc func toggleChartPalette() {
        chartToggle.state = chartToggle.state == .on ? .off : .on
        toggleChart()
    }
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if splitView === dataSplit { return 120 }
        if splitView === workspaceSplit { return 160 }
        return proposedMinimumPosition
    }
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if splitView === dataSplit { return splitView.bounds.height - 160 }
        if splitView === workspaceSplit { return max(splitView.bounds.width - 360, 160) }
        return proposedMaximumPosition
    }
    @objc func filterResults() {
        let needle = resultFilter.stringValue
        rows = needle.isEmpty ? allRows : allRows.filter { row in row.contains { String(describing: $0).localizedCaseInsensitiveContains(needle) } }
        table.reloadData(); table.deselectAll(nil); copyItem?.isEnabled = false
        resultSummary.stringValue = "\(rows.count) of \(allRows.count) returned rows"
    }
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard tableView === table, let descriptor = table.sortDescriptors.first, let key = descriptor.key, let index = Int(key) else { return }
        rows.sort { a, b in
            let left = String(describing: a[index]), right = String(describing: b[index])
            let order: ComparisonResult
            if let x = Decimal(string: left), let y = Decimal(string: right) { order = x < y ? .orderedAscending : x > y ? .orderedDescending : .orderedSame }
            else { order = left.localizedStandardCompare(right) }
            return descriptor.ascending ? order == .orderedAscending : order == .orderedDescending
        }
        table.reloadData(); table.deselectAll(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { if let p = process, p.isRunning { kill(p.processIdentifier, SIGKILL) } }
}
let app = NSApplication.shared
let delegate = QuelytApp(); app.delegate = delegate; app.setActivationPolicy(.regular); app.run()
