import Flutter
import Foundation
import UIKit

/// Outcome names shared with the Dart client.
enum DocumentExportOutcome: String {
  case saved
  case cancelled
  case unavailable
  case writeFailed
  case verifyFailed
  case invalidArguments
}

/// Kind of exported document.
enum DocumentExportKind: String {
  /// Canonical JSON backup document.
  case json

  /// Readable Markdown export.
  case markdown

  /// File extension handed to the system picker.
  var fileExtension: String {
    switch self {
    case .json: return "json"
    case .markdown: return "md"
    }
  }
}

/// Prepares and retracts the temporary document owned by an export.
@MainActor
protocol DocumentTempWriting: AnyObject {
  /// Lists the leftover files of previous launches.
  func contents(of directory: URL) -> [URL]

  /// Writes bytes atomically, replacing only the caller-owned file.
  func write(_ data: Data, to url: URL) throws

  /// Removes a temporary file owned by this operation.
  func removeItem(at url: URL) throws
}

/// Foundation writer over the operation-owned temporary directory.
@MainActor
final class FoundationDocumentTempWriter: DocumentTempWriting {
  init() {}

  func contents(of directory: URL) -> [URL] {
    (try? FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil
    )) ?? []
  }

  func write(_ data: Data, to url: URL) throws {
    try data.write(to: url, options: .atomic)
  }

  func removeItem(at url: URL) throws {
    if FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.removeItem(at: url)
    }
  }
}

/// A presented export picker owned by one operation.
@MainActor
protocol DocumentPickerPresenting: AnyObject {
  /// Presents the system dialog to the user.
  func present()
}

/// Builds the picker for one export operation.
@MainActor
protocol DocumentPickerMaking: AnyObject {
  func makePicker(
    for fileURL: URL,
    presenter: UIViewController,
    delegate: UIDocumentPickerDelegate
  ) -> DocumentPickerPresenting
}

/// Real picker over UIDocumentPickerViewController forwarding delegate events.
@MainActor
final class SystemDocumentPicker: NSObject, UIDocumentPickerDelegate, DocumentPickerPresenting {
  private let controller: UIDocumentPickerViewController
  private let presenter: UIViewController
  private weak var forwarder: UIDocumentPickerDelegate?

  init(fileURL: URL, presenter: UIViewController, forwarder: UIDocumentPickerDelegate) {
    self.presenter = presenter
    self.forwarder = forwarder
    controller = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
    super.init()
    controller.allowsMultipleSelection = false
    controller.delegate = self
  }

  func present() {
    presenter.present(controller, animated: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    forwarder?.documentPickerWasCancelled?(controller)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    forwarder?.documentPicker?(controller, didPickDocumentsAt: urls)
  }
}

/// Real maker presenting through the already-validated view controller.
@MainActor
final class SystemDocumentPickerMaker: DocumentPickerMaking {
  init() {}

  func makePicker(
    for fileURL: URL,
    presenter: UIViewController,
    delegate: UIDocumentPickerDelegate
  ) -> DocumentPickerPresenting {
    SystemDocumentPicker(
      fileURL: fileURL,
      presenter: presenter,
      forwarder: delegate
    )
  }
}

/// Binary channel seam of the export plugin.
@MainActor
protocol DocumentExportChanneling: AnyObject {
  func setMethodCallHandler(_ handler: FlutterMethodCallHandler?)
}

/// Flutter channel implementation of the seam.
@MainActor
final class FlutterDocumentExportChannel: DocumentExportChanneling {
  private let channel: FlutterMethodChannel

  init(name: String, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)

  }

  func setMethodCallHandler(_ handler: FlutterMethodCallHandler?) {
    channel.setMethodCallHandler(handler)
  }
}

/// Registers the document export channel and owns one active export.
///
/// The plugin owns the temporary document and the single active dialog,
/// finishes the result exactly once on success, cancellation, presentation
/// failure, or teardown, and sweeps leftovers of unfinished operations at
/// registration time (HLD architectural decision 4).
@MainActor
final class DocumentExportPlugin: NSObject, UIDocumentPickerDelegate {
  /// Wire channel name shared with the Dart client.
  static let channelName = "dev.hawkx.promptlibrary/document_export"

  private let channel: DocumentExportChanneling
  private let writer: DocumentTempWriting
  private let pickerMaker: DocumentPickerMaking
  private let presenterProvider: () -> UIViewController?
  private let tempDirectory: URL
  private var callback: FlutterResult?
  private var payload: Data?
  private var temporary: URL?
  private var presenting: DocumentPickerPresenting?

  /// Creates the plugin over injected seams and sweeps stale leftovers.
  init(
    channel: DocumentExportChanneling,
    writer: DocumentTempWriting,
    pickerMaker: DocumentPickerMaking,
    presenterProvider: @escaping () -> UIViewController?,
    tempDirectory: URL
  ) {
    self.channel = channel
    self.writer = writer
    self.pickerMaker = pickerMaker
    self.presenterProvider = presenterProvider
    self.tempDirectory = tempDirectory
    super.init()
    try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    sweepLeftovers()
  }

  /// Registers the plugin on the implicit-engine registrar.
  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = DocumentExportPlugin(
      channel: FlutterDocumentExportChannel(
        name: channelName,
        messenger: registrar.messenger()
      ),
      writer: FoundationDocumentTempWriter(),
      pickerMaker: SystemDocumentPickerMaker(),
      presenterProvider: { registrar.viewController },
      tempDirectory: FileManager.default.temporaryDirectory
        .appendingPathComponent("document_export", isDirectory: true)
    )
    // The handler retains the plugin for the app lifetime; shutdown() detaches.
    plugin.channel.setMethodCallHandler { call, result in
      plugin.handle(call, result: result)
    }
  }

  /// Detaches the channel and retracts the active operation; idempotent.
  func shutdown() {
    channel.setMethodCallHandler(nil)
    callback = nil
    payload = nil
    presenting = nil
    retractTemporary()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "exportDocument" else {
      result(FlutterMethodNotImplemented)
      return
    }
    // Single active dialog: a second request never presents a second picker.
    guard callback == nil else {
      result(reply(.unavailable))
      return
    }
    guard
      let args = call.arguments as? [String: Any],
      let rawKind = args["kind"] as? String,
      let kind = DocumentExportKind(rawValue: rawKind),
      let rawName = args["name"] as? String,
      let typed = args["bytes"] as? FlutterStandardTypedData
    else {
      result(reply(.invalidArguments))
      return
    }
    let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, !name.contains("/"), !name.contains(":") else {
      result(reply(.invalidArguments))
      return
    }
    guard !typed.data.isEmpty else {
      result(reply(.invalidArguments))
      return
    }
    guard let presenter = presenterProvider(), presenter.presentedViewController == nil else {
      result(reply(.unavailable))
      return
    }
    let fileName = name.hasSuffix(".\(kind.fileExtension)")
      ? name
      : "\(name).\(kind.fileExtension)"
    let url = tempDirectory.appendingPathComponent(fileName)
    do {
      try writer.write(typed.data, to: url)
    } catch {
      try? writer.removeItem(at: url)
      result(reply(.writeFailed))
      return
    }
    payload = typed.data
    temporary = url
    callback = result
    let picker = pickerMaker.makePicker(for: url, presenter: presenter, delegate: self)
    // The plugin owns the active picker: the system controller's delegate is
    // weak, so nothing else keeps the wrapper alive during presentation.
    presenting = picker
    picker.present()
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finish(reply(.cancelled))
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let destination = urls.first else {
      finish(reply(.writeFailed))
      return
    }
    // The copy is complete when the delegate fires; balanced scoped access.
    let accessed = destination.startAccessingSecurityScopedResource()
    defer { if accessed { destination.stopAccessingSecurityScopedResource() } }
    guard let exported = try? Data(contentsOf: destination), let expected = payload,
      exported == expected
    else {
      finish(reply(.verifyFailed))
      return
    }
    finish(["outcome": DocumentExportOutcome.saved.rawValue, "path": destination.path])
  }

  /// Sweeps leftovers of operations that never reached a delegate outcome.
  private func sweepLeftovers() {
    for url in writer.contents(of: tempDirectory) {
      try? writer.removeItem(at: url)
    }
  }

  /// Delivers exactly once and retracts the operation-owned state.
  private func finish(_ reply: [String: String]) {
    guard let result = callback else { return }
    callback = nil
    payload = nil
    presenting = nil
    retractTemporary()
    result(reply)
  }

  private func retractTemporary() {
    guard let url = temporary else { return }
    temporary = nil
    try? writer.removeItem(at: url)
  }

  private func reply(_ outcome: DocumentExportOutcome) -> [String: String] {
    ["outcome": outcome.rawValue]
  }
}
