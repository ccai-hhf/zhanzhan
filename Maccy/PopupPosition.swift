import AppKit.NSEvent
import Defaults
import Foundation

enum PopupPosition: String, CaseIterable, Identifiable, CustomStringConvertible, Defaults.Serializable {
  case bottom
  case cursor
  case statusItem
  case window
  case center
  case lastPosition

  var id: Self { self }

  var description: String {
    switch self {
    case .bottom:
      return "屏幕底部"
    case .cursor:
      return NSLocalizedString("PopupAtCursor", tableName: "AppearanceSettings", comment: "")
    case .statusItem:
      return NSLocalizedString("PopupAtMenuBarIcon", tableName: "AppearanceSettings", comment: "")
    case .window:
      return NSLocalizedString("PopupAtWindowCenter", tableName: "AppearanceSettings", comment: "")
    case .center:
      return NSLocalizedString("PopupAtScreenCenter", tableName: "AppearanceSettings", comment: "")
    case .lastPosition:
      return NSLocalizedString("PopupAtLastPosition", tableName: "AppearanceSettings", comment: "")
    }
  }

  func origin(size: NSSize, statusBarButton: NSStatusBarButton?) -> NSPoint {
    switch self {
    case .bottom:
      let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
      if let frame = screen?.visibleFrame {
        return NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 12)
      }
    case .center:
      if let frame = NSScreen.forPopup?.visibleFrame {
        return NSRect.centered(ofSize: size, in: frame).origin
      }
    case .window:
      if let frame = NSWorkspace.shared.frontmostApplication?.windowFrame {
        return NSRect.centered(ofSize: size, in: frame).origin
      }
    case .statusItem:
      if let statusBarButton {
        let rectInWindow = statusBarButton.convert(statusBarButton.bounds, to: nil)
        if let screenRect = statusBarButton.window?.convertToScreen(rectInWindow) {
          let topLeftPoint = NSPoint(x: screenRect.minX, y: screenRect.minY - size.height)
          let screen = statusBarButton.window?.screen ?? NSScreen.main
          return constrained(topLeftPoint, ofSize: size, to: screen)
        }
      }
    case .lastPosition:
      if let frame = NSScreen.forPopup?.visibleFrame {
        let relativePos = Defaults[.windowPosition]
        let anchorX = frame.minX + frame.width * relativePos.x
        let anchorY = frame.minY + frame.height * relativePos.y
        // Anchor is top middle of frame
        return NSPoint(x: anchorX - size.width / 2, y: anchorY - size.height)
      }
    default:
      break
    }

    let mouseLocation = NSEvent.mouseLocation
    // Center the shelf around the invocation point, then keep it on that display.
    // Anchoring a large shelf below the pointer would clamp it to the bottom too often.
    let point = NSPoint(x: mouseLocation.x - size.width / 2, y: mouseLocation.y - size.height / 2)
    let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    return constrained(point, ofSize: size, to: screen)
  }

  // Ensure that window doesn't spill over to an adjacent screen.
  private func constrained(_ origin: NSPoint, ofSize size: NSSize, to screen: NSScreen?) -> NSPoint {
    guard let visibleFrame = screen?.visibleFrame else {
      return origin
    }

    let frame = visibleFrame.insetBy(dx: 12, dy: 12)
    return NSPoint(
      x: min(max(origin.x, frame.minX), max(frame.minX, frame.maxX - size.width)),
      y: min(max(origin.y, frame.minY), max(frame.minY, frame.maxY - size.height))
    )
  }
}
