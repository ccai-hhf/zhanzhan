import AppKit
import Defaults
import NativeTouch
import Observation
import ShelfCore

nonisolated private func receiveTouchFrame(_ buffer: UnsafePointer<ZZFinger>?, _ count: Int32, _ timestamp: Double) {
  guard count >= 0, count <= 32, let buffer else { return }
  let contacts = UnsafeBufferPointer(start: buffer, count: Int(count)).map {
    FingerContact(id: Int($0.id), x: $0.x, y: $0.y)
  }
  DispatchQueue.main.async { TrackpadGesture.shared.receive(contacts, timestamp: timestamp) }
}

@Observable
final class TrackpadGesture {
  static let shared = TrackpadGesture()
  private(set) var isRunning = false
  private(set) var status = "未启动"
  private(set) var recognizedCount = 0
  private var detector = ThreeFingerSwipe()
  private var observers: [NSObjectProtocol] = []
  private var initialized = false

  func initialize() {
    guard !initialized else { return }
    initialized = true
    Task {
      for await enabled in Defaults.updates(.threeFingerSwipe) {
        if enabled { start() } else { stop(); status = "已关闭" }
      }
    }
    let center = NSWorkspace.shared.notificationCenter
    observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
      MainActor.assumeIsolated { TrackpadGesture.shared.stop() }
    })
    observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
      MainActor.assumeIsolated {
        if Defaults[.threeFingerSwipe] { TrackpadGesture.shared.start() }
      }
    })
  }

  func start() {
    stop()
    let result = ZZTouchStart(receiveTouchFrame)
    isRunning = result == 0
    status = switch result {
    case 0: "三指下滑唤起、上滑收起已启用"
    case -2: "未检测到可用触控板，可继续使用快捷键"
    default: "当前系统无法读取触控板，可继续使用快捷键"
    }
  }
  func stop() { isRunning = false; ZZTouchStop(); detector.reset() }
  func receive(_ contacts: [FingerContact], timestamp: Double) {
    guard isRunning else { return }
    if detector.update(contacts, at: timestamp) {
      recognizedCount += 1
      guard !AppState.shared.isEditingItem else { return }
      let popup = AppState.shared.popup
      switch detector.direction {
      case .down where popup.isClosed():
        History.shared.searchQuery = ""
        popup.open(height: 490, at: .cursor)
      case .up where !popup.isClosed():
        popup.close()
      default: break
      }
    }
  }
}
