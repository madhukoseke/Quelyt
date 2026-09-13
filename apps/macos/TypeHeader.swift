import AppKit

enum ColumnTypeGlyph {
    static func symbol(for duckdbType: String) -> String {
        let text = duckdbType.uppercased()
        if text.contains("BOOL") { return "switch.2" }
        if text.contains("DATE") || text.contains("TIME") { return "calendar" }
        if text.contains("INTERVAL") { return "questionmark" }
        let numeric = ["INT", "DOUBLE", "FLOAT", "DECIMAL", "NUMERIC", "REAL", "HUGEINT"]
        if numeric.contains(where: { text.contains($0) }) { return "number" }
        if text.contains("CHAR") || text.contains("TEXT") || text.contains("STRING") || text.contains("JSON") || text.contains("UUID") {
            return "textformat"
        }
        return "questionmark"
    }
}

final class TypedHeaderCell: NSTableHeaderCell {
    var typeName = ""
    var symbolName = "questionmark"

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        QuelytTheme.surface.setFill()
        cellFrame.fill()
        QuelytTheme.line.setStroke()
        let edge = NSBezierPath()
        edge.lineWidth = 1
        edge.move(to: NSPoint(x: cellFrame.maxX - 0.5, y: cellFrame.minY))
        edge.line(to: NSPoint(x: cellFrame.maxX - 0.5, y: cellFrame.maxY))
        edge.move(to: NSPoint(x: cellFrame.minX, y: cellFrame.minY + 0.5))
        edge.line(to: NSPoint(x: cellFrame.maxX, y: cellFrame.minY + 0.5))
        edge.stroke()
        drawInterior(withFrame: cellFrame, in: controlView)
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let inset = cellFrame.insetBy(dx: 6, dy: 0)
        var textMinX = inset.minX
        if let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
                .applying(NSImage.SymbolConfiguration(paletteColors: [QuelytTheme.inkMuted]))
            if let image = base.withSymbolConfiguration(config) {
                let imageRect = NSRect(x: inset.minX, y: inset.midY - 6, width: 12, height: 12)
                image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1)
                textMinX = inset.minX + 16
            }
        }
        let textRect = NSRect(x: textMinX, y: inset.minY, width: max(inset.maxX - textMinX, 0), height: inset.height)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: QuelytTheme.ink
        ]
        (stringValue as NSString).draw(in: textRect, withAttributes: attrs)
    }

    override func accessibilityLabel() -> String? {
        typeName.isEmpty ? stringValue : "\(stringValue), \(typeName)"
    }
}
