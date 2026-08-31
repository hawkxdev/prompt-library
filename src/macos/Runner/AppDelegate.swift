import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(
    _ sender: NSApplication
  ) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    return handleReopen(windows: sender.windows)
  }

  override func applicationWillTerminate(_ notification: Notification) {
    handleTermination(windows: NSApp.windows)
    super.applicationWillTerminate(notification)
  }

  override func applicationSupportsSecureRestorableState(
    _ app: NSApplication
  ) -> Bool {
    return true
  }

  func handleReopen(windows: [NSWindow]) -> Bool {
    windows
      .compactMap { $0 as? MainFlutterWindow }
      .first?
      .showFullLibrary()
    return true
  }

  func handleTermination(windows: [NSWindow]) {
    windows
      .compactMap { $0 as? MainFlutterWindow }
      .forEach { $0.shutdownQuickPanel() }
  }
}
