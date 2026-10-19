import AppKit
import KeyboardShortcuts
import Sauce
import SwiftUI

class GlobalHotKey {
  typealias Handler = () -> Void

  static public var key: KeyEquivalent? { {
    guard let shortcut = KeyboardShortcuts.Shortcut(name: .popup),
          let key = Sauce.shared.character(for: shortcut.carbonKeyCode, modifiers: .cocoa([]))?.first else { return nil }
    return KeyEquivalent(key)
  }() }
  static public var modifierFlags: EventModifiers? { {
    guard let shortcut = KeyboardShortcuts.Shortcut(name: .popup) else { return nil }
    var result: EventModifiers = []
    if shortcut.modifiers.contains(.command) { result.insert(.command) }
    if shortcut.modifiers.contains(.shift) { result.insert(.shift) }
    if shortcut.modifiers.contains(.option) { result.insert(.option) }
    if shortcut.modifiers.contains(.control) { result.insert(.control) }
    return result
  }() }

  private var handler: Handler

  init(_ handler: @escaping Handler) {
    self.handler = handler
//    KeyboardShortcuts.onKeyDown(for: .popup, action: handler)
  }
}
