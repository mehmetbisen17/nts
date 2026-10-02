import Flutter
import UIKit
import UniformTypeIdentifiers
import ImageIO
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Registers all pubspec-referenced Flutter plugins in the given registry
  static func registerPlugins(with registry: FlutterPluginRegistry) {
    GeneratedPluginRegistrant.register(with: registry)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    AppDelegate.registerPlugins(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NtsICloudFolder") {
      ICloudFolderChannel.shared.register(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NtsHandwriting") {
      HandwritingChannel.register(messenger: registrar.messenger())
      ImageChannel.register(messenger: registrar.messenger())
    }
  }
}

/// Channel 'nts/icloud_folder': lets the user pick a folder (e.g. in iCloud Drive)
/// and keeps access to it via a bookmark. Dart side: lib/data/icloud/icloud_storage.dart
class ICloudFolderChannel: NSObject, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
  static let shared = ICloudFolderChannel()

  /// Security-scoped URLs we started accessing. Never stopped, so access
  /// lasts for the app's lifetime.
  private var accessedURLs: [URL] = []
  private var pendingResult: FlutterResult?

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "nts/icloud_folder", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      ICloudFolderChannel.shared.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "pickFolder":
      pickFolder(result: result)
    case "resolveBookmark":
      guard let base64 = args?["bookmark"] as? String, let data = Data(base64Encoded: base64) else {
        result(FlutterError(code: "RESOLVE_FAILED", message: "Invalid bookmark", details: nil))
        return
      }
      do {
        var isStale = false
        let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
        // Checked before re-creating a stale bookmark, which needs access
        guard startAccessing(url) else {
          result(FlutterError(code: "RESOLVE_FAILED", message: "Access to the folder was denied", details: nil))
          return
        }
        let bookmark = isStale
          ? try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
          : data
        result(folderInfo(url, bookmark: bookmark))
      } catch {
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

  private func pickFolder(result: @escaping FlutterResult) {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    guard var top = window?.rootViewController else {
      result(FlutterError(code: "NO_WINDOW", message: "No window to present the picker from", details: nil))
      return
    }
    while let presented = top.presentedViewController { top = presented }

    // A previous picker that was dismissed without a callback counts as cancelled.
    pendingResult?(nil)
    pendingResult = result

    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
    picker.allowsMultipleSelection = false
    picker.delegate = self
    picker.presentationController?.delegate = self
    top.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pendingResult else { return }
    pendingResult = nil
    guard let url = urls.first else {
      result(nil)
      return
    }
    _ = startAccessing(url)
    do {
      let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
      result(folderInfo(url, bookmark: bookmark))
    } catch {
      result(FlutterError(code: "BOOKMARK_FAILED", message: error.localizedDescription, details: nil))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingResult?(nil)
    pendingResult = nil
  }

  /// Swiping the picker away may skip documentPickerWasCancelled,
  /// which would leave the Dart call waiting forever.
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    pendingResult?(nil)
    pendingResult = nil
  }

  /// Returns whether access was granted.
  private func startAccessing(_ url: URL) -> Bool {
    guard url.startAccessingSecurityScopedResource() else { return false }
    accessedURLs.append(url)
    return true
  }
}

private func folderInfo(_ url: URL, bookmark: Data) -> [String: Any] {
  let isUbiquitous = (try? url.resourceValues(forKeys: [.isUbiquitousItemKey]))?.isUbiquitousItem == true
  return [
    "path": url.path,
    "bookmark": bookmark.base64EncodedString(),
    "inICloud": url.path.contains("/Mobile Documents/") || isUbiquitous,
  ]
}

/// Asks iCloud to download every item in [folder] (recursively, incl. hidden
/// files) that isn't local yet. Returns how many downloads were requested.
private func startDownloads(in folder: URL) -> Int {
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
    } else if let status = (try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?.ubiquitousItemDownloadingStatus,
              status != .current {
      target = url
    }
    if let target = target, (try? fm.startDownloadingUbiquitousItem(at: target)) != nil {
      count += 1
    }
  }
  return count
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
