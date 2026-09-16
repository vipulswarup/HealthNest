import Cocoa
import CryptoKit
import Darwin
import FlutterMacOS
import PDFKit

enum FolderCheckBridge {
  static let shared = FolderCheckBridgeImpl()
}

final class FolderCheckBridgeImpl {
  private var channel: FlutterMethodChannel?
  private var accessed: [URL] = []

  func attach(to controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "sanovault/folder_check",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickFolder":
      DispatchQueue.main.async { self.pickFolder(result: result) }
    case "restoreBookmark":
      let bookmark = (call.arguments as? [String: Any])?["bookmark"] as? String
      DispatchQueue.global(qos: .userInitiated).async {
        self.finish(result, self.restoreBookmark(bookmark))
      }
    case "stopAccess":
      stopAccess()
      result(nil)
    case "listSubfolders":
      let path = (call.arguments as? [String: Any])?["path"] as? String
      DispatchQueue.global(qos: .userInitiated).async {
        self.finish(result, self.listSubfolders(path))
      }
    case "scanTree":
      let args = call.arguments as? [String: Any]
      let path = args?["path"] as? String
      let exclusions = (args?["exclusions"] as? [String]) ?? []
      DispatchQueue.global(qos: .userInitiated).async {
        self.finish(result, self.scanTree(path, exclusions: exclusions))
      }
    case "readFile":
      let path = (call.arguments as? [String: Any])?["path"] as? String
      DispatchQueue.global(qos: .userInitiated).async {
        self.finish(result, self.readFile(path))
      }
    case "pdfStatus":
      let args = call.arguments as? [String: Any]
      let path = args?["path"] as? String
      let passwords = (args?["passwords"] as? [String]) ?? []
      DispatchQueue.global(qos: .userInitiated).async {
        self.finish(result, self.pdfStatus(path, passwords: passwords))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func finish(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async { result(value) }
  }

  private func fail(_ result: @escaping FlutterResult, _ code: String, _ message: String) {
    DispatchQueue.main.async {
      result(FlutterError(code: code, message: message, details: nil))
    }
  }

  private func pickFolder(result: @escaping FlutterResult) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = false
    panel.prompt = "Choose"
    panel.message = "Choose the health folder for this person"
    guard let window = NSApp.keyWindow ?? NSApp.windows.first else {
      result(FlutterError(code: "NO_WINDOW", message: "No window to pick a folder from.", details: nil))
      return
    }
    panel.beginSheetModal(for: window) { response in
      guard response == .OK, let url = panel.url else {
        result(nil)
        return
      }
      do {
        self.stopAccess()
        _ = url.startAccessingSecurityScopedResource()
        self.accessed = [url]
        let bookmark = try url.bookmarkData(
          options: .withSecurityScope,
          includingResourceValuesForKeys: nil,
          relativeTo: nil
        )
        result([
          "bookmark": bookmark.base64EncodedString(),
          "path": url.path,
          "displayPath": url.path,
        ])
      } catch {
        result(FlutterError(code: "BOOKMARK_FAILED", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func restoreBookmark(_ bookmarkBase64: String?) -> Any {
    guard let bookmarkBase64, let data = Data(base64Encoded: bookmarkBase64) else {
      return FlutterError(code: "BAD_BOOKMARK", message: "Saved folder bookmark is missing.", details: nil)
    }
    do {
      stopAccess()
      var stale = false
      let url = try URL(
        resolvingBookmarkData: data,
        options: [.withSecurityScope, .withoutUI],
        relativeTo: nil,
        bookmarkDataIsStale: &stale
      )
      _ = url.startAccessingSecurityScopedResource()
      accessed = [url]
      var bookmarkOut = bookmarkBase64
      if stale {
        let refreshed = try url.bookmarkData(
          options: .withSecurityScope,
          includingResourceValuesForKeys: nil,
          relativeTo: nil
        )
        bookmarkOut = refreshed.base64EncodedString()
      }
      return [
        "bookmark": bookmarkOut,
        "path": url.path,
        "displayPath": url.path,
        "stale": stale,
      ]
    } catch {
      return FlutterError(code: "RESTORE_FAILED", message: error.localizedDescription, details: nil)
    }
  }

  private func stopAccess() {
    for url in accessed {
      url.stopAccessingSecurityScopedResource()
    }
    accessed = []
  }

  private func listSubfolders(_ path: String?) -> Any {
    guard let path else {
      return FlutterError(code: "BAD_PATH", message: "Folder path is missing.", details: nil)
    }
    let root = URL(fileURLWithPath: path, isDirectory: true)
    var folders: [String] = []
    let enumerator = FileManager.default.enumerator(
      at: root,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )
    while let item = enumerator?.nextObject() as? URL {
      if item.lastPathComponent == "__MACOSX" {
        enumerator?.skipDescendants()
        continue
      }
      let values = try? item.resourceValues(forKeys: [.isDirectoryKey])
      guard values?.isDirectory == true else { continue }
      let relative = relativePath(item, root: root)
      if !relative.isEmpty { folders.append(relative) }
    }
    return folders.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  private func scanTree(_ path: String?, exclusions: [String]) -> Any {
    guard let path else {
      return FlutterError(code: "BAD_PATH", message: "Folder path is missing.", details: nil)
    }
    let root = URL(fileURLWithPath: path, isDirectory: true)
    let skipPrefixes = Set(exclusions.filter { !$0.isEmpty })
    var files: [[String: Any]] = []
    let enumerator = FileManager.default.enumerator(
      at: root,
      includingPropertiesForKeys: [
        .isDirectoryKey,
        .isRegularFileKey,
        .fileSizeKey,
        .isSymbolicLinkKey,
        .isUbiquitousItemKey,
        .ubiquitousItemDownloadingStatusKey,
      ],
      options: [.skipsHiddenFiles]
    )
    while let item = enumerator?.nextObject() as? URL {
      let relative = relativePath(item, root: root)
      if isExcluded(relative, skipPrefixes) {
        enumerator?.skipDescendants()
        continue
      }
      if item.lastPathComponent == "__MACOSX" {
        enumerator?.skipDescendants()
        continue
      }
      let values = try? item.resourceValues(forKeys: [
        .isDirectoryKey,
        .isRegularFileKey,
        .fileSizeKey,
        .isSymbolicLinkKey,
      ])
      if values?.isDirectory == true { continue }
      if values?.isSymbolicLink == true { continue }
      guard values?.isRegularFile == true else { continue }
      if shouldSkipName(item.lastPathComponent) { continue }
      if isGoogleShortcut(item) { continue }
      if isDicomFile(item) { continue }
      guard let kind = ingestKind(item) else { continue }
      let size = Int(values?.fileSize ?? 0)
      let onlineOnly = isOnlineOnly(item)
      var row: [String: Any] = [
        "path": item.path,
        "relativePath": relative,
        "parentName": parentFolderName(relative),
        "name": item.lastPathComponent,
        "size": size,
        "kind": kind,
        "onlineOnly": onlineOnly,
      ]
      if !onlineOnly && size > 0 && size <= 50 * 1024 * 1024 {
        if let digest = sha256Hex(item) {
          row["sha256"] = digest
        }
      }
      files.append(row)
    }
    return files
  }

  private func readFile(_ path: String?) -> Any {
    guard let path else {
      return FlutterError(code: "BAD_PATH", message: "File path is missing.", details: nil)
    }
    do {
      let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
      return FlutterStandardTypedData(bytes: data)
    } catch {
      return FlutterError(code: "READ_FAILED", message: error.localizedDescription, details: nil)
    }
  }

  private func pdfStatus(_ path: String?, passwords: [String]) -> Any {
    guard let path else {
      return FlutterError(code: "BAD_PATH", message: "File path is missing.", details: nil)
    }
    let url = URL(fileURLWithPath: path)
    guard let probe = PDFDocument(url: url) else {
      return ["locked": false]
    }
    if !probe.isEncrypted && !probe.isLocked {
      return ["locked": false]
    }
    for password in passwords {
      let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty { continue }
      guard let document = PDFDocument(url: url) else { continue }
      if document.unlock(withPassword: trimmed) {
        return ["locked": true, "password": trimmed]
      }
    }
    return ["locked": true]
  }

  private func relativePath(_ url: URL, root: URL) -> String {
    let rootPath = root.standardizedFileURL.path
    let full = url.standardizedFileURL.path
    if full == rootPath { return "" }
    if full.hasPrefix(rootPath + "/") {
      return String(full.dropFirst(rootPath.count + 1))
    }
    return url.lastPathComponent
  }

  private func parentFolderName(_ relative: String) -> String {
    let parts = relative.split(separator: "/").map(String.init)
    if parts.count < 2 { return "" }
    return parts[parts.count - 2]
  }

  private func isExcluded(_ relative: String, _ exclusions: Set<String>) -> Bool {
    if relative.isEmpty { return false }
    for exclusion in exclusions {
      if relative == exclusion || relative.hasPrefix(exclusion + "/") { return true }
    }
    return false
  }

  private func shouldSkipName(_ name: String) -> Bool {
    if name.hasPrefix(".") { return true }
    if name == "Icon\r" { return true }
    return false
  }

  private func isGoogleShortcut(_ url: URL) -> Bool {
    let ext = url.pathExtension.lowercased()
    return [
      "gdoc", "gsheet", "gslides", "gform", "gdraw", "gtable", "gsite", "gmap", "gshortcut",
    ].contains(ext)
  }

  private func isDicomFile(_ url: URL) -> Bool {
    let ext = url.pathExtension.lowercased()
    return ext == "dcm" || ext == "dicom"
  }

  private func ingestKind(_ url: URL) -> String? {
    let ext = url.pathExtension.lowercased()
    if ext == "pdf" { return "pdf" }
    if ["jpg", "jpeg", "png", "webp", "tif", "tiff", "heic", "heif", "avif", "gif", "bmp"].contains(ext) {
      return "image"
    }
    if ["doc", "docx", "xls", "xlsx", "ppt", "pptx"].contains(ext) { return "office" }
    return nil
  }

  private let sfDataless: UInt32 = 0x4000_0000

  private func isOnlineOnly(_ url: URL) -> Bool {
    var info = stat()
    if lstat(url.path, &info) == 0, (info.st_flags & sfDataless) != 0 {
      return true
    }
    if let values = try? url.resourceValues(forKeys: [
      .isUbiquitousItemKey,
      .ubiquitousItemDownloadingStatusKey,
    ]) {
      if values.isUbiquitousItem == true,
         values.ubiquitousItemDownloadingStatus == URLUbiquitousItemDownloadingStatus.notDownloaded {
        return true
      }
    }
    return false
  }

  private func sha256Hex(_ url: URL) -> String? {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? handle.close() }
    var hasher = SHA256()
    while true {
      let chunk = try? handle.read(upToCount: 1024 * 1024)
      guard let chunk, !chunk.isEmpty else { break }
      hasher.update(data: chunk)
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
  }
}
