import AppKit

final class InsetHeader: NSView {
    private let crumbs = NSStackView()
    private let rule = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = QuelytTheme.canvas.cgColor
        translatesAutoresizingMaskIntoConstraints = false
        crumbs.orientation = .horizontal
        crumbs.alignment = .centerY
        crumbs.spacing = 8
        crumbs.translatesAutoresizingMaskIntoConstraints = false
        rule.wantsLayer = true
        rule.layer?.backgroundColor = QuelytTheme.hairlineBorder.cgColor
        rule.translatesAutoresizingMaskIntoConstraints = false
        addSubview(crumbs)
        addSubview(rule)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: QuelytTheme.headerHeight),
            crumbs.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            crumbs.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            crumbs.centerYAnchor.constraint(equalTo: centerYAnchor),
            rule.leadingAnchor.constraint(equalTo: leadingAnchor),
            rule.trailingAnchor.constraint(equalTo: trailingAnchor),
            rule.bottomAnchor.constraint(equalTo: bottomAnchor),
            rule.heightAnchor.constraint(equalToConstant: QuelytTheme.hairline)
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setCrumbs(["Quelyt", "Databases"])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setCrumbs(_ items: [String]) {
        crumbs.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let labels = items.isEmpty ? ["Quelyt"] : items
        for (index, item) in labels.enumerated() {
            if index > 0 {
                let chevron = NSImageView()
                chevron.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
                chevron.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
                chevron.contentTintColor = QuelytTheme.faint
                chevron.translatesAutoresizingMaskIntoConstraints = false
                chevron.widthAnchor.constraint(equalToConstant: 10).isActive = true
                chevron.heightAnchor.constraint(equalToConstant: 12).isActive = true
                crumbs.addArrangedSubview(chevron)
            }
            let field = NSTextField(labelWithString: item)
            let last = index == labels.count - 1
            field.font = .systemFont(ofSize: 13, weight: last ? .medium : .regular)
            field.textColor = last ? QuelytTheme.ink : QuelytTheme.inkMuted
            field.lineBreakMode = .byTruncatingMiddle
            crumbs.addArrangedSubview(field)
        }
        setAccessibilityLabel(labels.joined(separator: " / "))
    }
}
