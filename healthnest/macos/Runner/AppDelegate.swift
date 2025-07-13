import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    print("DEBUG: AppDelegate.applicationDidFinishLaunching called")
    super.applicationDidFinishLaunching(notification)
    
    // Force app activation
    NSApp.activate(ignoringOtherApps: true)
    
    // Ensure the main window is visible
    if let mainWindow = NSApp.mainWindow {
      print("DEBUG: Main window found, making key and front")
      mainWindow.makeKeyAndOrderFront(nil)
      mainWindow.orderFrontRegardless()
    } else {
      print("DEBUG: No main window found")
    }
    
    // Force app to front
    NSApp.arrangeInFront(nil)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
