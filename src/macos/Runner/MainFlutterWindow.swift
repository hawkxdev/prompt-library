import Cocoa
import FlutterMacOS

/// Owns the single Flutter view and native quick-panel service.
class MainFlutterWindow: NSWindow {
  private var quickPanelService: MacQuickPanelService?
  private var documentExportPlugin: DocumentExportPlugin?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = frame
    contentViewController = flutterViewController
    setFrame(windowFrame, display: true)
    RegisterGeneratedPlugins(registry: flutterViewController)
    super.awakeFromNib()
    quickPanelService = MacQuickPanelService(
      window: self,
      messenger: flutterViewController.engine.binaryMessenger
    )
    documentExportPlugin = DocumentExportPlugin(
      channel: FlutterDocumentExportChannel(
        messenger: flutterViewController.engine.binaryMessenger
      ),
      window: self,
      coordinator: DocumentExportCoordinator(writer: FoundationDocumentWriter())
    )
  }

  deinit {
    MainActor.assumeIsolated {
      quickPanelService?.shutdown()
      documentExportPlugin?.shutdown()
    }
  }

  /// Restores the ordinary full-library presentation.
  func showFullLibrary() {
    quickPanelService?.requestFullLibraryMode()
  }

  /// Releases native quick-panel resources once.
  func shutdownQuickPanel() {
    quickPanelService?.shutdown()
  }
}
