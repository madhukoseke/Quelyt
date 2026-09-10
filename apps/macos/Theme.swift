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

    static let canvas = rgb(0x0a0d14)
    static let surface = rgb(0x11151f)
    static let muted = rgb(0x1a2030)
    static let input = rgb(0x2a3040)
    static let line = rgb(0x222734)
    static let lineStrong = rgb(0x333a49)
    static let ink = rgb(0xe7e9ee)
    static let inkMuted = rgb(0x9aa2b1)
    static let faint = rgb(0x69707e)
    static let brand = rgb(0x3b82f6)
    static let brandHover = rgb(0x60a5fa)
    static let brandDeep = rgb(0x1e3a8a)
    static let success = rgb(0x00bb7f)
    static let warn = rgb(0xf99c00)
    static let danger = rgb(0xff6568)
    static let keyword = brandHover
    static let string = success
    static let radius: CGFloat = 10
    static let radiusSm: CGFloat = 8
    static let row: CGFloat = 32
    static let hairline: CGFloat = 1

    static func applyChrome(to window: NSWindow) {
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = canvas
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .line
        window.toolbarStyle = .unified
    }

    static func hairlineLayer(_ view: NSView, radius: CGFloat = radiusSm) {
        view.wantsLayer = true
        view.layer?.cornerRadius = radius
        view.layer?.borderWidth = hairline
        view.layer?.borderColor = line.cgColor
        view.layer?.backgroundColor = canvas.cgColor
        view.layer?.masksToBounds = true
    }
}
