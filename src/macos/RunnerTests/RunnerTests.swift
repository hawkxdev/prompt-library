import Carbon.HIToolbox
import FlutterMacOS
import XCTest

@testable import prompt_library

@MainActor
final class RunnerTests: XCTestCase {
  func testMapsStableCarbonStatuses() {
    XCTAssertEqual(
      SystemHotKeyRegistrar.result(for: noErr),
      SystemHotKeyRegistrationResult(kind: .registered, diagnosticCode: nil)
    )
    XCTAssertEqual(
      SystemHotKeyRegistrar.result(for: OSStatus(eventHotKeyExistsErr)),
      SystemHotKeyRegistrationResult(
        kind: .collision,
        diagnosticCode: OSStatus(eventHotKeyExistsErr)
      )
    )
    XCTAssertEqual(
      SystemHotKeyRegistrar.result(for: OSStatus(eventHotKeyInvalidErr)),
      SystemHotKeyRegistrationResult(
        kind: .invalidShortcut,
        diagnosticCode: OSStatus(eventHotKeyInvalidErr)
      )
    )
    XCTAssertEqual(
      SystemHotKeyRegistrar.result(for: -50),
      SystemHotKeyRegistrationResult(kind: .nativeFailure, diagnosticCode: -50)
    )
  }

  func testRegistersExclusiveHotKeyAndRoutesMatchingCallback() {
    let api = FakeCarbonHotKeyAPI()
    let registrar = SystemHotKeyRegistrar(api: api)
    var callbackCount = 0
    registrar.setCallback { callbackCount += 1 }
    let spec = SystemHotKeySpec(
      keyCode: UInt32(kVK_Space),
      modifiers: ["control", "option"]
    )

    XCTAssertEqual(registrar.replace(with: spec).kind, .registered)
    XCTAssertEqual(api.installCalls, 1)
    XCTAssertEqual(api.registerCalls.count, 1)
    XCTAssertEqual(
      api.registerCalls[0].modifiers,
      UInt32(controlKey | optionKey)
    )
    XCTAssertEqual(api.registerCalls[0].options, OptionBits(kEventHotKeyExclusive))

    XCTAssertEqual(api.emit(api.registerCalls[0].id), noErr)
    XCTAssertEqual(callbackCount, 1)
    XCTAssertEqual(
      api.emit(EventHotKeyID(signature: 0, id: 999)),
      OSStatus(eventNotHandledErr)
    )
    XCTAssertEqual(callbackCount, 1)
  }

  func testSameSpecIsIdempotent() {
    let api = FakeCarbonHotKeyAPI()
    let registrar = SystemHotKeyRegistrar(api: api)
    let spec = SystemHotKeySpec(keyCode: 35, modifiers: ["command"])

    XCTAssertEqual(registrar.replace(with: spec).kind, .registered)
    XCTAssertEqual(registrar.replace(with: spec).kind, .registered)

    XCTAssertEqual(api.installCalls, 1)
    XCTAssertEqual(api.registerCalls.count, 1)
    XCTAssertTrue(api.unregistered.isEmpty)
  }

  func testFailedReplacementRetainsOldRegistration() {
    let api = FakeCarbonHotKeyAPI()
    let registrar = SystemHotKeyRegistrar(api: api)
    var callbackCount = 0
    registrar.setCallback { callbackCount += 1 }
    let original = SystemHotKeySpec(keyCode: 35, modifiers: ["command"])
    let replacement = SystemHotKeySpec(keyCode: 49, modifiers: ["control"])

    XCTAssertEqual(registrar.replace(with: original).kind, .registered)
    api.registrationResults.append(
      (nil, OSStatus(eventHotKeyExistsErr))
    )

    let result = registrar.replace(with: replacement)

    XCTAssertEqual(result.kind, .collision)
    XCTAssertTrue(api.unregistered.isEmpty)
    XCTAssertEqual(api.emit(api.registerCalls[0].id), noErr)
    XCTAssertEqual(callbackCount, 1)
  }

  func testFailedOldUnregisterRollsBackCandidateAndKeepsOldCallback() {
    let api = FakeCarbonHotKeyAPI()
    let registrar = SystemHotKeyRegistrar(api: api)
    var callbackCount = 0
    registrar.setCallback { callbackCount += 1 }
    let original = SystemHotKeySpec(keyCode: 35, modifiers: ["command"])
    let replacement = SystemHotKeySpec(keyCode: 49, modifiers: ["control"])
    XCTAssertEqual(registrar.replace(with: original).kind, .registered)
    api.unregisterResults = [-50, noErr]

    let result = registrar.replace(with: replacement)

    XCTAssertEqual(
      result,
      SystemHotKeyRegistrationResult(kind: .nativeFailure, diagnosticCode: -50)
    )
    XCTAssertEqual(api.unregistered, [
      api.hotKeyReferences[0],
      api.hotKeyReferences[1],
    ])
    XCTAssertEqual(api.emit(api.registerCalls[0].id), noErr)
    XCTAssertEqual(callbackCount, 1)
    XCTAssertEqual(
      api.emit(api.registerCalls[1].id),
      OSStatus(eventNotHandledErr)
    )
  }

  func testSuccessfulReplacementUnregistersOldReference() {
    let api = FakeCarbonHotKeyAPI()
    let registrar = SystemHotKeyRegistrar(api: api)
    let original = SystemHotKeySpec(keyCode: 35, modifiers: ["command"])
    let replacement = SystemHotKeySpec(keyCode: 49, modifiers: ["control"])

    XCTAssertEqual(registrar.replace(with: original).kind, .registered)
    XCTAssertEqual(registrar.replace(with: replacement).kind, .registered)

    XCTAssertEqual(api.registerCalls.count, 2)
    XCTAssertEqual(api.unregistered, [api.hotKeyReferences[0]])
  }

  func testRejectsEmptyAndUnknownModifiersBeforeCarbon() {
    let api = FakeCarbonHotKeyAPI()
    let registrar = SystemHotKeyRegistrar(api: api)

    XCTAssertEqual(
      registrar.replace(with: SystemHotKeySpec(keyCode: 1, modifiers: [])).kind,
      .invalidShortcut
    )
    XCTAssertEqual(
      registrar.replace(
        with: SystemHotKeySpec(keyCode: 1, modifiers: ["capsLock"])
      ).kind,
      .invalidShortcut
    )
    XCTAssertTrue(api.registerCalls.isEmpty)
  }

  func testHandlerAndCandidateFailuresRemainObservable() {
    let handlerAPI = FakeCarbonHotKeyAPI()
    handlerAPI.installResult = (nil, -50)
    let handlerRegistrar = SystemHotKeyRegistrar(api: handlerAPI)

    XCTAssertEqual(
      handlerRegistrar.replace(
        with: SystemHotKeySpec(keyCode: 35, modifiers: ["command"])
      ),
      SystemHotKeyRegistrationResult(kind: .nativeFailure, diagnosticCode: -50)
    )

    let candidateAPI = FakeCarbonHotKeyAPI()
    candidateAPI.registrationResults.append((nil, noErr))
    let candidateRegistrar = SystemHotKeyRegistrar(api: candidateAPI)

    XCTAssertEqual(
      candidateRegistrar.replace(
        with: SystemHotKeySpec(keyCode: 35, modifiers: ["command"])
      ).kind,
      .nativeFailure
    )
  }

  func testUnregisterReleasesHotKeyAndHandlerIdempotently() {
    let api = FakeCarbonHotKeyAPI()
    let registrar = SystemHotKeyRegistrar(api: api)
    XCTAssertEqual(
      registrar.replace(
        with: SystemHotKeySpec(keyCode: 35, modifiers: ["command"])
      ).kind,
      .registered
    )

    XCTAssertEqual(registrar.unregister().kind, .registered)
    XCTAssertEqual(registrar.unregister().kind, .registered)

    XCTAssertEqual(api.unregistered, [api.hotKeyReferences[0]])
    XCTAssertEqual(api.removeCalls, 1)
    XCTAssertEqual(registrar.registrationState.kind, .unavailable)
  }

  func testShutdownIsIdempotentAndStopsCallbacks() {
    let api = FakeCarbonHotKeyAPI()
    let registrar = SystemHotKeyRegistrar(api: api)
    var callbackCount = 0
    registrar.setCallback { callbackCount += 1 }
    XCTAssertEqual(
      registrar.replace(
        with: SystemHotKeySpec(keyCode: 35, modifiers: ["command"])
      ).kind,
      .registered
    )
    let activeID = api.registerCalls[0].id

    registrar.shutdown()
    registrar.shutdown()

    XCTAssertEqual(api.unregistered, [api.hotKeyReferences[0]])
    XCTAssertEqual(api.removeCalls, 1)
    XCTAssertEqual(api.emit(activeID), OSStatus(eventNotHandledErr))
    XCTAssertEqual(callbackCount, 0)
    XCTAssertEqual(registrar.registrationState.kind, .unavailable)
  }
}

@MainActor
private final class FakeCarbonHotKeyAPI: CarbonHotKeyAPI {
  struct RegisterCall {
    let keyCode: UInt32
    let modifiers: UInt32
    let id: EventHotKeyID
    let options: OptionBits
  }

  var installResult: (EventHandlerRef?, OSStatus) = (
    OpaquePointer(bitPattern: 0x100),
    noErr
  )
  var registrationResults: [(EventHotKeyRef?, OSStatus)] = []
  var unregisterResults: [OSStatus] = []
  var installCalls = 0
  var removeCalls = 0
  var registerCalls: [RegisterCall] = []
  var unregistered: [EventHotKeyRef] = []
  var hotKeyReferences: [EventHotKeyRef] = []
  private var callback: ((EventHotKeyID) -> OSStatus)?

  func installHandler(
    _ callback: @escaping (EventHotKeyID) -> OSStatus
  ) -> (EventHandlerRef?, OSStatus) {
    installCalls += 1
    self.callback = callback
    return installResult
  }

  func removeHandler(_ handler: EventHandlerRef) -> OSStatus {
    removeCalls += 1
    callback = nil
    return noErr
  }

  func register(
    keyCode: UInt32,
    modifiers: UInt32,
    id: EventHotKeyID,
    options: OptionBits
  ) -> (EventHotKeyRef?, OSStatus) {
    registerCalls.append(
      RegisterCall(
        keyCode: keyCode,
        modifiers: modifiers,
        id: id,
        options: options
      )
    )
    if !registrationResults.isEmpty {
      return registrationResults.removeFirst()
    }
    let reference = OpaquePointer(bitPattern: 0x200 + hotKeyReferences.count)!
    hotKeyReferences.append(reference)
    return (reference, noErr)
  }

  func unregister(_ hotKey: EventHotKeyRef) -> OSStatus {
    unregistered.append(hotKey)
    if !unregisterResults.isEmpty {
      return unregisterResults.removeFirst()
    }
    return noErr
  }

  func emit(_ id: EventHotKeyID) -> OSStatus {
    return callback?(id) ?? OSStatus(eventNotHandledErr)
  }
}


@MainActor
extension RunnerTests {
  func testServiceDecodesChannelCallsAndStableResults() {
    let harness = ServiceHarness()

    let registered = harness.channel.call(
      "registerHotKey",
      arguments: [
        "keyCode": 49,
        "modifiers": ["control", "option"],
      ]
    ) as? [String: Any]
    XCTAssertEqual(registered?["kind"] as? String, "registered")

    let state = harness.channel.call("registrationState") as? [String: Any]
    XCTAssertEqual(state?["kind"] as? String, "registered")

    let unregistered = harness.channel.call("unregisterHotKey") as? [String: Any]
    XCTAssertEqual(unregistered?["kind"] as? String, "registered")
    let unavailableState =
      harness.channel.call("registrationState") as? [String: Any]
    XCTAssertEqual(unavailableState?["kind"] as? String, "unavailable")

    let invalid = harness.channel.call(
      "registerHotKey",
      arguments: ["keyCode": -1, "modifiers": []]
    ) as? [String: Any]
    XCTAssertEqual(invalid?["kind"] as? String, "invalidShortcut")

    let booleanKey = harness.channel.call(
      "registerHotKey",
      arguments: ["keyCode": true, "modifiers": ["control"]]
    ) as? [String: Any]
    XCTAssertEqual(booleanKey?["kind"] as? String, "invalidShortcut")

    let malformed = harness.channel.call(
      "hideQuickMode",
      arguments: ["restoreFocus": "yes"]
    ) as? [String: Any]
    XCTAssertEqual(malformed?["kind"] as? String, "invalidShortcut")

    let integerRestore = harness.channel.call(
      "hideQuickMode",
      arguments: ["restoreFocus": 1]
    ) as? [String: Any]
    XCTAssertEqual(integerRestore?["kind"] as? String, "invalidShortcut")

    let stateWithArguments = harness.channel.call(
      "registrationState",
      arguments: [:]
    ) as? [String: Any]
    XCTAssertEqual(
      stateWithArguments?["kind"] as? String,
      "invalidShortcut"
    )

    let frameBeforeMalformedShow = harness.window.frame
    let showWithArguments = harness.channel.call(
      "showFullLibrary",
      arguments: 1
    ) as? [String: Any]
    XCTAssertEqual(
      showWithArguments?["kind"] as? String,
      "invalidShortcut"
    )
    XCTAssertEqual(harness.window.frame, frameBeforeMalformedShow)

    let unknown = harness.channel.call("unknown")
    XCTAssertTrue(
      (unknown as AnyObject) === (FlutterMethodNotImplemented as AnyObject)
    )
  }

  func testHotKeyCapturesExternalApplicationAndUsesExistingWindow() {
    let harness = ServiceHarness()
    let external = FakeRunningApplication(processIdentifier: 2)
    harness.frontmost = external
    _ = harness.channel.call(
      "registerHotKey",
      arguments: ["keyCode": 49, "modifiers": ["control", "option"]]
    )

    XCTAssertEqual(harness.api.emit(harness.api.registerCalls[0].id), noErr)

    XCTAssertEqual(
      harness.window.frame,
      NSRect(x: 240, y: 160, width: 720, height: 480)
    )
    XCTAssertEqual(harness.window.makeKeyCalls, 1)
    XCTAssertEqual(harness.activateCurrentCalls, 1)
    XCTAssertEqual(harness.environment.events.prefix(2), ["frontmost", "activate"])
    XCTAssertEqual(harness.channel.invocations.map(\.method), ["quickModeRequested"])

    let hidden = harness.channel.call(
      "hideQuickMode",
      arguments: ["restoreFocus": true, "generation": 1]
    ) as? [String: Any]
    XCTAssertEqual(hidden?["kind"] as? String, "registered")
    XCTAssertEqual(harness.window.orderOutCalls, 1)
    XCTAssertEqual(external.activateCalls, 1)
  }

  func testStaleHideCannotOrderOutANewerQuickRequest() {
    let harness = ServiceHarness()
    let external = FakeRunningApplication(processIdentifier: 2)
    harness.frontmost = external

    harness.service.requestQuickMode()
    harness.service.requestQuickMode()
    let stale = harness.service.hideQuickMode(
      restoreFocus: true,
      generation: 1
    )

    XCTAssertEqual(stale["kind"] as? String, "registered")
    XCTAssertEqual(harness.window.orderOutCalls, 0)
    XCTAssertEqual(external.activateCalls, 0)

    _ = harness.service.hideQuickMode(restoreFocus: true, generation: 2)
    XCTAssertEqual(harness.window.orderOutCalls, 1)
    XCTAssertEqual(external.activateCalls, 1)
  }

  func testRepeatedRequestWhileFrontmostPreservesExternalFocusTarget() {
    let harness = ServiceHarness()
    let external = FakeRunningApplication(processIdentifier: 2)
    harness.frontmost = external

    harness.service.requestQuickMode()
    harness.service.requestQuickMode()
    let result = harness.service.hideQuickMode(restoreFocus: true, generation: 2)

    XCTAssertEqual(result["kind"] as? String, "registered")
    XCTAssertEqual(external.activateCalls, 1)
  }

  func testRepeatedQuickCyclesPreserveFullFrameAndRefreshFocusTarget() {
    let harness = ServiceHarness()
    let originalFrame = harness.window.frame
    let first = FakeRunningApplication(processIdentifier: 2)
    let second = FakeRunningApplication(processIdentifier: 3)

    harness.frontmost = first
    harness.service.requestQuickMode()
    _ = harness.service.hideQuickMode(restoreFocus: true, generation: 1)
    harness.frontmost = second
    harness.service.requestQuickMode()
    _ = harness.service.hideQuickMode(restoreFocus: true, generation: 2)
    let shown = harness.service.showFullLibrary()

    XCTAssertEqual(shown["kind"] as? String, "registered")
    XCTAssertEqual(harness.window.frame, originalFrame)
    XCTAssertEqual(first.activateCalls, 1)
    XCTAssertEqual(second.activateCalls, 1)
    XCTAssertEqual(harness.channel.invocations.count, 2)

    let movedFullFrame = NSRect(x: 30, y: 40, width: 900, height: 650)
    harness.window.frame = movedFullFrame
    _ = harness.service.showFullLibrary()
    XCTAssertEqual(harness.window.frame, movedFullFrame)
  }

  func testMissingOrSelfFocusTargetIsNonFatal() {
    let harness = ServiceHarness()
    harness.frontmost = FakeRunningApplication(processIdentifier: 1)

    harness.service.requestQuickMode()
    let result = harness.service.hideQuickMode(restoreFocus: true, generation: 1)

    XCTAssertEqual(result["kind"] as? String, "nativeFailure")
    XCTAssertEqual(harness.window.orderOutCalls, 1)
  }

  func testNativeReopenNotifiesDartAfterRestoringFullFrame() {
    let harness = ServiceHarness()
    let originalFrame = harness.window.frame
    harness.service.requestQuickMode()

    harness.service.requestFullLibraryMode()

    XCTAssertEqual(harness.window.frame, originalFrame)
    XCTAssertEqual(
      harness.channel.invocations.map(\.method),
      ["quickModeRequested", "fullLibraryRequested"]
    )
  }

  func testShutdownIsIdempotentAndRejectsStaleCalls() {
    let harness = ServiceHarness()
    _ = harness.channel.call(
      "registerHotKey",
      arguments: ["keyCode": 49, "modifiers": ["control", "option"]]
    )
    harness.service.requestQuickMode()

    harness.service.shutdown()
    harness.service.shutdown()
    let frameAfterShutdown = harness.window.frame
    harness.service.requestQuickMode()

    var registration: [String: Any]?
    harness.service.handle(
      call: FlutterMethodCall(
        methodName: "registrationState",
        arguments: nil
      ),
      result: { registration = $0 as? [String: Any] }
    )
    XCTAssertEqual(registration?["kind"] as? String, "unavailable")
    XCTAssertEqual(harness.window.frame, frameAfterShutdown)
    XCTAssertEqual(harness.channel.handlerRemovalCount, 1)
    XCTAssertEqual(harness.api.removeCalls, 1)
  }
  func testAppDelegateForwardsReopenAndTermination() {
    let delegate = AppDelegate()
    let window = TrackingMainFlutterWindow()

    XCTAssertFalse(
      delegate.applicationShouldTerminateAfterLastWindowClosed(NSApp)
    )
    XCTAssertTrue(delegate.handleReopen(windows: [window]))
    delegate.handleTermination(windows: [window])

    XCTAssertEqual(window.showFullCalls, 1)
    XCTAssertEqual(window.shutdownCalls, 1)
  }
}

@MainActor
private final class ServiceHarness {
  let window = FakeQuickPanelWindow(
    frame: NSRect(x: 100, y: 100, width: 1000, height: 700)
  )
  let channel = FakeQuickPanelChannel()
  let api = FakeCarbonHotKeyAPI()
  let environment = FakeServiceEnvironment()
  let registrar: SystemHotKeyRegistrar
  let service: MacQuickPanelService

  var frontmost: FakeRunningApplication? {
    get { environment.frontmost }
    set { environment.frontmost = newValue }
  }

  var activateCurrentCalls: Int {
    return environment.activateCurrentCalls
  }

  init() {
    registrar = SystemHotKeyRegistrar(api: api)
    service = MacQuickPanelService(
      window: window,
      channel: channel,
      registrar: registrar,
      frontmostApplication: { [environment] in
        environment.events.append("frontmost")
        return environment.frontmost
      },
      currentProcessIdentifier: { 1 },
      activateCurrentApplication: { [environment] in
        environment.events.append("activate")
        environment.activateCurrentCalls += 1
        environment.frontmost = FakeRunningApplication(processIdentifier: 1)
      },
      visibleFrame: { NSRect(x: 0, y: 0, width: 1200, height: 800) }
    )
  }
}

@MainActor
private final class FakeServiceEnvironment {
  var frontmost: FakeRunningApplication?
  var activateCurrentCalls = 0
  var events: [String] = []
}

@MainActor
private final class FakeQuickPanelChannel: QuickPanelChannel {
  struct Invocation {
    let method: String
    let arguments: Any?
  }

  private var handler: FlutterMethodCallHandler?
  var invocations: [Invocation] = []
  var handlerRemovalCount = 0

  func setMethodCallHandler(_ handler: FlutterMethodCallHandler?) {
    self.handler = handler
    if handler == nil {
      handlerRemovalCount += 1
    }
  }

  func invokeMethod(_ method: String, arguments: Any?) {
    invocations.append(Invocation(method: method, arguments: arguments))
  }

  func call(_ method: String, arguments: Any? = nil) -> Any? {
    var value: Any?
    handler?(
      FlutterMethodCall(methodName: method, arguments: arguments),
      { value = $0 }
    )
    return value
  }
}

@MainActor
private final class FakeQuickPanelWindow: QuickPanelWindow {
  var frame: NSRect
  var makeKeyCalls = 0
  var orderOutCalls = 0

  init(frame: NSRect) {
    self.frame = frame
  }

  func setFrame(_ frame: NSRect, display: Bool, animate: Bool) {
    self.frame = frame
  }

  func makeKeyAndOrderFront(_ sender: Any?) {
    makeKeyCalls += 1
  }

  func orderOut(_ sender: Any?) {
    orderOutCalls += 1
  }
}

@MainActor
private final class TrackingMainFlutterWindow: MainFlutterWindow {
  var showFullCalls = 0
  var shutdownCalls = 0

  init() {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
      styleMask: [],
      backing: .buffered,
      defer: false
    )
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not used in this test")
  }

  override func showFullLibrary() {
    showFullCalls += 1
  }

  override func shutdownQuickPanel() {
    shutdownCalls += 1
  }
}

@MainActor
private final class FakeRunningApplication: QuickPanelRunningApplication {
  let processIdentifier: pid_t
  var isTerminated = false
  var activationResult = true
  var activateCalls = 0

  init(processIdentifier: pid_t) {
    self.processIdentifier = processIdentifier
  }

  func activateForQuickPanel() -> Bool {
    activateCalls += 1
    return activationResult
  }
}
