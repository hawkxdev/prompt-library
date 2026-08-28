import Carbon.HIToolbox
import Foundation

struct SystemHotKeySpec: Equatable {
  let keyCode: UInt32
  let modifiers: Set<String>
}

enum SystemHotKeyRegistrationKind: String {
  case registered
  case collision
  case invalidShortcut
  case unavailable
  case nativeFailure
}

struct SystemHotKeyRegistrationResult: Equatable {
  let kind: SystemHotKeyRegistrationKind
  let diagnosticCode: OSStatus?
}

@MainActor
protocol CarbonHotKeyAPI: AnyObject {
  func installHandler(
    _ callback: @escaping (EventHotKeyID) -> OSStatus
  ) -> (EventHandlerRef?, OSStatus)

  func removeHandler(_ handler: EventHandlerRef) -> OSStatus

  func register(
    keyCode: UInt32,
    modifiers: UInt32,
    id: EventHotKeyID,
    options: OptionBits
  ) -> (EventHotKeyRef?, OSStatus)

  func unregister(_ hotKey: EventHotKeyRef) -> OSStatus
}

@MainActor
final class SystemHotKeyRegistrar {
  static let signature = OSType(0x504C4942)

  private let api: CarbonHotKeyAPI
  private var handler: EventHandlerRef?
  private var active: (
    spec: SystemHotKeySpec,
    reference: EventHotKeyRef,
    id: EventHotKeyID
  )?
  private var callback: (() -> Void)?
  private var nextID: UInt32 = 1
  private var deferredCleanup: [EventHotKeyRef] = []

  private(set) var registrationState = SystemHotKeyRegistrationResult(
    kind: .unavailable,
    diagnosticCode: nil
  )

  convenience init() {
    self.init(api: CarbonHotKeyAdapter())
  }

  init(api: CarbonHotKeyAPI) {
    self.api = api
  }

  func setCallback(_ callback: (() -> Void)?) {
    self.callback = callback
  }

  func replace(with spec: SystemHotKeySpec) -> SystemHotKeyRegistrationResult {
    guard let modifiers = Self.modifierBits(spec.modifiers) else {
      return update(Self.result(for: OSStatus(eventHotKeyInvalidErr)))
    }
    if active?.spec == spec {
      return update(
        SystemHotKeyRegistrationResult(
          kind: .registered,
          diagnosticCode: nil
        )
      )
    }
    guard ensureHandler() else {
      return registrationState
    }

    let id = EventHotKeyID(signature: Self.signature, id: nextID)
    nextID &+= 1
    let candidate = api.register(
      keyCode: spec.keyCode,
      modifiers: modifiers,
      id: id,
      options: OptionBits(kEventHotKeyExclusive)
    )
    guard candidate.1 == noErr else {
      return update(Self.result(for: candidate.1))
    }
    guard let candidateReference = candidate.0 else {
      return update(
        SystemHotKeyRegistrationResult(
          kind: .nativeFailure,
          diagnosticCode: nil
        )
      )
    }

    if let previous = active {
      let unregisterStatus = api.unregister(previous.reference)
      guard unregisterStatus == noErr else {
        if api.unregister(candidateReference) != noErr {
          deferredCleanup.append(candidateReference)
        }
        return update(Self.result(for: unregisterStatus))
      }
    }
    active = (spec, candidateReference, id)
    registrationState = SystemHotKeyRegistrationResult(
      kind: .registered,
      diagnosticCode: nil
    )
    return registrationState
  }

  func unregister() -> SystemHotKeyRegistrationResult {
    guard let active else {
      registrationState = SystemHotKeyRegistrationResult(
        kind: .unavailable,
        diagnosticCode: nil
      )
      return SystemHotKeyRegistrationResult(
        kind: .registered,
        diagnosticCode: nil
      )
    }
    let status = api.unregister(active.reference)
    guard status == noErr else {
      return update(Self.result(for: status))
    }
    self.active = nil
    if let handler {
      let handlerStatus = api.removeHandler(handler)
      guard handlerStatus == noErr else {
        self.handler = nil
        registrationState = SystemHotKeyRegistrationResult(
          kind: .unavailable,
          diagnosticCode: nil
        )
        return Self.result(for: handlerStatus)
      }
      self.handler = nil
    }
    registrationState = SystemHotKeyRegistrationResult(
      kind: .unavailable,
      diagnosticCode: nil
    )
    return SystemHotKeyRegistrationResult(
      kind: .registered,
      diagnosticCode: nil
    )
  }

  func shutdown() {
    _ = unregister()
    if let handler {
      _ = api.removeHandler(handler)
      self.handler = nil
    }
    for reference in deferredCleanup {
      _ = api.unregister(reference)
    }
    deferredCleanup.removeAll()
    callback = nil
    registrationState = SystemHotKeyRegistrationResult(
      kind: .unavailable,
      diagnosticCode: nil
    )
  }

  static func result(for status: OSStatus) -> SystemHotKeyRegistrationResult {
    switch status {
    case noErr:
      return SystemHotKeyRegistrationResult(
        kind: .registered,
        diagnosticCode: nil
      )
    case OSStatus(eventHotKeyExistsErr):
      return SystemHotKeyRegistrationResult(
        kind: .collision,
        diagnosticCode: status
      )
    case OSStatus(eventHotKeyInvalidErr):
      return SystemHotKeyRegistrationResult(
        kind: .invalidShortcut,
        diagnosticCode: status
      )
    default:
      return SystemHotKeyRegistrationResult(
        kind: .nativeFailure,
        diagnosticCode: status
      )
    }
  }

  private func ensureHandler() -> Bool {
    if handler != nil {
      return true
    }
    let installed = api.installHandler { [weak self] id in
      guard let self else {
        return OSStatus(eventNotHandledErr)
      }
      return self.handle(id)
    }
    guard installed.1 == noErr else {
      update(Self.result(for: installed.1))
      return false
    }
    guard let installedHandler = installed.0 else {
      update(
        SystemHotKeyRegistrationResult(
          kind: .nativeFailure,
          diagnosticCode: nil
        )
      )
      return false
    }
    handler = installedHandler
    return true
  }

  private func handle(_ id: EventHotKeyID) -> OSStatus {
    guard
      let active,
      id.signature == active.id.signature,
      id.id == active.id.id
    else {
      return OSStatus(eventNotHandledErr)
    }
    callback?()
    return noErr
  }

  @discardableResult
  private func update(
    _ result: SystemHotKeyRegistrationResult
  ) -> SystemHotKeyRegistrationResult {
    registrationState = result
    return result
  }

  private static func modifierBits(_ names: Set<String>) -> UInt32? {
    guard !names.isEmpty else {
      return nil
    }
    var bits: UInt32 = 0
    for name in names {
      switch name {
      case "command":
        bits |= UInt32(cmdKey)
      case "shift":
        bits |= UInt32(shiftKey)
      case "option":
        bits |= UInt32(optionKey)
      case "control":
        bits |= UInt32(controlKey)
      default:
        return nil
      }
    }
    return bits
  }
}

private let carbonHotKeyEventHandler: EventHandlerUPP = {
  _, event, userData in
  guard let event, let userData else {
    return OSStatus(eventNotHandledErr)
  }
  let adapter = Unmanaged<CarbonHotKeyAdapter>
    .fromOpaque(userData)
    .takeUnretainedValue()
  return MainActor.assumeIsolated {
    adapter.handle(event)
  }
}

@MainActor
final class CarbonHotKeyAdapter: CarbonHotKeyAPI {
  private var callback: ((EventHotKeyID) -> OSStatus)?

  func installHandler(
    _ callback: @escaping (EventHotKeyID) -> OSStatus
  ) -> (EventHandlerRef?, OSStatus) {
    self.callback = callback
    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )
    var handler: EventHandlerRef?
    let status = InstallEventHandler(
      GetApplicationEventTarget(),
      carbonHotKeyEventHandler,
      1,
      &eventType,
      Unmanaged.passUnretained(self).toOpaque(),
      &handler
    )
    if status != noErr {
      self.callback = nil
    }
    return (handler, status)
  }

  func removeHandler(_ handler: EventHandlerRef) -> OSStatus {
    callback = nil
    return RemoveEventHandler(handler)
  }

  func register(
    keyCode: UInt32,
    modifiers: UInt32,
    id: EventHotKeyID,
    options: OptionBits
  ) -> (EventHotKeyRef?, OSStatus) {
    var reference: EventHotKeyRef?
    let status = RegisterEventHotKey(
      keyCode,
      modifiers,
      id,
      GetApplicationEventTarget(),
      options,
      &reference
    )
    return (reference, status)
  }

  func unregister(_ hotKey: EventHotKeyRef) -> OSStatus {
    return UnregisterEventHotKey(hotKey)
  }

  fileprivate func handle(_ event: EventRef) -> OSStatus {
    var id = EventHotKeyID()
    var actualSize = 0
    let status = GetEventParameter(
      event,
      EventParamName(kEventParamDirectObject),
      EventParamType(typeEventHotKeyID),
      nil,
      MemoryLayout<EventHotKeyID>.size,
      &actualSize,
      &id
    )
    guard status == noErr else {
      return status
    }
    return callback?(id) ?? OSStatus(eventNotHandledErr)
  }
}
