import AppKit

struct PaletteCommand {
    let title: String
    let subtitle: String
    let action: Selector
}

final class CommandPalette: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate, NSWindowDelegate {
    private let panel: NSPanel
    private let search = NSSearchField()
    private let table = NSTableView()
    private var all: [PaletteCommand] = []
    private var filtered: [PaletteCommand] = []
    private weak var target: AnyObject?

    override init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 340),
            styleMask: [.titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.title = "Command Palette"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.delegate = self
        QuelytTheme.applyChrome(to: panel)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = QuelytTheme.surface
        panel.isOpaque = false

        let root = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        QuelytTheme.cardLayer(root, radius: 12)
        search.placeholderString = "Filter commands"
        search.delegate = self
        search.sendsSearchStringImmediately = true
        search.sendsWholeSearchString = false
        search.target = self
        search.action = #selector(applyFilter)
        search.setAccessibilityLabel("Filter commands")
        search.translatesAutoresizingMaskIntoConstraints = false
        table.headerView = nil
        table.rowHeight = 34
        table.delegate = self
        table.dataSource = self
        table.backgroundColor = QuelytTheme.surface
        table.selectionHighlightStyle = .regular
        table.setAccessibilityLabel("Commands")
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("command"))
        column.width = 480
        table.addTableColumn(column)
        table.target = self
        table.doubleAction = #selector(runSelected)
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(search)
        root.addSubview(scroll)
        NSLayoutConstraint.activate([
            search.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            search.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            search.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -8),
            scroll.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 10),
            scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -10)
        ])
        panel.contentView = root
        all = Self.defaultCommands()
        filtered = all
    }

    static func defaultCommands() -> [PaletteCommand] {
        [
            PaletteCommand(title: "Open dataset", subtitle: "Choose a CSV or Parquet file", action: #selector(QuelytApp.openPanel)),
            PaletteCommand(title: "Run Query", subtitle: "⌘ Return", action: #selector(QuelytApp.runQuery)),
            PaletteCommand(title: "Cancel Query", subtitle: "Stop the worker", action: #selector(QuelytApp.cancelQuery)),
            PaletteCommand(title: "Profile Dataset", subtitle: "Column stats for the open file", action: #selector(QuelytApp.profile)),
            PaletteCommand(title: "Copy Rows", subtitle: "Selected results as TSV", action: #selector(QuelytApp.copySelectedRows)),
            PaletteCommand(title: "Export Returned Results", subtitle: "JSON of the executed query", action: #selector(QuelytApp.exportResults)),
            PaletteCommand(title: "Save Query", subtitle: "Write SQL to a file", action: #selector(QuelytApp.saveQuery)),
            PaletteCommand(title: "Open Query", subtitle: "Load a .sql file", action: #selector(QuelytApp.loadQuery)),
            PaletteCommand(title: "Complete SQL", subtitle: "Schema names at the caret", action: #selector(QuelytApp.completeSQL)),
            PaletteCommand(title: "Focus SQL Editor", subtitle: "⌘1", action: #selector(QuelytApp.focusEditor)),
            PaletteCommand(title: "Focus Results", subtitle: "⌘2", action: #selector(QuelytApp.focusResults)),
            PaletteCommand(title: "Focus History", subtitle: "⌘3", action: #selector(QuelytApp.focusHistory)),
            PaletteCommand(title: "Toggle Sidebar", subtitle: "⌃B", action: #selector(QuelytApp.toggleSidebar(_:))),
            PaletteCommand(title: "Toggle Chart", subtitle: "Show or hide the bound chart", action: #selector(QuelytApp.toggleChartPalette)),
            PaletteCommand(title: "Go to Databases", subtitle: "Connect or create a local DuckDB file", action: #selector(QuelytApp.goDatabases)),
            PaletteCommand(title: "Go to Datasets", subtitle: "Open a CSV or Parquet file", action: #selector(QuelytApp.goDatasets)),
            PaletteCommand(title: "Go to History", subtitle: "Saved SQL traces", action: #selector(QuelytApp.goHistory)),
            PaletteCommand(title: "Go to Connections", subtitle: "Not available in this build", action: #selector(QuelytApp.goConnections)),
            PaletteCommand(title: "Go to Settings", subtitle: "Local-only facts", action: #selector(QuelytApp.goSettings)),
            PaletteCommand(title: "Go to AI", subtitle: "Research-only; no model calls", action: #selector(QuelytApp.goAI))
        ]
    }

    func matchingTitles(_ query: String) -> [String] {
        Self.filter(Self.defaultCommands(), query: query).map(\.title)
    }

    static func filter(_ commands: [PaletteCommand], query: String) -> [PaletteCommand] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if needle.isEmpty { return commands }
        return commands.filter {
            $0.title.localizedCaseInsensitiveContains(needle) || $0.subtitle.localizedCaseInsensitiveContains(needle)
        }
    }

    func present(from window: NSWindow, target: AnyObject) {
        self.target = target
        all = Self.defaultCommands()
        search.stringValue = ""
        applyFilter()
        if panel.parent != window { window.addChildWindow(panel, ordered: .above) }
        let frame = window.frame
        let size = panel.frame.size
        let origin = NSPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height - 48)
        panel.setFrameOrigin(origin)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(search)
    }

    func dismiss() {
        panel.orderOut(nil)
        panel.parent?.removeChildWindow(panel)
    }

    @objc func applyFilter() {
        filtered = Self.filter(all, query: search.stringValue)
        table.reloadData()
        if !filtered.isEmpty {
            table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    @objc func runSelected() {
        let row = table.selectedRow
        guard row >= 0, row < filtered.count, let target = target else { return }
        let command = filtered[row]
        dismiss()
        _ = target.perform(command.action, with: nil)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filtered.count else { return nil }
        let command = filtered[row]
        let title = NSTextField(labelWithString: command.title)
        title.font = .systemFont(ofSize: 13, weight: .medium)
        title.textColor = QuelytTheme.ink
        let subtitle = NSTextField(labelWithString: command.subtitle)
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = QuelytTheme.inkMuted
        let stack = NSStackView(views: [title, subtitle])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        return stack
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            let next = min(table.selectedRow + 1, max(filtered.count - 1, 0))
            table.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
            table.scrollRowToVisible(next)
            return true
        }
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            let next = max(table.selectedRow - 1, 0)
            table.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
            table.scrollRowToVisible(next)
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            runSelected()
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            dismiss()
            return true
        }
        return false
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        dismiss()
        return false
    }
}
