import AppKit

enum QuelytTheme {
    static func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(
            calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha
        )
    }

    static let canvas = rgb(0x111111)
    static let surface = rgb(0x212121)
    static let muted = rgb(0x343434)
    static let inputFill = rgb(0xffffff, alpha: 0.15)
    static let hairlineBorder = rgb(0xffffff, alpha: 0.10)
    static let line = hairlineBorder
    static let lineStrong = rgb(0xffffff, alpha: 0.18)
    static let ink = rgb(0xfafafa)
    static let inkMuted = rgb(0xa1a1a1)
    static let faint = rgb(0x737373)
    static let primary = rgb(0xe5e5e5)
    static let primaryInk = rgb(0x212121)
    static let accent = rgb(0x6d5cff)
    static let brand = accent
    static let success = rgb(0x2db88a)
    static let warn = rgb(0xe89a3c)
    static let danger = rgb(0xf07171)
    static let chart = rgb(0x2684e8)
    static let keyword = accent
    static let string = success
    static let radius: CGFloat = 10
    static let radiusSm: CGFloat = 8
    static let row: CGFloat = 32
    static let hairline: CGFloat = 1
    static let headerHeight: CGFloat = 48
    static let sidebarDefault: CGFloat = 240
    static let sidebarCompact: CGFloat = 56

    static func applyChrome(to window: NSWindow) {
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = canvas
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .line
        window.toolbarStyle = .unified
    }

    static func cardLayer(_ view: NSView, radius: CGFloat = radius) {
        view.wantsLayer = true
        view.layer?.cornerRadius = radius
        view.layer?.borderWidth = hairline
        view.layer?.borderColor = hairlineBorder.cgColor
        view.layer?.backgroundColor = surface.cgColor
        view.layer?.masksToBounds = true
    }

    static func hairlineLayer(_ view: NSView, radius: CGFloat = radiusSm) {
        cardLayer(view, radius: radius)
    }

    static func sectionLabel(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 11, weight: .medium)
        field.textColor = faint
        return field
    }
}
