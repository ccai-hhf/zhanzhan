import AppKit
import Defaults

enum MenuIcon: String, CaseIterable, Identifiable, Defaults.Serializable {
  case maccy
  case clipboard
  case scissors
  case paperclip

  var id: Self { self }

  var image: NSImage {
    switch self {
    case .maccy:
      return NSImage(systemSymbolName: "square.on.square", accessibilityDescription: "沾沾")!
    case .clipboard:
      return NSImage(systemSymbolName: "clipboard", accessibilityDescription: "沾沾")!
    case .scissors:
      return NSImage(systemSymbolName: "scissors", accessibilityDescription: "沾沾")!
    case .paperclip:
      return NSImage(systemSymbolName: "paperclip", accessibilityDescription: "沾沾")!
    }
  }
}
