import Cocoa
import FlutterMacOS
import ImageIO
import Vision

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    // Before Flutter starts, so Dart reads the copied settings
    SandboxMigration.copyPreferences()

    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Content runs under a transparent title bar, so the sidebar sits
    // below the traffic lights. Flutter moves the window on drags
    // (WindowDragArea in lib/components/navbar/responsive_navbar.dart).
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.minSize = NSSize(width: 640, height: 480)

    RegisterGeneratedPlugins(registry: flutterViewController)
    ICloudFolderChannel.register(messenger: flutterViewController.engine.binaryMessenger, window: self)
    HandwritingChannel.register(messenger: flutterViewController.engine.binaryMessenger)
    ImageChannel.register(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// Channel 'nts/icloud_folder': lets the user pick a folder (e.g. in iCloud Drive)
/// and keeps access to it via a security-scoped bookmark.
/// Dart side: lib/data/icloud/icloud_storage.dart
enum ICloudFolderChannel {
  /// Security-scoped URLs we started accessing. Never stopped, so access
  /// lasts for the app's lifetime.
  private static var accessedURLs: [URL] = []

  static func register(messenger: FlutterBinaryMessenger, window: NSWindow) {
    let channel = FlutterMethodChannel(name: "nts/icloud_folder", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak window] call, result in
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "pickFolder":
        pickFolder(window: window, result: result)
      case "resolveBookmark":
        guard let base64 = args?["bookmark"] as? String, let data = Data(base64Encoded: base64) else {
          result(FlutterError(code: "RESOLVE_FAILED", message: "Invalid bookmark", details: nil))
          return
        }
        do {
          var isStale = false
          let url = try URL(
            resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
          // e.g. after a rebuild changed the code signature the bookmark is tied to
          guard startAccessing(url) else {
            throw CocoaError(.fileReadNoPermission, userInfo: [NSLocalizedDescriptionKey: "Access to the folder was denied"])
          }
          let bookmark = isStale
            ? try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            : data
          result(folderInfo(url, bookmark: bookmark))
        } catch {
          // Without the sandbox the app doesn't need the bookmark's permission,
          // e.g. for a bookmark made by the old sandboxed app or before a rebuild.
          var isStale = false
          if !SandboxMigration.isSandboxed,
            let url = try? URL(
              resolvingBookmarkData: data, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale),
            FileManager.default.isWritableFile(atPath: url.path)
          {
            result(folderInfo(url, bookmark: data))
            return
          }
          result(FlutterError(code: "RESOLVE_FAILED", message: error.localizedDescription, details: nil))
        }
      case "startDownloads":
        guard let path = args?["path"] as? String else {
          result(FlutterError(code: "BAD_ARGS", message: "Missing path", details: nil))
          return
        }
        DispatchQueue.global(qos: .utility).async {
          let count = startDownloads(in: URL(fileURLWithPath: path, isDirectory: true))
          DispatchQueue.main.async { result(count) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func pickFolder(window: NSWindow?, result: @escaping FlutterResult) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Use Folder"
    // A sandbox's home is the app container, so use the real home directory.
    // Not checking existence: a sandbox can't see it yet, and the panel
    // falls back to its default directory if it's missing.
    if let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir {
      panel.directoryURL = URL(fileURLWithPath: String(cString: home))
        .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
    }

    let completion: (NSApplication.ModalResponse) -> Void = { response in
      guard response == .OK, let url = panel.url else {
        result(nil)
        return
      }
      // A panel's URL is accessible anyway, so this may return false
      _ = startAccessing(url)
      do {
        // Unsandboxed, a plain bookmark does too if a security-scoped one fails
        let bookmark =
          try (try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil))
          ?? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        result(folderInfo(url, bookmark: bookmark))
      } catch {
        result(FlutterError(code: "BOOKMARK_FAILED", message: error.localizedDescription, details: nil))
      }
    }
    if let window = window {
      panel.beginSheetModal(for: window, completionHandler: completion)
    } else {
      completion(panel.runModal())
    }
  }

  /// Returns whether access was granted.
  private static func startAccessing(_ url: URL) -> Bool {
    guard url.startAccessingSecurityScopedResource() else { return false }
    accessedURLs.append(url)
    return true
  }

  private static func folderInfo(_ url: URL, bookmark: Data) -> [String: Any] {
    let isUbiquitous = (try? url.resourceValues(forKeys: [.isUbiquitousItemKey]))?.isUbiquitousItem == true
    return [
      "path": url.path,
      "bookmark": bookmark.base64EncodedString(),
      "inICloud": url.path.contains("/Mobile Documents/") || isUbiquitous,
    ]
  }

  /// Asks iCloud to download every item in [folder] (recursively, incl. hidden
  /// files) that isn't local yet. Returns how many downloads were requested.
  private static func startDownloads(in folder: URL) -> Int {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(at: folder, includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey]) else {
      return 0
    }
    var count = 0
    for case let url as URL in enumerator {
      let name = url.lastPathComponent
      var target: URL?
      if name.hasPrefix(".") && name.hasSuffix(".icloud") && name.count > ".icloud".count + 1 {
        // Placeholder ".<name>.icloud" stands for the not-yet-downloaded "<name>"
        let realName = String(name.dropFirst().dropLast(".icloud".count))
        target = url.deletingLastPathComponent().appendingPathComponent(realName)
      } else if let status = (try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?
        .ubiquitousItemDownloadingStatus,
        status != .current
      {
        target = url
      }
      if let target = target, (try? fm.startDownloadingUbiquitousItem(at: target)) != nil {
        count += 1
      }
    }
    return count
  }
}

// MARK: - Handwriting recognition

/// Channel 'nts/handwriting': reads the text in a PNG of handwriting with
/// Apple's Vision framework, on device. Dart side:
/// lib/data/services/handwriting.dart
enum HandwritingChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "nts/handwriting", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognize" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any]
      guard let png = args?["png"] as? FlutterStandardTypedData else {
        result(FlutterError(code: "BAD_ARGS", message: "Missing png", details: nil))
        return
      }
      let languages = args?["languages"] as? [String] ?? []
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let text = try recognize(png.data, languages: languages)
          DispatchQueue.main.async { result(text) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "RECOGNIZE_FAILED", message: error.localizedDescription, details: nil))
          }
        }
      }
    }
  }

  /// The lines of text in [image], top to bottom.
  /// [languages] are the user's, e.g. "en-GB", most preferred first.
  static func recognize(_ image: Data, languages: [String]) throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    let supported = (try? request.supportedRecognitionLanguages()) ?? []
    var wanted: [String] = []
    for tag in languages {
      // e.g. "en-GB" isn't supported, but "en-US" is
      let language = tag.split(separator: "-").first.map(String.init) ?? tag
      let match = supported.first { $0 == tag }
        ?? supported.first { $0 == language || $0.hasPrefix(language + "-") }
      if let match = match, !wanted.contains(match) { wanted.append(match) }
    }
    if !wanted.isEmpty { request.recognitionLanguages = wanted }

    try VNImageRequestHandler(data: image, options: [:]).perform([request])

    // Vision can split a line where there are big gaps, so join the pieces
    // that are level with each other, left to right.
    var lines: [[VNRecognizedTextObservation]] = []
    for piece in (request.results ?? []).sorted(by: { $0.boundingBox.midY > $1.boundingBox.midY }) {
      if let first = lines.last?.first,
        abs(first.boundingBox.midY - piece.boundingBox.midY) < first.boundingBox.height / 2
      {
        lines[lines.count - 1].append(piece)
      } else {
        lines.append([piece])
      }
    }
    return lines.map { line in
      line.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: " ")
    }.joined(separator: "\n")
  }
}

// MARK: - Leaving the App Sandbox

/// The Mac app used to run in the App Sandbox, which kept its data in
/// ~/Library/Containers/<bundle id>/Data. Unsandboxed (so it can run Claude
/// Code), the same APIs point to the normal locations, so the old settings
/// are copied over once. Nothing in the old container is changed or removed.
/// The notes are copied in Dart: lib/data/file_manager/sandbox_migration.dart
enum SandboxMigration {
  static let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil

  private static let marker = "nts.sandboxPreferencesCopied"

  /// Copies the old container's shared_preferences ("flutter." keys) into
  /// the app's preferences, never overwriting a key that's already set.
  static func copyPreferences() {
    let defaults = UserDefaults.standard
    guard !isSandboxed, !defaults.bool(forKey: marker), let id = Bundle.main.bundleIdentifier else { return }
    let old = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Containers/\(id)/Data/Library/Preferences/\(id).plist")
    // Missing (never sandboxed) or not readable yet: try again next launch
    guard let values = NSDictionary(contentsOf: old) as? [String: Any] else { return }
    var copied = 0
    for (key, value) in values where key.hasPrefix("flutter.") && defaults.object(forKey: key) == nil {
      defaults.set(value, forKey: key)
      copied += 1
    }
    defaults.set(true, forKey: marker)
    NSLog("nts: copied %d settings from the old app sandbox", copied)
  }
}

// MARK: - Image conversion

/// Channel 'nts/image': turns a picture Flutter can't decode (e.g. a HEIC
/// photo from Photos or Files) into a JPEG, with ImageIO. Dart side:
/// lib/pages/editor/editor.dart (`_toJpeg`).
enum ImageChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "nts/image", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "jpeg" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let bytes = call.arguments as? FlutterStandardTypedData else {
        result(FlutterError(code: "BAD_ARGS", message: "Missing image", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        let jpeg = toJpeg(bytes.data)
        DispatchQueue.main.async {
          result(jpeg.map { FlutterStandardTypedData(bytes: $0) })
        }
      }
    }
  }

  /// [data] as a JPEG, or nil if ImageIO can't read it.
  static func toJpeg(_ data: Data) -> Data? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailWithTransform: true,
          ] as CFDictionary)
    else { return nil }
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
      output as CFMutableData, "public.jpeg" as CFString, 1, nil)
    else { return nil }
    // Keep the photo's orientation
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
    CGImageDestinationAddImage(destination, image, properties)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return output as Data
  }
}
