import Cocoa
import CoreFoundation
import FlutterMacOS

@MainActor
protocol QuickPanelChannel: AnyObject {
  func setMethodCallHandler(_ handler: FlutterMethodCallHandler?)
  func invokeMethod(_ method: String, arguments: Any?)
}

@MainActor
final class FlutterQuickPanelChannel: QuickPanelChannel {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: MacQuickPanelService.channelName,
      binaryMessenger: messenger
    )
  }

  func setMethodCallHandler(_ handler: FlutterMethodCallHandler?) {
    channel.setMethodCallHandler(handler)
  }

  func invokeMethod(_ method: String, arguments: Any?) {
    channel.invokeMethod(method, arguments: arguments)
  }
}

@MainActor
protocol QuickPanelWindow: AnyObject {
  var frame: NSRect { get }
  func setFrame(_ frame: NSRect, display: Bool, animate: Bool)
  func makeKeyAndOrderFront(_ sender: Any?)
  func orderOut(_ sender: Any?)
}

extension NSWindow: QuickPanelWindow {}

@MainActor
protocol QuickPanelRunningApplication: AnyObject {
  var processIdentifier: pid_t { get }
  var isTerminated: Bool { get }
  func activateForQuickPanel() -> Bool
}

extension NSRunningApplication: QuickPanelRunningApplication {
  func activateForQuickPanel() -> Bool {
    return activate(options: [])
  }
}

@MainActor
final class MacQuickPanelService {
  static let channelName = "dev.hawkx.promptlibrary/mac_quick_panel"

  private weak var window: (any QuickPanelWindow)?
  private let channel: any QuickPanelChannel
  private let registrar: SystemHotKeyRegistrar
  private let frontmostApplication: () -> (any QuickPanelRunningApplication)?
  private let currentProcessIdentifier: () -> pid_t
  private let activateCurrentApplication: () -> Void
  private let visibleFrame: () -> NSRect?

  private var previousApplication: (any QuickPanelRunningApplication)?
  private var fullLibraryFrame: NSRect?
  private var isQuickMode = false
  private var isShutdown = false
  private var presentationGeneration = 0

  convenience init(
    window: NSWindow,
    messenger: FlutterBinaryMessenger
  ) {
    let channel = FlutterQuickPanelChannel(messenger: messenger)
    self.init(
      window: window,
      channel: channel,
      registrar: SystemHotKeyRegistrar(),
      frontmostApplication: {
        NSWorkspace.shared.frontmostApplication
      },
      currentProcessIdentifier: {
        NSRunningApplication.current.processIdentifier
      },
      activateCurrentApplication: {
        NSApp.activate(ignoringOtherApps: true)
      },
      visibleFrame: { [weak window] in
        window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
      }
    )
  }

  init(
    window: any QuickPanelWindow,
    channel: any QuickPanelChannel,
    registrar: SystemHotKeyRegistrar,
    frontmostApplication: @escaping () -> (any QuickPanelRunningApplication)?,
    currentProcessIdentifier: @escaping () -> pid_t,
    activateCurrentApplication: @escaping () -> Void,
    visibleFrame: @escaping () -> NSRect?
  ) {
    self.window = window
    self.channel = channel
    self.registrar = registrar
    self.frontmostApplication = frontmostApplication
    self.currentProcessIdentifier = currentProcessIdentifier
    self.activateCurrentApplication = activateCurrentApplication
    self.visibleFrame = visibleFrame

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(["kind": "unavailable"])
        return
      }
      self.handle(call: call, result: result)
    }
    registrar.setCallback { [weak self] in
      self?.requestQuickMode()
    }
  }

  func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard !isShutdown else {
      result(["kind": "unavailable"])
      return
    }
    switch call.method {
    case "registerHotKey":
      guard let spec = decodeHotKeySpec(call.arguments) else {
        result(["kind": "invalidShortcut"])
        return
      }
      result(map(registrar.replace(with: spec)))
    case "registrationState":
      guard call.arguments == nil else {
        result(["kind": "invalidShortcut"])
        return
      }
      result(map(registrar.registrationState))
    case "unregisterHotKey":
      guard call.arguments == nil else {
        result(["kind": "invalidShortcut"])
        return
      }
      result(map(registrar.unregister()))
    case "hideQuickMode":
      guard
        let arguments = call.arguments as? [String: Any],
        let restoreFocus = decodeBoolean(arguments["restoreFocus"]),
        let generation = decodeInteger(arguments["generation"])
      else {
        result(["kind": "invalidShortcut"])
        return
      }
      result(
        hideQuickMode(
          restoreFocus: restoreFocus,
          generation: generation
        )
      )
    case "showFullLibrary":
      guard call.arguments == nil else {
        result(["kind": "invalidShortcut"])
        return
      }
      result(showFullLibrary())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func requestQuickMode() {
    guard !isShutdown, let window else {
      return
    }
    if let application = frontmostApplication(),
       application.processIdentifier != currentProcessIdentifier() {
      previousApplication = application
    } else if !isQuickMode {
      previousApplication = nil
    }
    if !isQuickMode {
      fullLibraryFrame = window.frame
    }
    isQuickMode = true
    presentationGeneration += 1

    let available = visibleFrame() ?? window.frame
    let compact = NSRect(
      x: available.midX - 360,
      y: available.midY - 240,
      width: 720,
      height: 480
    )
    window.setFrame(compact, display: true, animate: false)
    activateCurrentApplication()
    window.makeKeyAndOrderFront(nil)
    channel.invokeMethod(
      "quickModeRequested",
      arguments: ["generation": presentationGeneration]
    )
  }

  func hideQuickMode(
    restoreFocus: Bool,
    generation: Int
  ) -> [String: Any] {
    guard !isShutdown, let window else {
      return ["kind": "unavailable"]
    }
    guard generation == presentationGeneration, isQuickMode else {
      return successResult
    }
    window.orderOut(nil)
    guard restoreFocus else {
      previousApplication = nil
      return successResult
    }

    let application = previousApplication
    previousApplication = nil
    guard let application, !application.isTerminated else {
      return ["kind": "nativeFailure"]
    }
    return application.activateForQuickPanel()
      ? successResult
      : ["kind": "nativeFailure"]
  }

  func showFullLibrary() -> [String: Any] {
    guard !isShutdown, let window else {
      return ["kind": "unavailable"]
    }
    presentationGeneration += 1
    if let fullLibraryFrame {
      window.setFrame(fullLibraryFrame, display: true, animate: false)
      self.fullLibraryFrame = nil
    }
    isQuickMode = false
    previousApplication = nil
    activateCurrentApplication()
    window.makeKeyAndOrderFront(nil)
    return successResult
  }
  func requestFullLibraryMode() {
    let result = showFullLibrary()
    guard result["kind"] as? String == "registered" else {
      return
    }
    channel.invokeMethod(
      "fullLibraryRequested",
      arguments: ["generation": presentationGeneration]
    )
  }

  func shutdown() {
    guard !isShutdown else {
      return
    }
    isShutdown = true
    channel.setMethodCallHandler(nil)
    registrar.setCallback(nil)
    registrar.shutdown()
    previousApplication = nil
    fullLibraryFrame = nil
    window = nil
  }

  private var successResult: [String: Any] {
    return ["kind": SystemHotKeyRegistrationKind.registered.rawValue]
  }

  private func decodeHotKeySpec(_ value: Any?) -> SystemHotKeySpec? {
    guard
      let arguments = value as? [String: Any],
      let keyCode = decodeInteger(arguments["keyCode"]),
      let modifiers = arguments["modifiers"] as? [String],
      keyCode >= 0,
      keyCode <= Int(UInt32.max),
      !modifiers.isEmpty
    else {
      return nil
    }
    return SystemHotKeySpec(
      keyCode: UInt32(keyCode),
      modifiers: Set(modifiers)
    )
  }

  private func decodeInteger(_ value: Any?) -> Int? {
    guard
      let number = value as? NSNumber,
      CFGetTypeID(number) != CFBooleanGetTypeID()
    else {
      return nil
    }
    let integer = number.int64Value
    guard NSNumber(value: integer).compare(number) == .orderedSame else {
      return nil
    }
    return Int(exactly: integer)
  }

  private func decodeBoolean(_ value: Any?) -> Bool? {
    guard
      let number = value as? NSNumber,
      CFGetTypeID(number) == CFBooleanGetTypeID()
    else {
      return nil
    }
    return number.boolValue
  }

  private func map(
    _ state: SystemHotKeyRegistrationResult
  ) -> [String: Any] {
    var value: [String: Any] = ["kind": state.kind.rawValue]
    if let code = state.diagnosticCode {
      value["diagnosticCode"] = Int(code)
    }
    return value
  }
}
