import Cocoa
import FlutterMacOS

/// Owns the single Flutter view and native quick-panel service.
class MainFlutterWindow: NSWindow {
  private var quickPanelService: MacQuickPanelService?

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
  }

  deinit {
    MainActor.assumeIsolated {
      quickPanelService?.shutdown()
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
