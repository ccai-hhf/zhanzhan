import Foundation

public struct FingerContact: Equatable, Sendable {
  public let id: Int
  public let x: Double
  public let y: Double
  public init(id: Int, x: Double, y: Double) { self.id = id; self.x = x; self.y = y }
}

/// Physical vertical movement, independent of the natural scrolling preference.
/// Commits on lift so a transient three-contact frame in a four-finger gesture cannot activate it.
public struct ThreeFingerSwipe: Sendable {
  public enum Direction: Sendable { case down, up }
  public private(set) var direction: Direction = .down
  private var origins: [Int: FingerContact] = [:]
  private var latest: [FingerContact] = []
  private var startedAt = 0.0
  private var cancelled = false
  private var lastTrigger = -Double.infinity
  public init() {}

  public mutating func update(_ touches: [FingerContact], at time: Double) -> Bool {
    guard time.isFinite, touches.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { reset(); return false }
    if touches.isEmpty {
      defer { reset() }
      guard !cancelled, origins.count == 3, latest.count == 3,
            (0.06...1.2).contains(time - startedAt), time - lastTrigger >= 0.7 else { return false }
      let dx = latest.reduce(0) { $0 + $1.x - origins[$1.id]!.x } / 3
      let dy = latest.reduce(0) { $0 + $1.y - origins[$1.id]!.y } / 3
      let sign = dy > 0 ? 1.0 : -1.0
      guard abs(dy) > 0.13, abs(dy) > abs(dx) * 1.6,
            latest.allSatisfy({ ($0.y - origins[$0.id]!.y) * sign > 0.07 }) else { return false }
      direction = dy > 0 ? .up : .down
      lastTrigger = time
      return true
    }
    if touches.count > 3 { cancelled = true; return false }
    guard !cancelled, touches.count == 3 else { return false }
    let ids = Set(touches.map(\.id))
    guard ids.count == 3 else { cancelled = true; return false }
    if origins.isEmpty {
      origins = Dictionary(uniqueKeysWithValues: touches.map { ($0.id, $0) })
      startedAt = time
    }
    guard ids == Set(origins.keys), time - startedAt <= 1.2 else { cancelled = true; return false }
    latest = touches
    return false
  }
  public mutating func reset() { origins = [:]; latest = []; cancelled = false; startedAt = 0 }
}
