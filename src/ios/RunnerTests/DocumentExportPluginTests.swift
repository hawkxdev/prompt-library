import Flutter
import UIKit
import XCTest

@testable import Runner

/// In-memory writer with failure injection for export operations.
@MainActor
private final class FakeTempWriter: DocumentTempWriting {
  var failWrite = false
  private(set) var removedURLs: [URL] = []
  private var files: [URL: Data] = [:]

  func contents(of directory: URL) -> [URL] {
    let prefix = directory.standardizedFileURL.path + "/"
    var children = Set<URL>()
    for url in files.keys where url.standardizedFileURL.path.hasPrefix(prefix) {
      let remainder = String(url.standardizedFileURL.path.dropFirst(prefix.count))
      guard let first = remainder.split(separator: "/").first else { continue }
      children.insert(directory.appendingPathComponent(String(first)))
    }
    return children.sorted { $0.path < $1.path }
  }

  func write(_ data: Data, to url: URL) throws {
    if failWrite {
      files[url] = data.prefix(3)
      throw CocoaError(.fileWriteUnknown)
    }
    files[url] = data
  }

  func removeItem(at url: URL) throws {
    removedURLs.append(url)
    let prefix = url.standardizedFileURL.path + "/"
    files = files.filter {
      $0.key != url && !$0.key.standardizedFileURL.path.hasPrefix(prefix)
    }
  }

  func hasFile(at url: URL) -> Bool {
    files[url] != nil
  }

  func files(under directory: URL) -> [URL] {
    let prefix = directory.standardizedFileURL.path + "/"
    return files.keys.filter { $0.standardizedFileURL.path.hasPrefix(prefix) }
      .sorted { $0.path < $1.path }
  }

  func data(at url: URL) -> Data? {
    files[url]
  }

  func seed(_ url: URL, data: Data) {
    files[url] = data
  }
}

/// Records presentations and replays delegate events in tests.
@MainActor
private final class FakePicker: DocumentPickerPresenting {
  private(set) var presentAttemptCount = 0
  private(set) var presentCount = 0
  private(set) var dismissCount = 0
  var allowsPresentation = true
  let delegate: UIDocumentPickerDelegate
  let fileURL: URL
  let controller: UIDocumentPickerViewController
  private var dismissalCompletion: (() -> Void)?

  init(fileURL: URL, delegate: UIDocumentPickerDelegate) {
    self.fileURL = fileURL
    self.delegate = delegate
    // The system picker validates the exported file exists at creation.
    let stub = FileManager.default.temporaryDirectory
      .appendingPathComponent("fake-picker-\(UUID().uuidString).json")
    try? Data().write(to: stub, options: .atomic)
    controller = UIDocumentPickerViewController(forExporting: [stub], asCopy: true)
  }

  func present() -> Bool {
    presentAttemptCount += 1
    guard allowsPresentation else { return false }
    presentCount += 1
    return true
  }

  func dismiss(completion: @escaping () -> Void) {
    dismissCount += 1
    dismissalCompletion = completion
  }

  func completeDismissal() {
    let completion = dismissalCompletion
    dismissalCompletion = nil
    completion?()
  }

  func fireCancelled() {
    delegate.documentPickerWasCancelled?(controller)
  }

  func firePick(at urls: [URL]) {
    delegate.documentPicker?(controller, didPickDocumentsAt: urls)
  }
}

@MainActor
private final class FakePickerMaker: DocumentPickerMaking {
  private(set) var pickers: [FakePicker] = []
  var allowsNextPresentation = true

  func makePicker(
    for fileURL: URL,
    presenter: UIViewController,
    delegate: UIDocumentPickerDelegate
  ) -> DocumentPickerPresenting {
    let picker = FakePicker(fileURL: fileURL, delegate: delegate)
    picker.allowsPresentation = allowsNextPresentation
    allowsNextPresentation = true
    pickers.append(picker)
    return picker
  }
}

/// Regression control for C-1: retains nothing, so only the plugin keeps the
/// active picker alive during presentation.
@MainActor
private final class NonRetainingPickerMaker: DocumentPickerMaking {
  private(set) weak var lastMade: FakePicker?

  func makePicker(
    for fileURL: URL,
    presenter: UIViewController,
    delegate: UIDocumentPickerDelegate
  ) -> DocumentPickerPresenting {
    let picker = FakePicker(fileURL: fileURL, delegate: delegate)
    lastMade = picker
    return picker
  }
}

@MainActor
private final class FakeChannel: DocumentExportChanneling {
  private(set) var lastHandler: FlutterMethodCallHandler?

  func setMethodCallHandler(_ handler: FlutterMethodCallHandler?) {
    lastHandler = handler
  }
}

/// Presenter exposing UIKit transition states.
@MainActor
private final class TransitioningPresenter: UIViewController {
  var reportsBeingPresented = false
  var reportsBeingDismissed = false

  override var isBeingPresented: Bool {
    reportsBeingPresented
  }

  override var isBeingDismissed: Bool {
    reportsBeingDismissed
  }
}

/// Semantics of the iOS export plugin over injected seams.
@MainActor
final class DocumentExportPluginTests: XCTestCase {
  private var channel: FakeChannel!
  private var writer: FakeTempWriter!
  private var maker: FakePickerMaker!
  private var presenter: UIViewController!
  private var window: UIWindow!
  private var tempDirectory: URL!
  private var plugin: DocumentExportPlugin!
  private var replies: [[String: String]] = []

  override func setUp() {
    super.setUp()
    channel = FakeChannel()
    writer = FakeTempWriter()
    maker = FakePickerMaker()
    presenter = UIViewController()
    window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = presenter
    window.makeKeyAndVisible()
    replies = []
    tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("doc_plugin_tests_\(UUID().uuidString)", isDirectory: true)
    makePlugin()
  }

  override func tearDown() {
    plugin?.shutdown()
    maker?.pickers.last?.completeDismissal()
    window?.isHidden = true
    window = nil
    try? FileManager.default.removeItem(at: tempDirectory)
    // FakePicker stub files live in the shared temporary directory (C-3).
    let stubs = (try? FileManager.default.contentsOfDirectory(
      at: FileManager.default.temporaryDirectory, includingPropertiesForKeys: nil
    ))?.filter { $0.lastPathComponent.hasPrefix("fake-picker-") } ?? []
    for url in stubs {
      try? FileManager.default.removeItem(at: url)
    }
    super.tearDown()
  }

  private func makePlugin(pickerMaker: DocumentPickerMaking? = nil) {
    plugin = DocumentExportPlugin(
      channel: channel,
      writer: writer,
      pickerMaker: pickerMaker ?? maker,
      presenterProvider: { [presenter] in presenter },
      tempDirectory: tempDirectory
    )
    channel.setMethodCallHandler { [weak plugin] call, result in
      plugin?.handle(call, result: result)
    }
  }

  private func exportCall(
    name: String = "library.json",
    kind: String = "json",
    bytes: Data = Data([1, 2, 3])
  ) -> FlutterMethodCall {
    FlutterMethodCall(
      methodName: "exportDocument",
      arguments: [
        "name": name,
        "kind": kind,
        "bytes": FlutterStandardTypedData(bytes: bytes),
      ]
    )
  }

  private func callExport(
    name: String = "library.json",
    kind: String = "json",
    bytes: Data = Data([1, 2, 3])
  ) {
    channel.lastHandler?(exportCall(name: name, kind: kind, bytes: bytes)) { [weak self] reply in
      if let map = reply as? [String: String] {
        self?.replies.append(map)
      }
    }
  }

  private func destinationURL(contents: Data) -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("chosen_\(UUID().uuidString).json")
    try? contents.write(to: url, options: .atomic)
    return url
  }

  func testSuccessfulExportSavesVerifiedBytes() {
    let payload = Data("payload".utf8)
    let destination = destinationURL(contents: payload)
    defer { try? FileManager.default.removeItem(at: destination) }

    callExport(bytes: payload)
    let temp = writer.files(under: tempDirectory).first!
    XCTAssertTrue(writer.hasFile(at: temp))
    maker.pickers[0].firePick(at: [destination])

    XCTAssertEqual(replies, [["outcome": "saved", "path": destination.path]])
    XCTAssertTrue(writer.removedURLs.contains(temp))
    XCTAssertTrue(writer.contents(of: tempDirectory).isEmpty)
  }

  func testStalePickerCannotCompleteNextExport() {
    callExport(name: "first.json")
    let oldPicker = maker.pickers[0]
    oldPicker.fireCancelled()
    callExport(name: "second.json")
    let currentTemporary = writer.files(under: tempDirectory).first!

    oldPicker.fireCancelled()

    XCTAssertEqual(replies.count, 1)
    XCTAssertTrue(writer.hasFile(at: currentTemporary))
    XCTAssertEqual(maker.pickers[1].dismissCount, 0)
    maker.pickers[1].fireCancelled()
    XCTAssertEqual(replies.count, 2)
  }

  func testEmptyBytesRejectedWithoutPresentation() {
    callExport(bytes: Data())

    XCTAssertEqual(replies, [["outcome": "invalidArguments"]])
    XCTAssertTrue(maker.pickers.isEmpty)
  }

  func testCancelledOutcomeRemovesTemporaryFile() {
    callExport()
    let temp = writer.files(under: tempDirectory).first!

    maker.pickers[0].fireCancelled()

    XCTAssertEqual(replies, [["outcome": "cancelled"]])
    XCTAssertFalse(writer.hasFile(at: temp))
  }

  func testByteMismatchReturnsVerifyFailed() {
    let payload = Data("payload".utf8)
    let destination = destinationURL(contents: Data("other".utf8))
    defer { try? FileManager.default.removeItem(at: destination) }

    callExport(bytes: payload)
    maker.pickers[0].firePick(at: [destination])

    XCTAssertEqual(replies, [["outcome": "verifyFailed"]])
    XCTAssertTrue(writer.contents(of: tempDirectory).isEmpty)
  }

  func testWriteFailureReturnsWriteFailedWithoutPresentation() {
    writer.failWrite = true

    callExport()

    XCTAssertEqual(replies, [["outcome": "writeFailed"]])
    XCTAssertTrue(maker.pickers.isEmpty)
    XCTAssertTrue(writer.contents(of: tempDirectory).isEmpty)
  }

  func testInvalidArgumentsRejectedWithoutPresentation() {
    callExport(kind: "yaml")

    XCTAssertEqual(replies, [["outcome": "invalidArguments"]])
    XCTAssertTrue(maker.pickers.isEmpty)
  }

  func testBusyExportReturnsUnavailableWithoutSecondPresentation() {
    callExport()

    callExport()

    XCTAssertEqual(replies.last, ["outcome": "unavailable"])
    XCTAssertEqual(maker.pickers.count, 1)
    XCTAssertEqual(maker.pickers[0].presentCount, 1)
  }

  func testSingleCallbackDeliveredExactlyOnce() {
    let payload = Data("payload".utf8)
    let destination = destinationURL(contents: payload)
    defer { try? FileManager.default.removeItem(at: destination) }

    callExport(bytes: payload)
    let temp = writer.files(under: tempDirectory).first!
    maker.pickers[0].firePick(at: [destination])
    maker.pickers[0].firePick(at: [destination])

    XCTAssertEqual(replies.count, 1)
    XCTAssertFalse(writer.hasFile(at: temp))
  }

  func testShutdownRetainsSourceUntilOneDismissalCompletion() {
    callExport()
    let temp = writer.files(under: tempDirectory).first!
    let activePicker = maker.pickers[0]

    plugin.shutdown()
    plugin.shutdown()
    activePicker.fireCancelled()

    XCTAssertEqual(replies.count, 0)
    XCTAssertTrue(writer.hasFile(at: temp))
    XCTAssertEqual(activePicker.dismissCount, 1)
    XCTAssertNil(channel.lastHandler)

    activePicker.completeDismissal()

    XCTAssertFalse(writer.hasFile(at: temp))
  }

  func testActivePickerRetainedByPluginAndReleasedAfterOutcome() {
    // C-1 control: the system controller's delegate is weak, so the plugin
    // must hold the active wrapper itself; with a non-retaining maker the
    // wrapper would die before any delegate callback could arrive.
    let nonRetaining = NonRetainingPickerMaker()
    makePlugin(pickerMaker: nonRetaining)

    callExport()
    XCTAssertNotNil(nonRetaining.lastMade)

    nonRetaining.lastMade?.fireCancelled()
    XCTAssertEqual(replies.last, ["outcome": "cancelled"])
    XCTAssertNil(nonRetaining.lastMade)
  }

  func testRegistrationSweepsLeftoversFromPreviousLaunch() {
    let leftover = tempDirectory.appendingPathComponent("stale.json")
    writer.seed(leftover, data: Data("stale".utf8))

    makePlugin()

    XCTAssertFalse(writer.hasFile(at: leftover))
  }

  func testRegistrationPublishesPluginForEngineLifecycle() {
    var engine: FlutterEngine? = FlutterEngine(name: "document-export-registration-test")
    XCTAssertTrue(engine?.run() ?? false)
    guard let registrar = engine?.registrar(forPlugin: "DocumentExportPlugin") else {
      XCTFail("Expected registrar")
      return
    }

    DocumentExportPlugin.register(with: registrar)

    let published = engine?.valuePublished(
      byPlugin: "DocumentExportPlugin"
    ) as? DocumentExportPlugin
    XCTAssertNotNil(published)
    XCTAssertFalse(published?.isShutdown ?? true)
    engine?.destroyContext()
    engine = nil
    XCTAssertTrue(published?.isShutdown ?? false)
  }

  func testDetachedPresenterRejectedBeforePickerCreation() {
    plugin.shutdown()
    presenter = UIViewController()
    makePlugin()

    callExport()

    XCTAssertEqual(replies, [["outcome": "unavailable"]])
    XCTAssertTrue(maker.pickers.isEmpty)
    XCTAssertTrue(writer.files(under: tempDirectory).isEmpty)
  }

  func testAttachedPresenterStartsPresentation() {
    callExport()

    XCTAssertTrue(replies.isEmpty)
    XCTAssertEqual(maker.pickers.count, 1)
    XCTAssertEqual(maker.pickers[0].presentAttemptCount, 1)
    XCTAssertEqual(maker.pickers[0].presentCount, 1)
  }

  func testPresentingPresenterRejectedBeforePickerCreation() {
    plugin.shutdown()
    let transitioning = TransitioningPresenter()
    transitioning.reportsBeingPresented = true
    presenter = transitioning
    window.rootViewController = presenter
    makePlugin()

    callExport()

    XCTAssertEqual(replies, [["outcome": "unavailable"]])
    XCTAssertTrue(maker.pickers.isEmpty)
  }

  func testDismissingPresenterRejectedBeforePickerCreation() {
    plugin.shutdown()
    let transitioning = TransitioningPresenter()
    transitioning.reportsBeingDismissed = true
    presenter = transitioning
    window.rootViewController = presenter
    makePlugin()

    callExport()

    XCTAssertEqual(replies, [["outcome": "unavailable"]])
    XCTAssertTrue(maker.pickers.isEmpty)
  }

  func testPickerPresentationRefusalReturnsUnavailableAndCleansSource() {
    maker.allowsNextPresentation = false

    callExport()

    XCTAssertEqual(replies, [["outcome": "unavailable"]])
    XCTAssertEqual(maker.pickers[0].presentAttemptCount, 1)
    XCTAssertEqual(maker.pickers[0].presentCount, 0)
    XCTAssertTrue(writer.files(under: tempDirectory).isEmpty)
  }

  func testNewPluginDoesNotSweepAnotherPluginsLiveSource() {
    callExport(name: "shared.json", bytes: Data("first".utf8))
    let firstPicker = maker.pickers[0]
    let firstSource = firstPicker.fileURL
    let secondChannel = FakeChannel()
    let secondMaker = FakePickerMaker()
    let secondPlugin = DocumentExportPlugin(
      channel: secondChannel,
      writer: writer,
      pickerMaker: secondMaker,
      presenterProvider: { [presenter] in presenter },
      tempDirectory: tempDirectory
    )
    secondChannel.setMethodCallHandler { [weak secondPlugin] call, result in
      secondPlugin?.handle(call, result: result)
    }

    secondChannel.lastHandler?(
      exportCall(name: "shared.json", bytes: Data("second".utf8))
    ) { _ in }

    XCTAssertTrue(writer.hasFile(at: firstSource))
    XCTAssertEqual(writer.data(at: firstSource), Data("first".utf8))
    XCTAssertEqual(secondMaker.pickers[0].fileURL.lastPathComponent, "shared.json")
    XCTAssertEqual(firstSource.lastPathComponent, "shared.json")
    XCTAssertNotEqual(firstSource, secondMaker.pickers[0].fileURL)
    XCTAssertEqual(writer.files(under: tempDirectory).count, 2)

    firstPicker.fireCancelled()
    secondMaker.pickers[0].fireCancelled()
  }
}

/// Receives no events; keeps the weak forwarder of a real picker alive.
@MainActor
private final class SilentPickerDelegate: NSObject, UIDocumentPickerDelegate {}

/// Presentation of the real system picker from a scene-attached presenter.
///
/// The fakes above report presentation synchronously; UIKit presents the
/// system picker asynchronously through a remote view controller, so these
/// cases run the real controller inside the host application's scene.
@MainActor
final class SystemDocumentPickerPresentationTests: XCTestCase {
  private var window: UIWindow!
  private var presenter: UIViewController!
  private var tempDirectory: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    )
    presenter = UIViewController()
    window = UIWindow(windowScene: scene)
    window.windowLevel = .alert
    window.rootViewController = presenter
    window.makeKeyAndVisible()
    tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("system_picker_tests_\(UUID().uuidString)", isDirectory: true)
  }

  override func tearDown() {
    presenter?.presentedViewController?.dismiss(animated: false)
    window?.isHidden = true
    window = nil
    presenter = nil
    try? FileManager.default.removeItem(at: tempDirectory)
    super.tearDown()
  }

  /// Spins the main run loop until the condition holds or the timeout ends.
  private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
      RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
    return condition()
  }

  private func exportSources() -> [String] {
    (FileManager.default.subpaths(atPath: tempDirectory.path) ?? [])
      .filter { $0.hasSuffix("library.json") }
  }

  func testRealPickerKeepsExportPendingAndSourceWhilePresented() {
    let plugin = DocumentExportPlugin(
      channel: FakeChannel(),
      writer: FoundationDocumentTempWriter(),
      pickerMaker: SystemDocumentPickerMaker(),
      presenterProvider: { [presenter] in presenter },
      tempDirectory: tempDirectory
    )
    var replies: [Any?] = []
    plugin.handle(
      FlutterMethodCall(
        methodName: "exportDocument",
        arguments: [
          "name": "library.json",
          "kind": "json",
          "bytes": FlutterStandardTypedData(bytes: Data("payload".utf8)),
        ]
      )
    ) { replies.append($0) }

    // A cold first presentation took about 4 s on the simulator.
    let presented = waitUntil(timeout: 30) { self.presenter.presentedViewController != nil }

    XCTAssertTrue(presented, "the system picker was not presented")
    XCTAssertTrue(
      replies.isEmpty,
      "export replied before a picker outcome: \(replies); presented:"
        + " \(String(describing: presenter.presentedViewController))"
    )
    XCTAssertEqual(exportSources().count, 1, "the source was removed while the picker is presented")

    plugin.shutdown()
    XCTAssertTrue(waitUntil { self.exportSources().isEmpty })
  }

  func testShutdownBeforePickerAppearsKeepsSourceUntilDismissal() {
    let plugin = DocumentExportPlugin(
      channel: FakeChannel(),
      writer: FoundationDocumentTempWriter(),
      pickerMaker: SystemDocumentPickerMaker(),
      presenterProvider: { [presenter] in presenter },
      tempDirectory: tempDirectory
    )
    plugin.handle(
      FlutterMethodCall(
        methodName: "exportDocument",
        arguments: [
          "name": "library.json",
          "kind": "json",
          "bytes": FlutterStandardTypedData(bytes: Data("payload".utf8)),
        ]
      )
    ) { _ in }

    plugin.shutdown()

    XCTAssertEqual(
      exportSources().count,
      1,
      "the source was removed before the system picker appeared"
    )
    XCTAssertTrue(
      waitUntil(timeout: 30) {
        self.exportSources().isEmpty && self.presenter.presentedViewController == nil
      },
      "the picker was not dismissed and cleaned up after the presentation settled"
    )
  }

  func testRealPickerRefusedWhilePresenterShowsAnotherController() throws {
    let blocker = UIViewController()
    presenter.present(blocker, animated: false)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    let source = tempDirectory.appendingPathComponent("refused.json")
    try Data("payload".utf8).write(to: source)
    let forwarder = SilentPickerDelegate()
    let picker = SystemDocumentPicker(fileURL: source, presenter: presenter, forwarder: forwarder)

    XCTAssertFalse(picker.present())
    XCTAssertTrue(presenter.presentedViewController === blocker)
  }
}
