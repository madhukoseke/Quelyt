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
        let high = max(numbers.max() ?? 1, low + 1)
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
                let height = max(CGFloat((value - low) / span) * plot.height, 1)
                let x = plot.minX + slot * CGFloat(index) + (slot - width) / 2
                teal.withAlphaComponent(0.88).setFill()
                NSBezierPath(roundedRect: NSRect(x: x, y: plot.maxY - height, width: width, height: height), xRadius: 2, yRadius: 2).fill()
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
    let editor = NSTextView()
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
    let workspace = Bundle.main.object(forInfoDictionaryKey: "QuelytWorkspace") as? String ?? FileManager.default.currentDirectoryPath

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .aqua)
        setupMenu()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1140, height: 760), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Quelyt"; window.minSize = NSSize(width: 800, height: 580)
        let root = DatasetDropView(); root.orientation = .vertical; root.alignment = .leading; root.spacing = 14
        root.wantsLayer = true; root.layer?.backgroundColor = NSColor(calibratedWhite: 0.97, alpha: 1).cgColor
        root.edgeInsets = NSEdgeInsets(top: 24, left: 26, bottom: 22, right: 26)
        root.registerForDraggedTypes([.fileURL]); root.openFile = { [weak self] url in self?.openDataset(url) }
        heading.font = .systemFont(ofSize: 27, weight: .semibold)
        detail.textColor = .secondaryLabelColor; detail.lineBreakMode = .byTruncatingMiddle
        let toolbar = NSStackView(); toolbar.orientation = .horizontal; toolbar.spacing = 10
        let openButton = NSButton(title: "Open dataset…", target: self, action: #selector(openPanel))
        openButton.bezelStyle = .rounded
        runButton.target = self; runButton.bezelStyle = .rounded; runButton.keyEquivalent = "\r"; runButton.keyEquivalentModifierMask = .command
        cancelButton.target = self; cancelButton.bezelStyle = .rounded
        profileButton.target = self; profileButton.bezelStyle = .rounded
        let badge = NSTextField(labelWithString: "READ MODE  ·  LOCAL"); badge.font = .monospacedSystemFont(ofSize: 11, weight: .medium); badge.textColor = .systemTeal
        for view in [openButton, runButton, cancelButton, profileButton, badge] { toolbar.addArrangedSubview(view) }
        let body = NSStackView(); body.orientation = .horizontal; body.alignment = .top; body.spacing = 20
        let sidebar = NSStackView(); sidebar.orientation = .vertical; sidebar.alignment = .leading; sidebar.spacing = 10
        let schemaTitle = NSTextField(labelWithString: "DATASET"); schemaTitle.font = .systemFont(ofSize: 11, weight: .semibold); schemaTitle.textColor = .secondaryLabelColor
        schema.frame = NSRect(x: 0, y: 0, width: 205, height: 500); schema.minSize = NSSize(width: 205, height: 0); schema.maxSize = NSSize(width: 205, height: CGFloat.greatestFiniteMagnitude); schema.isVerticallyResizable = true; schema.autoresizingMask = [.width]; schema.textContainer?.widthTracksTextView = true
        schema.isEditable = false; schema.font = .monospacedSystemFont(ofSize: 12, weight: .regular); schema.string = "No dataset selected"; schema.drawsBackground = false
        let schemaScroll = NSScrollView(); schemaScroll.documentView = schema; schemaScroll.hasVerticalScroller = true
        sidebar.addArrangedSubview(schemaTitle); sidebar.addArrangedSubview(schemaScroll)
        sidebar.widthAnchor.constraint(equalToConstant: 205).isActive = true
        schemaScroll.widthAnchor.constraint(equalTo: sidebar.widthAnchor).isActive = true
        let content = NSStackView(); content.orientation = .vertical; content.alignment = .leading; content.spacing = 12
        let queryTitle = NSTextField(labelWithString: "SQL   ·   ⌘ Return to run"); queryTitle.textColor = .secondaryLabelColor; queryTitle.font = .systemFont(ofSize: 11, weight: .medium)
        editor.font = .monospacedSystemFont(ofSize: 14, weight: .regular); editor.string = "SELECT *\nFROM dataset\nLIMIT 200;"
        editor.isRichText = false; editor.isAutomaticQuoteSubstitutionEnabled = false; editor.isAutomaticDashSubstitutionEnabled = false; editor.isAutomaticTextReplacementEnabled = false; editor.textContainerInset = NSSize(width: 12, height: 12)
        editor.setAccessibilityLabel("SQL query")
        let editorScroll = NSScrollView(); editorScroll.documentView = editor; editorScroll.hasVerticalScroller = true; editorScroll.borderType = .bezelBorder
        editor.minSize = NSSize(width: 0, height: 145); editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude); editor.isVerticallyResizable = true; editor.autoresizingMask = [.width]; editor.textContainer?.widthTracksTextView = true
        editorScroll.heightAnchor.constraint(equalToConstant: 145).isActive = true
        table.delegate = self; table.dataSource = self; table.allowsMultipleSelection = true
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
         table.rowHeight = 27; table.usesAlternatingRowBackgroundColors = true; table.columnAutoresizingStyle = .noColumnAutoresizing; table.setAccessibilityLabel("Query results")
        let grid = NSScrollView(); grid.documentView = table; grid.hasVerticalScroller = true; grid.hasHorizontalScroller = true; grid.borderType = .bezelBorder
        grid.setContentHuggingPriority(.defaultLow, for: .vertical)
        grid.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        grid.heightAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        let resultTitle = NSTextField(labelWithString: "RESULTS"); resultTitle.font = .systemFont(ofSize: 11, weight: .medium); resultTitle.textColor = .secondaryLabelColor
        chartHeight = chartView.heightAnchor.constraint(equalToConstant: 0)
        chartHeight.isActive = true
        chartView.setContentHuggingPriority(.required, for: .vertical)
        chartView.setContentCompressionResistancePriority(.required, for: .vertical)
        chartView.setAccessibilityRole(.image)
        for view in [queryTitle, editorScroll, resultTitle, grid, chartView] { content.addArrangedSubview(view) }
        for view in [editorScroll, grid, chartView] { view.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true }
        body.addArrangedSubview(sidebar); body.addArrangedSubview(content)
        content.widthAnchor.constraint(equalTo: body.widthAnchor, constant: -225).isActive = true
        content.heightAnchor.constraint(equalTo: body.heightAnchor).isActive = true; sidebar.heightAnchor.constraint(equalTo: body.heightAnchor).isActive = true
        status.font = .systemFont(ofSize: 12); status.textColor = .secondaryLabelColor
        for view in [heading, detail, toolbar, body, status] { root.addArrangedSubview(view) }
        for view in [detail, body, status] { view.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -52).isActive = true }
        window.contentView = root; window.center(); window.makeKeyAndOrderFront(nil); setBusy(false)
        NSApp.activate(ignoringOtherApps: true)
        if CommandLine.arguments.count > 1 { openDataset(URL(fileURLWithPath: CommandLine.arguments[1])) }
    }

    func setupMenu() {
        let main = NSMenu(); let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu(); appMenu.addItem(withTitle: "Quit Quelyt", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); appItem.submenu = appMenu
        let fileItem = NSMenuItem(); main.addItem(fileItem); let file = NSMenu(title: "File"); fileItem.submenu = file
        let open = file.addItem(withTitle: "Open dataset…", action: #selector(openPanel), keyEquivalent: "o"); open.target = self
        let editItem = NSMenuItem(); main.addItem(editItem); let edit = NSMenu(title: "Edit"); editItem.submenu = edit
        for (title, selector, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] { edit.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key) }
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
    func openDataset(_ url: URL) {
        guard process == nil else { return }
        guard ["csv", "parquet"].contains(url.pathExtension.lowercased()) else { status.stringValue = "Choose one CSV or Parquet file."; return }
        selectedURL = url; heading.stringValue = url.lastPathComponent
        detail.stringValue = "Temporary snapshot · source file stays unchanged"
        editor.string = "SELECT *\nFROM dataset\nLIMIT 200;"; schema.string = "Loading schema…"
        runQuery()
    }
    func setBusy(_ busy: Bool) {
        runButton.isEnabled = !busy && selectedURL != nil; profileButton.isEnabled = !busy && selectedURL != nil; cancelButton.isEnabled = busy; editor.isEditable = !busy
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
        rows = []; table.reloadData(); setChartVisible(false); chartView.kind = "none"
        workerStarted = Date.timeIntervalSinceReferenceDate
        status.stringValue = "Reading selected data and running query…"; setBusy(true)
        do { try p.run() } catch { status.stringValue = "Cannot start worker: \(error.localizedDescription). Run the setup commands in README."; setBusy(false); return }
        process = p
        stdin.fileHandleForWriting.write(input); try? stdin.fileHandleForWriting.close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self = self, self.activeID == id, p.isRunning else { return }; self.timedOut = true; self.stop(p)
        }
        // Drain stderr concurrently, so an error cannot fill a pipe and deadlock the worker.
        DispatchQueue.global().async { _ = stderr.fileHandleForReading.readDataToEndOfFile() }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let data = stdout.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
            let response = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            DispatchQueue.main.async {
                guard let self = self, self.activeID == id else { return }
                self.process = nil; self.activeID = nil; self.setBusy(false)
                let roundTrip = (Date.timeIntervalSinceReferenceDate - self.workerStarted) * 1000
                self.recordSmoke(response)
                self.recordCompare(response, roundTrip: roundTrip)
                if self.cancelled { self.status.stringValue = "Cancelled. Your source file is unchanged."; self.setChartVisible(false); return }
                if self.timedOut { self.status.stringValue = "Stopped after the 30-second operation limit."; self.setChartVisible(false); return }
                guard let response = response else { self.status.stringValue = "Worker stopped without a result (exit \(p.terminationStatus)). Try a smaller query."; self.setChartVisible(false); return }
                guard response["ok"] as? Bool == true else { self.status.stringValue = response["error"] as? String ?? "Query failed."; self.setChartVisible(false); return }
                if response["action"] as? String == "profile", let sql = response["sql"] as? String { self.editor.string = sql }
                self.rows = response["rows"] as? [[Any]] ?? []; self.columns = response["columns"] as? [[String: Any]] ?? []
                for col in self.table.tableColumns { self.table.removeTableColumn(col) }
                for (index, column) in self.columns.enumerated() { let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(String(index))); col.title = column["name"] as? String ?? "Column"; col.width = 160; self.table.addTableColumn(col) }
                self.table.reloadData()
                self.schema.string = self.schemaText(response)
                let fields = response["schema"] as? [[String: Any]] ?? []
                self.detail.stringValue = "\(response["dataset_rows"] ?? 0) rows · \(fields.count) columns · temporary snapshot"
                self.updateChart(response)
                let clipped = response["truncated"] as? Bool == true || response["cells_truncated"] as? Bool == true
                let elapsed = (response["elapsed_ms"] as? NSNumber)?.doubleValue ?? 0
                let chart = (response["chart"] as? [String: Any])?["kind"] as? String
                var message = "\(self.rows.count) result rows · \(String(format: "%.1f", elapsed)) ms including import"
                if clipped { message += " · Result truncated to display limits" }
                if chart == "bar" || chart == "line" { message += " · \(chart!) chart from this query" }
                self.status.stringValue = message
                if ProcessInfo.processInfo.environment["QUELYT_BENCHMARK"] == "1" {
                    DispatchQueue.main.async {
                        self.window.displayIfNeeded()
                        FileHandle.standardOutput.write(Data("QUELYT_READY\n".utf8))
                    }
                }
                // Developer-only render snapshot of our own view hierarchy, for layout QA.
                if let flag = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > flag + 1 {
                    let output = CommandLine.arguments[flag + 1]
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        self.window.layoutIfNeeded()
                        guard let view = self.window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                        view.cacheDisplay(in: view.bounds, to: bitmap)
                        if let png = bitmap.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: output)) }
                    }
                }
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
        setChartVisible(visible)
        chartView.setAccessibilityLabel(visible ? "\(kind) chart of the current query result" : "No chart")
        chartView.needsDisplay = true
    }
    func setChartVisible(_ visible: Bool) {
        chartHeight.constant = visible ? 168 : 0
        window?.contentView?.layoutSubtreeIfNeeded()
        chartView.needsDisplay = true
    }
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
    func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        guard let column = column, let index = Int(column.identifier.rawValue), row < rows.count, index < rows[row].count else { return nil }
        let reuse = NSUserInterfaceItemIdentifier("cell")
        let field = tableView.makeView(withIdentifier: reuse, owner: self) as? NSTextField ?? NSTextField(labelWithString: "")
        field.identifier = reuse; let value = rows[row][index]; field.stringValue = value is NSNull ? "NULL" : String(describing: value)
        field.font = .monospacedSystemFont(ofSize: 12, weight: .regular); field.lineBreakMode = .byTruncatingTail; field.toolTip = field.stringValue
        return field
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { if let p = process, p.isRunning { kill(p.processIdentifier, SIGKILL) } }
}
let app = NSApplication.shared
let delegate = QuelytApp(); app.delegate = delegate; app.setActivationPolicy(.regular); app.run()
