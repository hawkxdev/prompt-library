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
    case failWithForeignFile
  }

  var writeBehavior: WriteBehavior = .success
  var verificationData: Data?
  var removeThrows = false
  var removedURLs: [URL] = []
  var foreignDestination: URL?
  let staging = FileManager.default.temporaryDirectory
    .appendingPathComponent("writer-stage-\(UUID().uuidString)", isDirectory: true)

  func stagingDirectory(for destination: URL) throws -> URL { staging }

  func publish(_ staged: URL, to destination: URL) throws {
    guard files[destination] == nil else { throw CocoaError(.fileWriteFileExists) }
    files[destination] = files.removeValue(forKey: staged)
  }
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
    case .failWithForeignFile:
      files[foreignDestination!] = Data("foreign".utf8)
      throw CocoaError(.fileWriteNoPermission)
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
    files = files.filter { $0.key != url && $0.key.deletingLastPathComponent() != url }
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

/// Observes cleanup around the real filesystem writer.
@MainActor
private final class ObservedDocumentWriter: DocumentWriting {
  private let writer = FoundationDocumentWriter()
  private(set) var staging: URL?
  private(set) var lastFailure: NSError?

  func stagingDirectory(for destination: URL) throws -> URL {
    do {
      let directory = try writer.stagingDirectory(for: destination)
      staging = directory
      return directory
    } catch {
      lastFailure = error as NSError
      throw error
    }
  }

  func write(_ data: Data, to url: URL) throws {
    do { try writer.write(data, to: url) } catch {
      lastFailure = error as NSError
      throw error
    }
  }
  func data(at url: URL) -> Data? { writer.data(at: url) }
  func removeItem(at url: URL) throws { try writer.removeItem(at: url) }
  func publish(_ staged: URL, to destination: URL) throws {
    do { try writer.publish(staged, to: destination) } catch {
      lastFailure = error as NSError
      throw error
    }
  }
}

@MainActor
final class DocumentExportPluginTests: XCTestCase {
  /// Acquires scoped access to the exact synthetic volume when requested.
  private func volumeURL(_ root: String) throws -> URL {
    let expected = URL(fileURLWithPath: root, isDirectory: true)
    guard ProcessInfo.processInfo.environment["PL_INTERACTIVE_VOLUME_ACCESS"] == "1" else {
      return expected
    }
    let panel = NSOpenPanel()
    panel.title = "Authorize synthetic volume"
    panel.message = "Select the current synthetic test volume."
    panel.prompt = "Use test volume"
    panel.directoryURL = expected
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let selected = panel.url,
          selected.resolvingSymlinksInPath() == expected.resolvingSymlinksInPath() else {
      throw CocoaError(.userCancelled)
    }
    return selected
  }

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
    let writer = ObservedDocumentWriter()

    let outcome = DocumentExportCoordinator(writer: writer)
      .performExport(payload, to: url)

    XCTAssertEqual(outcome, .saved)
    XCTAssertEqual(try? Data(contentsOf: url), payload)
    XCTAssertNotNil(writer.staging)
    XCTAssertFalse(FileManager.default.fileExists(atPath: writer.staging!.path))
  }

  func testSymlinkDestinationAndItsTargetArePreserved() throws {
    for existingTarget in [false, true] {
      let root = makeTempURL("doc_symlink_\(UUID().uuidString)")
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
      defer { clear(root) }
      let target = root.appendingPathComponent("target.json")
      let link = root.appendingPathComponent("link.json")
      if existingTarget { try Data("keep".utf8).write(to: target) }
      try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

      let outcome = DocumentExportCoordinator(writer: FoundationDocumentWriter())
        .performExport(Data("replacement".utf8), to: link)

      XCTAssertEqual(outcome, .existingFile)
      XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: link.path), target.path)
      if existingTarget {
        XCTAssertEqual(try Data(contentsOf: target), Data("keep".utf8))
      } else {
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
      }
    }
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
    XCTAssertEqual(writer.removedURLs, [writer.staging])
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
    XCTAssertEqual(writer.removedURLs, [writer.staging])
  }

  func testWriteFailureWithoutOwnershipPreservesForeignFile() {
    let url = makeTempURL("doc_plugin_foreign.json")
    let writer = FakeDocumentWriter()
    writer.writeBehavior = .failWithForeignFile
    writer.foreignDestination = url
    let coordinator = DocumentExportCoordinator(writer: writer)

    let outcome = coordinator.performExport(Data("payload".utf8), to: url)

    XCTAssertEqual(outcome, .writeFailed)
    XCTAssertEqual(writer.data(at: url), Data("foreign".utf8))
    XCTAssertFalse(writer.removedURLs.contains(url))
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
    XCTAssertEqual(writer.removedURLs, [writer.staging])
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
    let volume = try volumeURL(root)
    let accessed = volume.startAccessingSecurityScopedResource()
    defer { if accessed { volume.stopAccessingSecurityScopedResource() } }
    let url = volume
      .appendingPathComponent("doc_plugin_ro_\(UUID().uuidString).json")
    XCTAssertNoThrow(try FileManager.default.contentsOfDirectory(atPath: volume.path))

    let outcome = DocumentExportCoordinator(writer: FoundationDocumentWriter())
      .performExport(Data("payload".utf8), to: url)

    XCTAssertEqual(outcome, .writeFailed)
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
  }

  func testRealVolumeFullDiskLeavesNoPartialFile() throws {
    guard let root = ProcessInfo.processInfo.environment["PL_TINY_VOLUME"] else {
      throw XCTSkip("PL_TINY_VOLUME is not mounted")
    }
    let volume = try volumeURL(root)
    let accessed = volume.startAccessingSecurityScopedResource()
    defer { if accessed { volume.stopAccessingSecurityScopedResource() } }
    let url = volume
      .appendingPathComponent("doc_plugin_enospc_\(UUID().uuidString).json")

    let control = volume
      .appendingPathComponent("doc_plugin_control_\(UUID().uuidString).json")
    defer { clear(control) }
    let small = Data("control".utf8)
    let controlWriter = ObservedDocumentWriter()
    let controlOutcome = DocumentExportCoordinator(writer: controlWriter)
      .performExport(small, to: control)
    XCTAssertEqual(controlOutcome, .saved, "failure=\(String(describing: controlWriter.lastFailure)) staging=\(String(describing: controlWriter.staging))")
    XCTAssertEqual(try Data(contentsOf: control), small)

    let oversized = Data(count: 1 << 20)
    let outcome = DocumentExportCoordinator(writer: FoundationDocumentWriter())
      .performExport(oversized, to: url)

    XCTAssertEqual(outcome, .writeFailed)
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
  }
}
