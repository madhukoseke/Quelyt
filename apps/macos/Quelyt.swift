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
    let profileButton = NSButton(title: "Count rows", target: nil, action: #selector(profile))
    var selectedURL: URL?
    var rows: [[Any]] = []
    var columns: [[String: Any]] = []
    var process: Process?
    var activeID: UUID?
    var cancelled = false
    var timedOut = false
    var smokeStage = 0
    var smokeResults: [[String: Any]] = []
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
        let resultTitle = NSTextField(labelWithString: "RESULTS"); resultTitle.font = .systemFont(ofSize: 11, weight: .medium); resultTitle.textColor = .secondaryLabelColor
        for view in [queryTitle, editorScroll, resultTitle, grid] { content.addArrangedSubview(view) }
        for view in [editorScroll, grid] { view.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true }
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
        editor.string = "SELECT COUNT(*) AS row_count\nFROM dataset;"; runQuery()
    }
    @objc func cancelQuery() {
        guard let process = process else { return }; cancelled = true; status.stringValue = "Cancelling…"; stop(process)
    }
    func stop(_ p: Process) {
        if p.isRunning { p.terminate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { if p.isRunning { kill(p.processIdentifier, SIGKILL) } }
    }
    @objc func runQuery() {
        guard process == nil, let url = selectedURL else { return }
        let sql = editor.string
        guard let input = try? JSONSerialization.data(withJSONObject: ["path": url.path, "sql": sql, "timeout_seconds": 15]) else { return }
        let p = Process(); p.executableURL = URL(fileURLWithPath: workspace + "/.venv/bin/python")
        p.arguments = ["-I", "-B", workspace + "/src/quelyt/worker.py"]
        p.environment = ["PATH": "/usr/bin:/bin", "PYTHONIOENCODING": "utf-8", "PYTHONDONTWRITEBYTECODE": "1"]
        let stdin = Pipe(); let stdout = Pipe(); let stderr = Pipe(); p.standardInput = stdin; p.standardOutput = stdout; p.standardError = stderr
        let id = UUID(); activeID = id; cancelled = false; timedOut = false
        rows = []; table.reloadData(); status.stringValue = "Reading selected data and running query…"; setBusy(true)
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
                self.recordSmoke(response)
                if self.cancelled { self.status.stringValue = "Cancelled. Your source file is unchanged."; return }
                if self.timedOut { self.status.stringValue = "Stopped after the 30-second operation limit."; return }
                guard let response = response else { self.status.stringValue = "Worker stopped without a result (exit \(p.terminationStatus)). Try a smaller query."; return }
                guard response["ok"] as? Bool == true else { self.status.stringValue = response["error"] as? String ?? "Query failed."; return }
                self.rows = response["rows"] as? [[Any]] ?? []; self.columns = response["columns"] as? [[String: Any]] ?? []
                for col in self.table.tableColumns { self.table.removeTableColumn(col) }
                for (index, column) in self.columns.enumerated() { let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(String(index))); col.title = column["name"] as? String ?? "Column"; col.width = 160; self.table.addTableColumn(col) }
                self.table.reloadData()
                let fields = response["schema"] as? [[String: String]] ?? []
                self.schema.string = "dataset\n\n" + fields.map { "\($0["name"] ?? "")\n\($0["type"] ?? "")\n" }.joined(separator: "\n")
                self.detail.stringValue = "\(response["dataset_rows"] ?? 0) rows · \(fields.count) columns · temporary snapshot"
                let clipped = response["truncated"] as? Bool == true || response["cells_truncated"] as? Bool == true
                let elapsed = (response["elapsed_ms"] as? NSNumber)?.doubleValue ?? 0
                self.status.stringValue = "\(self.rows.count) result rows · \(String(format: "%.1f", elapsed)) ms including import" + (clipped ? " · Result truncated to display limits" : "")
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
        let names = ["native_open_preview", "native_count_action", "native_write_rejection", "native_cancel_action"]
        let values = response?["rows"] as? [[String]] ?? []
        let passed: Bool
        switch smokeStage {
        case 0: passed = response?["ok"] as? Bool == true && (response?["rows"] as? [[Any]])?.count == 200
        case 1: passed = response?["ok"] as? Bool == true && values == [["1000000"]]
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
