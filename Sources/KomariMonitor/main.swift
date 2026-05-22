import AppKit
import Foundation

private let app = NSApplication.shared
private let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
