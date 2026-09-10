import AppKit

final class SQLEditor: NSTextView {
    var schemaColumns: [String] = []
    private let keywords = "SELECT FROM WHERE GROUP BY ORDER ASC DESC LIMIT OFFSET AS AND OR NOT NULL IS IN LIKE BETWEEN DISTINCT HAVING JOIN LEFT RIGHT INNER OUTER ON CASE WHEN THEN ELSE END TRUE FALSE SUM COUNT AVG MIN MAX COALESCE CAST".components(separatedBy: " ")
    static func quotedIdentifier(_ name: String) -> String {
        "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    override var string: String {
        didSet { highlight() }
    }
    override func didChangeText() {
        super.didChangeText()
        highlight()
    }
    func insertIdentifier(_ name: String) {
        let quoted = Self.quotedIdentifier(name)
        let range = selectedRange()
        if shouldChangeText(in: range, replacementString: quoted) {
            replaceCharacters(in: range, with: quoted)
            didChangeText()
        }
    }
    func highlight() {
        guard let storage = textStorage else { return }
        let full = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.addAttributes([.foregroundColor: NSColor.labelColor, .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)], range: full)
        // One tokenizer protects quoted strings and comments from keyword highlighting.
        let pattern = "--[^\\n]*|/\\*[\\s\\S]*?\\*/|'(?:''|[^'])*'|\"(?:\"\"|[^\"])*\"|\\b[A-Za-z_][A-Za-z_0-9]*\\b|\\b[0-9]+(?:\\.[0-9]+)?\\b"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            for match in regex.matches(in: string, range: full) {
                let token = (string as NSString).substring(with: match.range)
                let color: NSColor
                if token.hasPrefix("--") || token.hasPrefix("/*") { color = .secondaryLabelColor }
                else if token.hasPrefix("'") { color = .systemBrown }
                else if keywords.contains(token.uppercased()) { color = NSColor(calibratedRed: 0.16, green: 0.43, blue: 0.37, alpha: 1) }
                else { continue }
                storage.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }
        storage.endEditing()
        typingAttributes = [.font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), .foregroundColor: NSColor.labelColor]
    }
    override func completions(forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String]? {
        let prefix = (string as NSString).substring(with: charRange)
        let columns = schemaColumns.map { Self.quotedIdentifier($0) }
        let candidates = Array(Set(keywords + ["dataset"] + columns)).sorted()
        index.pointee = 0
        return candidates.filter { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")).localizedLowercase.hasPrefix(prefix.localizedLowercase) }
    }
}
