import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    AuthLinkBridge.shared.attach(to: flutterViewController)
    FolderCheckBridge.shared.attach(to: flutterViewController)

    super.awakeFromNib()
  }
}

enum AuthLinkBridge {
  static let shared = AuthLinkBridgeImpl()
}

final class AuthLinkBridgeImpl {
  private var channel: FlutterMethodChannel?

  func attach(to controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "sanovault/links",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "openSafari",
         let urlString = call.arguments as? String,
         let url = URL(string: urlString) {
        let configuration = NSWorkspace.OpenConfiguration()
        if let safari = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
          NSWorkspace.shared.open([url], withApplicationAt: safari, configuration: configuration) { _, error in
            if let error {
              result(FlutterError(code: "OPEN_FAILED", message: error.localizedDescription, details: nil))
            } else {
              result(nil)
            }
          }
        } else {
          NSWorkspace.shared.open(url)
          result(nil)
        }
        return
      }
      result(FlutterMethodNotImplemented)
    }
    self.channel = channel
  }

  func handleOpenUrls(_ urls: [URL]) {
    for url in urls {
      channel?.invokeMethod("onOpenUrl", arguments: url.absoluteString)
    }
  }
}
