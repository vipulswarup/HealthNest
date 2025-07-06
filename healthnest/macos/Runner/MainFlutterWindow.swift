import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1440, height: 900)
    let windowSize = CGSize(width: 1200, height: 900)
    let windowRect = NSRect(
      x: (screenSize.width - windowSize.width) / 2,
      y: (screenSize.height - windowSize.height) / 2,
      width: windowSize.width,
      height: windowSize.height
    )
    self.setFrame(windowRect, display: true)
    self.contentViewController = flutterViewController

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
