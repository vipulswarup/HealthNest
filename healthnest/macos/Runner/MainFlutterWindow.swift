import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    print("DEBUG: MainFlutterWindow.awakeFromNib called")
    
    let flutterViewController = FlutterViewController()
    let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1440, height: 900)
    let windowSize = CGSize(width: 1200, height: 900)
    let windowRect = NSRect(
      x: (screenSize.width - windowSize.width) / 2,
      y: (screenSize.height - windowSize.height) / 2,
      width: windowSize.width,
      height: windowSize.height
    )
    
    print("DEBUG: Setting window frame to \(windowRect)")
    self.setFrame(windowRect, display: true)
    self.contentViewController = flutterViewController
    self.title = "HealthNest"
    
    print("DEBUG: Window isReleasedWhenClosed = \(self.isReleasedWhenClosed)")
    print("DEBUG: Window isVisible = \(self.isVisible)")
    
    self.isReleasedWhenClosed = false
    
    // Force window to be visible
    self.makeKeyAndOrderFront(nil)
    self.orderFrontRegardless()
    
    print("DEBUG: After makeKeyAndOrderFront - isVisible = \(self.isVisible)")
    
    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
