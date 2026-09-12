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
  func present() -> Bool

  /// Dismisses the system dialog and reports release completion.
  func dismiss(completion: @escaping () -> Void)
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

  func present() -> Bool {
    guard
      presenter.viewIfLoaded?.window != nil,
      presenter.presentedViewController == nil,
      !presenter.isBeingPresented,
      !presenter.isBeingDismissed,
      presenter.transitionCoordinator == nil
    else {
      return false
    }
    presenter.present(controller, animated: true)
    return presenter.presentedViewController === controller
  }

  func dismiss(completion: @escaping () -> Void) {
    if controller.isBeingDismissed {
      guard let coordinator = controller.transitionCoordinator else { return }
      _ = coordinator.animate(alongsideTransition: nil) { _ in completion() }
      return
    }
    guard
      controller.presentingViewController != nil ||
        controller.isBeingPresented ||
        presenter.presentedViewController === controller
    else {
      completion()
      return
    }
    controller.dismiss(animated: false, completion: completion)
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

  init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  func setMethodCallHandler(_ handler: FlutterMethodCallHandler?) {
    channel.setMethodCallHandler(handler)
  }
}

/// Routes callbacks for exactly one export operation.
@MainActor
private final class DocumentExportOperationDelegate: NSObject, UIDocumentPickerDelegate {
  private let operationID: UUID
  private weak var owner: DocumentExportPlugin?

  init(operationID: UUID, owner: DocumentExportPlugin) {
    self.operationID = operationID
    self.owner = owner
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    owner?.completeCancellation(operationID: operationID)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    owner?.completePick(operationID: operationID, urls: urls)
  }
}

/// Registers the document export channel and owns one active export.
///
/// The plugin owns the temporary document and the single active dialog,
/// delivers one result for an operation outcome or presentation failure,
/// invalidates delivery during teardown, and sweeps abandoned leftovers at
/// registration time.
@MainActor
final class DocumentExportPlugin: NSObject, @preconcurrency FlutterPlugin {
  /// Wire channel name shared with the Dart client.
  static let channelName = "dev.hawkx.promptlibrary/document_export"

  private let channel: DocumentExportChanneling
  private let writer: DocumentTempWriting
  private let pickerMaker: DocumentPickerMaking
  private let presenterProvider: () -> UIViewController?
  private let tempDirectory: URL
  private static var activeOperationDirectories = Set<URL>()
  private var callback: FlutterResult?
  private var payload: Data?
  private var temporary: URL?
  private var operationDirectory: URL?
  private var operationID: UUID?
  private var operationDelegate: DocumentExportOperationDelegate?
  private var presenting: DocumentPickerPresenting?
  private var shutdownRetainer: DocumentExportPlugin?
  private(set) var isShutdown = false

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
    let flutterChannel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let plugin = DocumentExportPlugin(
      channel: FlutterDocumentExportChannel(channel: flutterChannel),
      writer: FoundationDocumentTempWriter(),
      pickerMaker: SystemDocumentPickerMaker(),
      presenterProvider: { registrar.viewController },
      tempDirectory: FileManager.default.temporaryDirectory
        .appendingPathComponent("document_export", isDirectory: true)
    )
    registrar.publish(plugin)
    registrar.addMethodCallDelegate(plugin, channel: flutterChannel)
  }

  /// Detaches the channel and retracts the active operation; idempotent.
  func shutdown() {
    guard !isShutdown else { return }
    isShutdown = true
    channel.setMethodCallHandler(nil)
    callback = nil
    payload = nil
    operationID = nil
    guard let picker = presenting else {
      operationDelegate = nil
      retractTemporary()
      return
    }
    shutdownRetainer = self
    picker.dismiss { [weak self] in
      self?.completeShutdownCleanup()
    }
  }

  /// Releases resources when the owning Flutter engine detaches.
  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    shutdown()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "exportDocument" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard !isShutdown else {
      result(reply(.unavailable))
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
    guard let presenter = presenterProvider(), isReadyForPresentation(presenter) else {
      result(reply(.unavailable))
      return
    }
    let fileName = name.hasSuffix(".\(kind.fileExtension)")
      ? name
      : "\(name).\(kind.fileExtension)"
    let currentOperationID = UUID()
    let currentOperationDirectory = tempDirectory.appendingPathComponent(
      currentOperationID.uuidString,
      isDirectory: true
    )
    let url = currentOperationDirectory.appendingPathComponent(fileName)
    do {
      try FileManager.default.createDirectory(
        at: currentOperationDirectory,
        withIntermediateDirectories: true
      )
      try writer.write(typed.data, to: url)
    } catch {
      try? writer.removeItem(at: url)
      try? writer.removeItem(at: currentOperationDirectory)
      result(reply(.writeFailed))
      return
    }
    Self.activeOperationDirectories.insert(currentOperationDirectory)
    payload = typed.data
    temporary = url
    operationDirectory = currentOperationDirectory
    operationID = currentOperationID
    callback = result
    let delegate = DocumentExportOperationDelegate(
      operationID: currentOperationID,
      owner: self
    )
    operationDelegate = delegate
    let picker = pickerMaker.makePicker(for: url, presenter: presenter, delegate: delegate)
    presenting = picker
    guard picker.present() else {
      finish(operationID: currentOperationID, reply(.unavailable))
      return
    }
  }

  fileprivate func completeCancellation(operationID: UUID) {
    finish(operationID: operationID, reply(.cancelled))
  }

  fileprivate func completePick(operationID: UUID, urls: [URL]) {
    guard self.operationID == operationID else { return }
    guard let destination = urls.first else {
      finish(operationID: operationID, reply(.writeFailed))
      return
    }
    // The copy is complete when the delegate fires; balanced scoped access.
    let accessed = destination.startAccessingSecurityScopedResource()
    defer { if accessed { destination.stopAccessingSecurityScopedResource() } }
    guard let exported = try? Data(contentsOf: destination), let expected = payload,
      exported == expected
    else {
      finish(operationID: operationID, reply(.verifyFailed))
      return
    }
    finish(
      operationID: operationID,
      ["outcome": DocumentExportOutcome.saved.rawValue, "path": destination.path]
    )
  }

  /// Sweeps leftovers of operations that never reached a delegate outcome.
  private func sweepLeftovers() {
    for url in writer.contents(of: tempDirectory) {
      guard !Self.activeOperationDirectories.contains(url) else { continue }
      try? writer.removeItem(at: url)
    }
  }

  /// Delivers exactly once and retracts the operation-owned state.
  private func finish(operationID: UUID, _ reply: [String: String]) {
    guard self.operationID == operationID, let result = callback else { return }
    callback = nil
    payload = nil
    self.operationID = nil
    operationDelegate = nil
    presenting = nil
    retractTemporary()
    result(reply)
  }

  private func retractTemporary() {
    guard let directory = operationDirectory else { return }
    Self.activeOperationDirectories.remove(directory)
    operationDirectory = nil
    let url = temporary
    temporary = nil
    if let url {
      try? writer.removeItem(at: url)
    }
    try? writer.removeItem(at: directory)
  }

  private func completeShutdownCleanup() {
    presenting = nil
    operationDelegate = nil
    retractTemporary()
    shutdownRetainer = nil
  }

  private func isReadyForPresentation(_ presenter: UIViewController) -> Bool {
    presenter.viewIfLoaded?.window != nil &&
      presenter.presentedViewController == nil &&
      !presenter.isBeingPresented &&
      !presenter.isBeingDismissed &&
      presenter.transitionCoordinator == nil
  }

  private func reply(_ outcome: DocumentExportOutcome) -> [String: String] {
    ["outcome": outcome.rawValue]
  }
}
