import AppKit
import UniformTypeIdentifiers
import Darwin

final class DatasetDropView: NSStackView {
    var openFile: ((URL) -> Void)?
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) ? .copy : []
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], urls.count == 1 else { return false }
        openFile?(urls[0]); return true
    }
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
        NSColor.white.setFill(); dirtyRect.fill()
        NSColor.separatorColor.setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)); border.lineWidth = 1; border.stroke()
        guard kind == "bar" || kind == "line", numbers.count >= 2, numbers.count == labels.count else { return }
        let plot = NSRect(x: 36, y: 28, width: max(bounds.width - 48, 8), height: max(bounds.height - 54, 8))
        let low = min(0, numbers.min() ?? 0)
        let high = max(0, max(numbers.max() ?? 1, low + 1))
        let span = high - low
        let count = CGFloat(numbers.count)
        NSColor.separatorColor.setStroke()
        let axes = NSBezierPath(); axes.lineWidth = 1
        axes.move(to: NSPoint(x: plot.minX, y: plot.maxY)); axes.line(to: NSPoint(x: plot.maxX, y: plot.maxY))
        axes.move(to: NSPoint(x: plot.minX, y: plot.minY)); axes.line(to: NSPoint(x: plot.minX, y: plot.maxY))
        axes.stroke()
        let teal = NSColor.systemTeal
        if kind == "bar" {
            let slot = plot.width / count
            let width = slot * 0.62
            for (index, value) in numbers.enumerated() {
                let zeroY = plot.maxY - CGFloat((0 - low) / span) * plot.height
                let valueY = plot.maxY - CGFloat((value - low) / span) * plot.height
                let height = max(abs(zeroY - valueY), 1)
                let x = plot.minX + slot * CGFloat(index) + (slot - width) / 2
                teal.withAlphaComponent(0.88).setFill()
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
            teal.setStroke(); line.stroke(); teal.setFill()
            for (index, value) in numbers.enumerated() {
                let x = plot.minX + plot.width * CGFloat(index) / max(count - 1, 1)
                let y = plot.maxY - CGFloat((value - low) / span) * plot.height
                NSBezierPath(ovalIn: NSRect(x: x - 3, y: y - 3, width: 6, height: 6)).fill()
            }
        }
        let caption: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.secondaryLabelColor]
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
        title.draw(at: NSPoint(x: plot.minX, y: 6), withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.secondaryLabelColor])
    }
}

final class QuelytApp: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate {
    var window: NSWindow!
    let editor = SQLEditor()
    let table = ResultsTableView()
    let heading = NSTextField(labelWithString: "Explore your data. Locally.")
    let detail = NSTextField(labelWithString: "Open or drop a CSV / Parquet file to begin.")
    let status = NSTextField(wrappingLabelWithString: "Your data stays on this Mac. No account. No network connection.")
    let schema = NSTextView()
    let runButton = NSButton(title: "Run query", target: nil, action: #selector(runQuery))
    let cancelButton = NSButton(title: "Cancel", target: nil, action: #selector(cancelQuery))
    let profileButton = NSButton(title: "Profile dataset", target: nil, action: #selector(profile))
    let chartView = ResultChartView()
    var chartHeight: NSLayoutConstraint!
    let copyButton = NSButton(title: "Copy rows", target: nil, action: nil)
    var lastResponse: [String: Any]?
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
    let historyTable = NSTableView()
    var traces: [[String: Any]] = []
    var recentMenu: NSMenu!
    var reloadingHistory = false
    let workspace = Bundle.main.object(forInfoDictionaryKey: "QuelytWorkspace") as? String ?? FileManager.default.currentDirectoryPath

    func skipHistory() -> Bool {
        compareOutput() != nil || CommandLine.arguments.contains("--smoke-test") || ProcessInfo.processInfo.environment["QUELYT_BENCHMARK"] == "1"
    }

    func label(_ text: String, size: CGFloat = 12, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
        let view = NSTextField(labelWithString: text)
        view.font = .systemFont(ofSize: size, weight: weight); view.textColor = color
        return view
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .aqua)
        setupMenu()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 790), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Quelyt"; window.minSize = NSSize(width: 980, height: 720)
        window.titlebarAppearsTransparent = true; window.backgroundColor = NSColor(calibratedWhite: 0.975, alpha: 1)
        let root = DatasetDropView(); root.orientation = .vertical; root.alignment = .leading; root.spacing = 15
        root.wantsLayer = true; root.layer?.backgroundColor = window.backgroundColor.cgColor
        root.edgeInsets = NSEdgeInsets(top: 20, left: 26, bottom: 18, right: 26)
        root.registerForDraggedTypes([.fileURL]); root.openFile = { [weak self] url in self?.openDataset(url) }
        let brand = label("QUELYT  /  LOCAL WORKSPACE", size: 10, weight: .semibold, color: .secondaryLabelColor)
        heading.stringValue = "A place to explore your data"; heading.font = .systemFont(ofSize: 25, weight: .semibold)
        detail.stringValue = "Open a dataset. Write a query. Follow the evidence."
        detail.font = .systemFont(ofSize: 12); detail.textColor = .secondaryLabelColor; detail.lineBreakMode = .byTruncatingMiddle
        let toolbar = NSStackView(); toolbar.orientation = .horizontal; toolbar.spacing = 9
        let openButton = NSButton(title: "Open dataset…", target: self, action: #selector(openPanel))
        openButton.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil); openButton.imagePosition = .imageLeading
        runButton.target = self; runButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil); runButton.imagePosition = .imageLeading
        runButton.keyEquivalent = "\r"; runButton.keyEquivalentModifierMask = .command
        runButton.bezelColor = NSColor(calibratedRed: 0.18, green: 0.42, blue: 0.37, alpha: 1)
        cancelButton.target = self; profileButton.target = self
        copyButton.target = table; copyButton.action = #selector(ResultsTableView.copy(_:)); copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil); copyButton.imagePosition = .imageLeading
        copyButton.toolTip = "Copy selected result rows with headers (⌘C)"
        for button in [openButton, runButton, cancelButton, profileButton, copyButton] { button.bezelStyle = .rounded; button.controlSize = .regular; toolbar.addArrangedSubview(button) }
        let flexible = NSView(); flexible.setContentHuggingPriority(.defaultLow, for: .horizontal); toolbar.addArrangedSubview(flexible)
        let badge = label("●  Local · Read only", size: 11, weight: .medium, color: NSColor(calibratedRed: 0.2, green: 0.43, blue: 0.38, alpha: 1)); toolbar.addArrangedSubview(badge)
        let divider = NSBox(); divider.boxType = .separator
        let body = NSStackView(); body.orientation = .horizontal; body.alignment = .top; body.spacing = 24
        let sidebar = NSStackView(); sidebar.orientation = .vertical; sidebar.alignment = .leading; sidebar.spacing = 14
        let schemaTitle = label("Columns", size: 12, weight: .semibold)
        schema.frame = NSRect(x: 0, y: 0, width: 198, height: 500); schema.minSize = NSSize(width: 198, height: 0); schema.maxSize = NSSize(width: 198, height: CGFloat.greatestFiniteMagnitude)
        schema.isVerticallyResizable = true; schema.autoresizingMask = [.width]; schema.textContainer?.widthTracksTextView = true; schema.textContainerInset = NSSize(width: 0, height: 0)
        schema.isEditable = false; schema.font = .systemFont(ofSize: 12); schema.string = "Your dataset’s columns\nwill appear here."; schema.textColor = .secondaryLabelColor; schema.drawsBackground = false
        let schemaScroll = NSScrollView(); schemaScroll.documentView = schema; schemaScroll.hasVerticalScroller = true; schemaScroll.drawsBackground = false
        let sidebarNote = label("One dataset at a time.\nYour source stays unchanged.", size: 10, color: .tertiaryLabelColor)
        sidebar.addArrangedSubview(schemaTitle); sidebar.addArrangedSubview(schemaScroll); sidebar.addArrangedSubview(label("Recent queries", size: 12, weight: .semibold))
        historyTable.delegate = self; historyTable.dataSource = self; historyTable.headerView = nil; historyTable.rowHeight = 27
        historyTable.target = self; historyTable.doubleAction = #selector(rerunHistory); historyTable.setAccessibilityLabel("Recent queries")
        let historyColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("history")); historyColumn.width = 190; historyTable.addTableColumn(historyColumn)
        let historyScroll = NSScrollView(); historyScroll.documentView = historyTable; historyScroll.hasVerticalScroller = true; historyScroll.drawsBackground = false
        sidebar.addArrangedSubview(historyScroll); historyScroll.widthAnchor.constraint(equalTo: sidebar.widthAnchor).isActive = true; historyScroll.heightAnchor.constraint(equalToConstant: 125).isActive = true
        sidebar.addArrangedSubview(sidebarNote)
        sidebar.widthAnchor.constraint(equalToConstant: 198).isActive = true
        schemaScroll.widthAnchor.constraint(equalTo: sidebar.widthAnchor).isActive = true
        let content = NSStackView(); content.orientation = .vertical; content.alignment = .leading; content.spacing = 10
        let queryTitle = label("Query", size: 12, weight: .semibold)
        let queryHint = label("SQL · ⌘ Return to run · Esc to complete", size: 10, color: .secondaryLabelColor)
        let queryHeader = NSStackView(views: [queryTitle, queryHint]); queryHeader.spacing = 12
        editor.font = .monospacedSystemFont(ofSize: 13, weight: .regular); editor.string = "-- Open a CSV or Parquet file to start.\n-- Your table will be available as dataset."
        editor.isRichText = false; editor.allowsUndo = true; editor.isAutomaticQuoteSubstitutionEnabled = false; editor.isAutomaticDashSubstitutionEnabled = false; editor.isAutomaticTextReplacementEnabled = false
        editor.textContainerInset = NSSize(width: 15, height: 14); editor.setAccessibilityLabel("SQL query")
        let editorScroll = NSScrollView(); editorScroll.documentView = editor; editorScroll.hasVerticalScroller = true
        editorScroll.wantsLayer = true; editorScroll.layer?.cornerRadius = 7; editorScroll.layer?.borderWidth = 1; editorScroll.layer?.borderColor = NSColor(calibratedWhite: 0.87, alpha: 1).cgColor; editorScroll.layer?.masksToBounds = true
        editor.minSize = NSSize(width: 0, height: 160); editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude); editor.isVerticallyResizable = true; editor.autoresizingMask = [.width]; editor.textContainer?.widthTracksTextView = true
        editorScroll.heightAnchor.constraint(equalToConstant: 165).isActive = true
        table.delegate = self; table.dataSource = self; table.allowsMultipleSelection = true; table.rowHeight = 29; table.usesAlternatingRowBackgroundColors = true; table.columnAutoresizingStyle = .noColumnAutoresizing; table.setAccessibilityLabel("Query results")
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
        resultContainer.wantsLayer = true; resultContainer.layer?.backgroundColor = NSColor.white.cgColor; resultContainer.layer?.cornerRadius = 7; resultContainer.layer?.borderWidth = 1; resultContainer.layer?.borderColor = NSColor(calibratedWhite: 0.87, alpha: 1).cgColor; resultContainer.layer?.masksToBounds = true
        resultContainer.addSubview(grid); grid.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([grid.leadingAnchor.constraint(equalTo: resultContainer.leadingAnchor),grid.trailingAnchor.constraint(equalTo: resultContainer.trailingAnchor),grid.topAnchor.constraint(equalTo: resultContainer.topAnchor),grid.bottomAnchor.constraint(equalTo: resultContainer.bottomAnchor)])
        statePanel.orientation = .vertical; statePanel.alignment = .centerX; statePanel.spacing = 12; statePanel.translatesAutoresizingMaskIntoConstraints = false
        stateIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 27, weight: .light); stateIcon.contentTintColor = NSColor(calibratedRed: 0.33, green: 0.54, blue: 0.49, alpha: 1)
        stateTitle.font = .systemFont(ofSize: 18, weight: .medium); stateDescription.font = .systemFont(ofSize: 12); stateDescription.textColor = .secondaryLabelColor; stateDescription.alignment = .center; stateDescription.maximumNumberOfLines = 7
        stateOpenButton.target = self; stateOpenButton.action = #selector(openPanel); stateOpenButton.bezelStyle = .rounded
        stateSpinner.style = .spinning; stateSpinner.controlSize = .small; stateSpinner.isDisplayedWhenStopped = false
        for view in [stateIcon,stateSpinner,stateTitle,stateDescription,stateOpenButton] { statePanel.addArrangedSubview(view) }
        stateDescription.widthAnchor.constraint(equalToConstant: 350).isActive = true
        resultContainer.addSubview(statePanel)
        NSLayoutConstraint.activate([statePanel.centerXAnchor.constraint(equalTo: resultContainer.centerXAnchor),statePanel.centerYAnchor.constraint(equalTo: resultContainer.centerYAnchor)])
        resultSummary.font = .systemFont(ofSize: 10); resultSummary.textColor = .secondaryLabelColor
        resultFilter.placeholderString = "Filter returned rows"; resultFilter.target = self; resultFilter.action = #selector(filterResults); resultFilter.sendsSearchStringImmediately = true; resultFilter.setAccessibilityLabel("Filter returned results")
        resultFilter.widthAnchor.constraint(equalToConstant: 170).isActive = true
        chartToggle.target = self; chartToggle.action = #selector(toggleChart); chartToggle.state = .on; chartToggle.isEnabled = false
        exportButton.target = self; exportButton.bezelStyle = .rounded; exportButton.isEnabled = false
        let resultHeader = NSStackView(views: [label("Results", size: 12, weight: .semibold), resultSummary, resultFilter, chartToggle, exportButton]); resultHeader.spacing = 8
        chartHeight = chartView.heightAnchor.constraint(equalToConstant: 0); chartHeight.isActive = true
        chartView.isHidden = true
        for view in [queryHeader, editorScroll, resultHeader, resultContainer, chartView] { content.addArrangedSubview(view) }
        for view in [editorScroll, resultContainer, chartView] { view.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true }
        body.addArrangedSubview(sidebar); body.addArrangedSubview(content)
        content.widthAnchor.constraint(equalTo: body.widthAnchor, constant: -222).isActive = true
        content.heightAnchor.constraint(equalTo: body.heightAnchor).isActive = true; sidebar.heightAnchor.constraint(equalTo: body.heightAnchor).isActive = true
        status.font = .systemFont(ofSize: 11); status.textColor = .secondaryLabelColor; status.stringValue = "Local by default. No account or cloud connection required."
        for view in [brand, heading, detail, toolbar, divider, body, status] { root.addArrangedSubview(view) }
        for view in [detail, toolbar, divider, body, status] { view.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -52).isActive = true }
        window.contentView = root; window.center(); window.makeKeyAndOrderFront(nil); setBusy(false)
        showState("Open a dataset", message: "Choose a CSV or Parquet file, or drop one onto the workspace. Your data stays on this Mac.", symbol: "tablecells", canOpen: true)
        NSApp.activate(ignoringOtherApps: true); window.makeFirstResponder(openButton)
        if CommandLine.arguments.count > 1 && !CommandLine.arguments[1].hasPrefix("--") { openDataset(URL(fileURLWithPath: CommandLine.arguments[1])) }
        if !skipHistory() {
            reloadHistory()
            if selectedURL == nil, !CommandLine.arguments.contains("--snapshot"), let last = lastReadableSource() { openDataset(last) }
        }
        capturePreview()
    }
    func showState(_ title: String, message: String, symbol: String, canOpen: Bool = false, loading: Bool = false) {
        resultScroll.isHidden = true; statePanel.isHidden = false; stateTitle.stringValue = title; stateDescription.stringValue = message
        stateIcon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil); stateIcon.isHidden = loading
        stateOpenButton.isHidden = !canOpen
        stateSpinner.isHidden = !loading
        if loading { stateSpinner.startAnimation(nil) } else { stateSpinner.stopAnimation(nil) }
    }
    func showSchema(_ fields: [[String: String]]) {
        let text = NSMutableAttributedString()
        for field in fields {
            text.append(NSAttributedString(string: (field["name"] ?? "") + "\n", attributes: [.font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.labelColor]))
            text.append(NSAttributedString(string: (field["type"] ?? "") + "\n\n", attributes: [.font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular), .foregroundColor: NSColor.secondaryLabelColor]))
        }
        schema.textStorage?.setAttributedString(text)
    }
    func capturePreview() {
        guard let flag = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > flag + 1 else { return }
        let output = CommandLine.arguments[flag + 1]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard let view = self.window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            if let png = bitmap.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: output)) }
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
        for (title, action, key) in [("Focus SQL Editor", #selector(focusEditor), "1"), ("Focus Results", #selector(focusResults), "2"), ("Focus History", #selector(focusHistory), "3"), ("Complete SQL", #selector(completeSQL), ""), ("Run Selected History Query", #selector(rerunHistory), "")] { let item = queryMenu.addItem(withTitle: title, action: action, keyEquivalent: key); item.target = self }
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
        selectedURL = url; heading.stringValue = url.lastPathComponent
        detail.stringValue = "Temporary snapshot · source file stays unchanged"
        editor.string = sql ?? "SELECT *\nFROM dataset\nLIMIT 200;"; schema.string = "Loading schema…"
        runQuery()
    }
    func setBusy(_ busy: Bool) {
        runButton.isEnabled = !busy && selectedURL != nil; profileButton.isEnabled = !busy && selectedURL != nil; cancelButton.isEnabled = busy; editor.isEditable = !busy; copyButton.isEnabled = !busy && !table.selectedRowIndexes.isEmpty
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
    func startWorker(_ body: [String: Any]) {
        guard process == nil, selectedURL != nil else { return }
        guard let input = try? JSONSerialization.data(withJSONObject: body) else { return }
        let p = Process(); p.executableURL = URL(fileURLWithPath: workspace + "/.venv/bin/python")
        p.arguments = ["-I", "-B", workspace + "/src/quelyt/worker.py"]
        p.environment = ["PATH": "/usr/bin:/bin", "PYTHONIOENCODING": "utf-8", "PYTHONDONTWRITEBYTECODE": "1"]
        let stdin = Pipe(); let stdout = Pipe(); let stderr = Pipe(); p.standardInput = stdin; p.standardOutput = stdout; p.standardError = stderr
        let id = UUID(); activeID = id; cancelled = false; timedOut = false
        lastResponse = nil; allRows = []; resultFilter.stringValue = ""; resultFilter.isEnabled = false; exportButton.isEnabled = false; chartToggle.isEnabled = false
        rows = []; table.reloadData(); setChartVisible(false); chartView.kind = "none"
        resultSummary.stringValue = ""
        showState(openingDataset ? "Opening dataset…" : "Running query…", message: "Working locally. You can cancel at any time.", symbol: "", loading: true)
        openingDataset = false
        workerStarted = Date.timeIntervalSinceReferenceDate
        status.stringValue = "Reading selected data and running query…"; setBusy(true)
        do { try p.run() } catch { status.stringValue = "Cannot start worker: \(error.localizedDescription). Run the setup commands in README."; setBusy(false); showState("Worker unavailable", message: "The local query worker could not start. See the status message below.", symbol: "exclamationmark.circle"); return }
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
                guard response["ok"] as? Bool == true else { self.status.stringValue = response["error"] as? String ?? "Query failed."; self.setChartVisible(false); self.showState(self.cancelled ? "Query cancelled" : "Query stopped", message: self.status.stringValue, symbol: "exclamationmark.circle"); self.capturePreview(); return }
                if response["action"] as? String == "profile", let sql = response["sql"] as? String { self.editor.string = sql }
                self.lastResponse = response; self.exportButton.isEnabled = true; self.resultFilter.isEnabled = true
                self.rows = response["rows"] as? [[Any]] ?? []; self.columns = response["columns"] as? [[String: Any]] ?? []
                for col in self.table.tableColumns { self.table.removeTableColumn(col) }
                for (index, column) in self.columns.enumerated() { let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(String(index))); col.title = column["name"] as? String ?? "Column"; col.width = 160; col.sortDescriptorPrototype = NSSortDescriptor(key: String(index), ascending: true); self.table.addTableColumn(col) }
                self.allRows = self.rows; self.table.sortDescriptors = []
                self.stateSpinner.stopAnimation(nil); self.statePanel.isHidden = true; self.resultScroll.isHidden = false
                self.table.reloadData()
                self.schema.string = self.schemaText(response)
                if response["profile"] == nil { self.showSchema(response["schema"] as? [[String: String]] ?? []) }
                let fields = response["schema"] as? [[String: Any]] ?? []
                self.editor.schemaColumns = fields.compactMap { $0["name"] as? String }; self.editor.highlight()
                let datasetCount = (response["dataset_rows"] as? NSNumber)?.intValue ?? 0
                self.detail.stringValue = "\(datasetCount.formatted()) rows · \(fields.count) columns · source unchanged"
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
        for (index, column) in columns.enumerated() {
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(String(index)))
            col.title = column["name"] as? String ?? "Column"; col.width = 160; table.addTableColumn(col)
        }
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
    func schemaText(_ response: [String: Any]) -> String {
        if let profile = response["profile"] as? [[String: Any]], !profile.isEmpty {
            return "dataset\n\n" + profile.map { column in
                let name = column["name"] as? String ?? ""
                let type = column["type"] as? String ?? ""
                let nullPct = column["null_pct"] as? NSNumber ?? 0
                let distinct = column["distinct_count"] as? NSNumber ?? 0
                var lines = ["\(name)", "\(type)", "null \(nullPct)% · distinct \(distinct)"]
                var range: [String] = []
                if let min = column["min"], !(min is NSNull) { range.append("min \(min)") }
                if let max = column["max"], !(max is NSNull) { range.append("max \(max)") }
                if !range.isEmpty { lines.append(range.joined(separator: " · ")) }
                return lines.joined(separator: "\n")
            }.joined(separator: "\n\n")
        }
        let fields = response["schema"] as? [[String: Any]] ?? []
        return "dataset\n\n" + fields.map { "\($0["name"] as? String ?? "")\n\($0["type"] as? String ?? "")\n" }.joined(separator: "\n")
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
    func numberOfRows(in tableView: NSTableView) -> Int { tableView === historyTable ? traces.count : rows.count }
    func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        if tableView === historyTable {
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
        guard let column = column, let index = Int(column.identifier.rawValue), row < rows.count, index < rows[row].count else { return nil }
        let reuse = NSUserInterfaceItemIdentifier("cell")
        let field = tableView.makeView(withIdentifier: reuse, owner: self) as? NSTextField ?? NSTextField(labelWithString: "")
        field.identifier = reuse; let value = rows[row][index]; field.stringValue = value is NSNull ? "NULL" : String(describing: value)
        field.font = .monospacedSystemFont(ofSize: 12, weight: .regular); field.lineBreakMode = .byTruncatingTail; field.toolTip = field.stringValue
        return field
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        copyButton.isEnabled = process == nil && !table.selectedRowIndexes.isEmpty
        guard notification.object as? NSTableView === historyTable, !reloadingHistory, process == nil else { return }
        let row = historyTable.selectedRow
        guard row >= 0, row < traces.count, let sql = traces[row]["sql"] as? String else { return }
        editor.string = sql
        if let path = traces[row]["path"] as? String, selectedURL?.path != path, ["csv", "parquet"].contains(URL(fileURLWithPath: path).pathExtension.lowercased()) {
            status.stringValue = "History SQL loaded. Open that dataset to run it."
        }
    }
    func historyJSON(_ arguments: [String], input: Data? = nil) -> [String: Any]? {
        let p = Process(); p.executableURL = URL(fileURLWithPath: workspace + "/.venv/bin/python")
        p.arguments = ["-I", "-B", workspace + "/src/quelyt/history.py"] + arguments
        p.environment = ["PATH": "/usr/bin:/bin", "PYTHONIOENCODING": "utf-8", "PYTHONDONTWRITEBYTECODE": "1"]
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
        reloadingHistory = true
        let listed = historyJSON(["list"])
        traces = listed?["traces"] as? [[String: Any]] ?? []
        historyTable.reloadData(); historyTable.deselectAll(nil)
        reloadingHistory = false
        rebuildRecentMenu(listed?["sources"] as? [[String: Any]] ?? [])
    }
    func rebuildRecentMenu(_ sources: [[String: Any]]) {
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
        traces = listed?["traces"] as? [[String: Any]] ?? []
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
    @objc func rerunHistory() {
        let row = historyTable.clickedRow >= 0 ? historyTable.clickedRow : historyTable.selectedRow
        guard process == nil, row >= 0, row < traces.count, let sql = traces[row]["sql"] as? String else { return }
        editor.string = sql
        guard let path = traces[row]["path"] as? String, FileManager.default.isReadableFile(atPath: path) else {
            status.stringValue = "This query’s dataset is unavailable. Open the source file before rerunning."; return
        }
        if selectedURL?.path != path { openDataset(URL(fileURLWithPath: path), sql: sql); return }
        runQuery()
    }
    @objc func deleteSelectedTrace() {
        let row = historyTable.selectedRow
        guard !skipHistory(), row >= 0, row < traces.count, let id = traces[row]["id"] else { return }
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
    @objc func exportResults() {
        guard process == nil, let response = lastResponse else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "quelyt-results.json"
        panel.message = "Export the returned rows with types, SQL and truncation flags. Display limits apply."
        panel.beginSheetModal(for: window) { result in
            guard result == .OK, let url = panel.url else { return }
            do {
                let data = try JSONSerialization.data(withJSONObject: response, options: [.prettyPrinted, .sortedKeys])
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
    @objc func focusEditor() { window.makeFirstResponder(editor) }
    @objc func focusResults() { window.makeFirstResponder(table) }
    @objc func focusHistory() { window.makeFirstResponder(historyTable) }
    @objc func completeSQL() { window.makeFirstResponder(editor); editor.complete(nil) }
    @objc func toggleChart() { setChartVisible(chartToggle.state == .on && chartView.kind != "none") }
    @objc func filterResults() {
        let needle = resultFilter.stringValue
        rows = needle.isEmpty ? allRows : allRows.filter { row in row.contains { String(describing: $0).localizedCaseInsensitiveContains(needle) } }
        table.reloadData(); table.deselectAll(nil); copyButton.isEnabled = false
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
