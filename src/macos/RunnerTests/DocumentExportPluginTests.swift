import Cocoa
import FlutterMacOS
import XCTest

@testable import prompt_library

/// Replays writes and verification for failure injection.
@MainActor
private final class FakeDocumentWriter: DocumentWriting {
  enum WriteBehavior {
    case success
    case failAfterPartial
    case failExisting
  }

  var writeBehavior: WriteBehavior = .success
  var verificationData: Data?
  var removeThrows = false
  var removedURLs: [URL] = []
  private var files: [URL: Data] = [:]

  func write(_ data: Data, to url: URL) throws {
    switch writeBehavior {
    case .success:
      files[url] = data
    case .failAfterPartial:
      files[url] = data.prefix(4)
      throw CocoaError(.fileWriteUnknown)
    case .failExisting:
      throw CocoaError(.fileWriteFileExists)
    }
  }

  func data(at url: URL) -> Data? {
    verificationData ?? files[url]
  }

  func removeItem(at url: URL) throws {
    removedURLs.append(url)
    if removeThrows {
      throw CocoaError(.fileNoSuchFile)
    }
    files.removeValue(forKey: url)
  }

  func hasFile(at url: URL) -> Bool {
    files[url] != nil
  }
}

/// Records installed handlers for the export channel.
@MainActor
private final class FakeDocumentExportChannel: DocumentExportChannel {
  private(set) var lastHandler: FlutterMethodCallHandler?

  func setMethodCallHandler(_ handler: FlutterMethodCallHandler?) {
    lastHandler = handler
  }
}

@MainActor
final class DocumentExportPluginTests: XCTestCase {
  private func makeTempURL(_ name: String) -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(name)
  }

  private func clear(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
  }

  func testSuccessfulExportSavesVerifiedBytes() {
    let url = makeTempURL("doc_plugin_success.json")
    clear(url)
    defer { clear(url) }
    let payload = Data("{}".utf8)

    let outcome = DocumentExportCoordinator(writer: FoundationDocumentWriter())
      .performExport(payload, to: url)

    XCTAssertEqual(outcome, .saved)
    XCTAssertEqual(try? Data(contentsOf: url), payload)
  }

  func testExistingFileIsRejectedWithoutOverwrite() {
    let url = makeTempURL("doc_plugin_existing.json")
    clear(url)
    let original = Data("original".utf8)
    try? original.write(to: url)
    defer { clear(url) }

    let outcome = DocumentExportCoordinator(writer: FoundationDocumentWriter())
      .performExport(Data("replacement".utf8), to: url)

    XCTAssertEqual(outcome, .existingFile)
    XCTAssertEqual(try? Data(contentsOf: url), original)
  }

  func testVerificationFailureRemovesPartialFile() {
    let url = makeTempURL("doc_plugin_verify.json")
    clear(url)
    let writer = FakeDocumentWriter()
    writer.verificationData = Data("tampered".utf8)
    let coordinator = DocumentExportCoordinator(writer: writer)

    let outcome = coordinator.performExport(Data("payload".utf8), to: url)

    XCTAssertEqual(outcome, .verifyFailed)
    XCTAssertFalse(writer.hasFile(at: url))
    XCTAssertEqual(writer.removedURLs, [url])
  }

  func testWriteFailureRemovesPartialFile() {
    let url = makeTempURL("doc_plugin_write.json")
    clear(url)
    let writer = FakeDocumentWriter()
    writer.writeBehavior = .failAfterPartial
    let coordinator = DocumentExportCoordinator(writer: writer)

    let outcome = coordinator.performExport(Data("payload".utf8), to: url)

    XCTAssertEqual(outcome, .writeFailed)
    XCTAssertFalse(writer.hasFile(at: url))
    XCTAssertEqual(writer.removedURLs, [url])
  }

  func testCleanupFailureDoesNotMaskTypedOutcome() {
    let url = makeTempURL("doc_plugin_cleanup.json")
    clear(url)
    let writer = FakeDocumentWriter()
    writer.verificationData = Data("tampered".utf8)
    writer.removeThrows = true
    let coordinator = DocumentExportCoordinator(writer: writer)

    let outcome = coordinator.performExport(Data("payload".utf8), to: url)

    XCTAssertEqual(outcome, .verifyFailed)
    XCTAssertEqual(writer.removedURLs, [url])
  }

  func testRegistrationInstallsHandlerAndShutdownClearsItIdempotently() {
    let channel = FakeDocumentExportChannel()
    let plugin = DocumentExportPlugin(
      channel: channel,
      window: NSWindow(),
      coordinator: DocumentExportCoordinator(writer: FoundationDocumentWriter())
    )

    XCTAssertNotNil(channel.lastHandler)

    plugin.shutdown()
    XCTAssertNil(channel.lastHandler)

    plugin.shutdown()
    XCTAssertNil(channel.lastHandler)
  }

  func testInvalidArgumentsReturnWithoutPresentingPanel() throws {
    let channel = FakeDocumentExportChannel()
    let plugin = DocumentExportPlugin(
      channel: channel,
      window: NSWindow(),
      coordinator: DocumentExportCoordinator(writer: FoundationDocumentWriter())
    )
    let handler = try XCTUnwrap(channel.lastHandler)

    var outcome: String?
    handler(
      FlutterMethodCall(
        methodName: "exportDocument",
        arguments: [
          "name": "library.json",
          "kind": "yaml",
          "bytes": FlutterStandardTypedData(bytes: Data()),
        ]
      )
    ) { reply in
      let map = reply as? [String: Any]
      outcome = map?["outcome"] as? String
    }

    XCTAssertEqual(outcome, DocumentExportOutcome.invalidArguments.rawValue)
  }

  func testRealVolumeAccessDenialLeavesNoPartialFile() throws {
    guard let root = ProcessInfo.processInfo.environment["PL_READONLY_VOLUME"] else {
      throw XCTSkip("PL_READONLY_VOLUME is not mounted")
    }
    let url = URL(fileURLWithPath: root, isDirectory: true)
      .appendingPathComponent("doc_plugin_ro_\(UUID().uuidString).json")

    let outcome = DocumentExportCoordinator(writer: FoundationDocumentWriter())
      .performExport(Data("payload".utf8), to: url)

    XCTAssertEqual(outcome, .writeFailed)
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
  }

  func testRealVolumeFullDiskLeavesNoPartialFile() throws {
    guard let root = ProcessInfo.processInfo.environment["PL_TINY_VOLUME"] else {
      throw XCTSkip("PL_TINY_VOLUME is not mounted")
    }
    let url = URL(fileURLWithPath: root, isDirectory: true)
      .appendingPathComponent("doc_plugin_enospc_\(UUID().uuidString).json")

    let oversized = Data(count: 1 << 20)
    let outcome = DocumentExportCoordinator(writer: FoundationDocumentWriter())
      .performExport(oversized, to: url)

    XCTAssertEqual(outcome, .writeFailed)
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
  }
}
