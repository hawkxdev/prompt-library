import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

/// Writes exported bytes without overwriting and verifies the result.
@MainActor
protocol DocumentWriting: AnyObject {
  /// Writes bytes refusing to overwrite an existing file.
  func write(_ data: Data, to url: URL) throws

  /// Reads back written bytes.
  func data(at url: URL) -> Data?

  /// Removes a partial or failed export file.
  func removeItem(at url: URL) throws
}

/// Foundation writer enforcing without-overwriting semantics.
@MainActor
final class FoundationDocumentWriter: DocumentWriting {
  func write(_ data: Data, to url: URL) throws {
    try data.write(to: url, options: [.withoutOverwriting])
  }

  func data(at url: URL) -> Data? {
    try? Data(contentsOf: url)
  }

  func removeItem(at url: URL) throws {
    try FileManager.default.removeItem(at: url)
  }
}

/// Outcome names shared with the Dart client.
enum DocumentExportOutcome: String {
  case saved
  case cancelled
  case existingFile
  case writeFailed
  case verifyFailed
  case unavailable
  case invalidArguments
}

/// Kind of exported document.
enum DocumentExportKind: String {
  case json
  case markdown

  var contentTypes: [UTType] {
    switch self {
    case .json:
      return [.json]
    case .markdown:
      return [UTType(filenameExtension: "md", conformingTo: .text) ?? .plainText]
    }
  }
}

/// Applies exported bytes to a chosen URL using an injected writer.
@MainActor
final class DocumentExportCoordinator {
  private let writer: any DocumentWriting

  init(writer: any DocumentWriting) {
    self.writer = writer
  }

  /// Writes, verifies and cleans up; never overwrites an existing file.
  func performExport(_ data: Data, to url: URL) -> DocumentExportOutcome {
    do {
      try writer.write(data, to: url)
    } catch let error as CocoaError where error.code == .fileWriteFileExists {
      return .existingFile
    } catch {
      cleanup(url)
      return .writeFailed
    }
    guard let written = writer.data(at: url), written == data else {
      cleanup(url)
      return .verifyFailed
    }
    return .saved
  }

  /// Removes a failed export attempt; cleanup failures stay silent.
  func cleanup(_ url: URL) {
    try? writer.removeItem(at: url)
  }
}

/// Binary channel seam for the export plugin.
@MainActor
protocol DocumentExportChannel: AnyObject {
  func setMethodCallHandler(_ handler: FlutterMethodCallHandler?)
}

/// Flutter channel implementation of the export seam.
@MainActor
final class FlutterDocumentExportChannel: DocumentExportChannel {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: DocumentExportPlugin.channelName,
      binaryMessenger: messenger
    )
  }

  func setMethodCallHandler(_ handler: FlutterMethodCallHandler?) {
    channel.setMethodCallHandler(handler)
  }
}

/// Registers the document export channel on the main window.
@MainActor
final class DocumentExportPlugin {
  static let channelName = "dev.hawkx.promptlibrary/document_export"

  private weak var window: NSWindow?
  private let channel: any DocumentExportChannel
  private let coordinator: DocumentExportCoordinator
  private var handlerInstalled = false

  init(
    channel: any DocumentExportChannel,
    window: NSWindow,
    coordinator: DocumentExportCoordinator
  ) {
    self.channel = channel
    self.window = window
    self.coordinator = coordinator
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result)
    }
    handlerInstalled = true
  }

  /// Releases the channel handler once; repeated calls are no-ops.
  func shutdown() {
    handlerInstalled = false
    channel.setMethodCallHandler(nil)
  }

  private func handle(
    _ call: FlutterMethodCall,
    _ result: @escaping FlutterResult
  ) {
    guard call.method == "exportDocument",
          let arguments = call.arguments as? [String: Any],
          let name = arguments["name"] as? String,
          !name.isEmpty,
          !name.contains("/"),
          !name.contains(":"),
          let kindRaw = arguments["kind"] as? String,
          let kind = DocumentExportKind(rawValue: kindRaw),
          let typedBytes = arguments["bytes"] as? FlutterStandardTypedData
    else {
      result(["outcome": DocumentExportOutcome.invalidArguments.rawValue])
      return
    }
    presentPanel(
      name: name,
      kind: kind,
      data: typedBytes.data,
      result: result
    )
  }

  private func presentPanel(
    name: String,
    kind: DocumentExportKind,
    data: Data,
    result: @escaping FlutterResult
  ) {
    guard let window else {
      result(["outcome": DocumentExportOutcome.unavailable.rawValue])
      return
    }
    let panel = NSSavePanel()
    panel.allowedContentTypes = kind.contentTypes
    panel.nameFieldStringValue = name
    panel.canCreateDirectories = true
    panel.beginSheetModal(for: window) { [weak self] response in
      guard let self, self.handlerInstalled else { return }
      guard response == .OK, let url = panel.url else {
        result(["outcome": DocumentExportOutcome.cancelled.rawValue])
        return
      }
      let outcome = self.coordinator.performExport(data, to: url)
      if outcome == .saved {
        result(["outcome": outcome.rawValue, "path": url.path])
      } else {
        result(["outcome": outcome.rawValue])
      }
    }
  }
}
