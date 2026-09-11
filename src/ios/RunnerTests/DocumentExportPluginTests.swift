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
    files.keys.filter { $0.deletingLastPathComponent() == directory }
      .sorted { $0.path < $1.path }
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
    files.removeValue(forKey: url)
  }

  func hasFile(at url: URL) -> Bool {
    files[url] != nil
  }

  func seed(_ url: URL, data: Data) {
    files[url] = data
  }
}

/// Records presentations and replays delegate events in tests.
@MainActor
private final class FakePicker: DocumentPickerPresenting {
  private(set) var presentCount = 0
  weak var delegate: UIDocumentPickerDelegate?
  let controller: UIDocumentPickerViewController

  init() {
    // The system picker validates the exported file exists at creation.
    let stub = FileManager.default.temporaryDirectory
      .appendingPathComponent("fake-picker-\(UUID().uuidString).json")
    try? Data().write(to: stub, options: .atomic)
    controller = UIDocumentPickerViewController(forExporting: [stub], asCopy: true)
  }

  func present() {
    presentCount += 1
  }

  func fireCancelled() {
    delegate?.documentPickerWasCancelled?(controller)
  }

  func firePick(at urls: [URL]) {
    delegate?.documentPicker?(controller, didPickDocumentsAt: urls)
  }
}

@MainActor
private final class FakePickerMaker: DocumentPickerMaking {
  private(set) var pickers: [FakePicker] = []

  func makePicker(
    for fileURL: URL,
    presenter: UIViewController,
    delegate: UIDocumentPickerDelegate
  ) -> DocumentPickerPresenting {
    let picker = FakePicker()
    picker.delegate = delegate
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
    let picker = FakePicker()
    picker.delegate = delegate
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

/// Semantics of the iOS export plugin over injected seams.
@MainActor
final class DocumentExportPluginTests: XCTestCase {
  private var channel: FakeChannel!
  private var writer: FakeTempWriter!
  private var maker: FakePickerMaker!
  private var presenter: UIViewController!
  private var tempDirectory: URL!
  private var plugin: DocumentExportPlugin!
  private var replies: [[String: String]] = []

  override func setUp() {
    super.setUp()
    channel = FakeChannel()
    writer = FakeTempWriter()
    maker = FakePickerMaker()
    presenter = UIViewController()
    replies = []
    tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("doc_plugin_tests_\(UUID().uuidString)", isDirectory: true)
    makePlugin()
  }

  override func tearDown() {
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
    // The handler retains the plugin, mirroring production registration.
    channel.setMethodCallHandler { [plugin] call, result in
      plugin.handle(call, result: result)
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
    let temp = writer.contents(of: tempDirectory).first!
    XCTAssertTrue(writer.hasFile(at: temp))
    maker.pickers[0].firePick(at: [destination])

    XCTAssertEqual(replies, [["outcome": "saved", "path": destination.path]])
    XCTAssertTrue(writer.removedURLs.contains(temp))
    XCTAssertTrue(writer.contents(of: tempDirectory).isEmpty)
  }

  func testEmptyBytesRejectedWithoutPresentation() {
    callExport(bytes: Data())

    XCTAssertEqual(replies, [["outcome": "invalidArguments"]])
    XCTAssertTrue(maker.pickers.isEmpty)
  }

  func testCancelledOutcomeRemovesTemporaryFile() {
    callExport()
    let temp = writer.contents(of: tempDirectory).first!

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
    let temp = writer.contents(of: tempDirectory).first!
    maker.pickers[0].firePick(at: [destination])
    maker.pickers[0].firePick(at: [destination])

    XCTAssertEqual(replies.count, 1)
    XCTAssertFalse(writer.hasFile(at: temp))
  }

  func testShutdownIsIdempotentDropsLateCallbacksAndClearsTemporary() {
    callExport()
    let temp = writer.contents(of: tempDirectory).first!

    plugin.shutdown()
    plugin.shutdown()
    maker.pickers[0].fireCancelled()

    XCTAssertEqual(replies.count, 0)
    XCTAssertFalse(writer.hasFile(at: temp))
    XCTAssertNil(channel.lastHandler)
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
}
