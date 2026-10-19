import AppKit
import Foundation
import ShelfCore

@MainActor
final class Storage {
  static let shared = Storage()
  var items: [HistoryItem] = []
  private var archive: HistoryArchive?
  private var loadError: Error?
  private let url = URL.applicationSupportDirectory.appending(path: "ZhanZhan/History.json")

  var size: String {
    let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
  }

  init() {
    do {
      let archive = try HistoryArchive(url: url)
      self.archive = archive
      items = archive.records.map(HistoryItem.init(record:))
    } catch { loadError = error }
  }

  func loadItems() throws -> [HistoryItem] {
    if let loadError { throw loadError }
    return items
  }
  func insert(_ item: HistoryItem) { if !items.contains(item) { items.append(item) } }
  func delete(_ item: HistoryItem) { items.removeAll { $0 == item } }
  func processPendingChanges() {}

  func save() throws {
    if let loadError { throw loadError }
    guard var archive else { return }
    try archive.replace(with: items.map(\.record))
    self.archive = archive
  }

  @discardableResult
  func persist() -> Bool {
    do { try save(); return true }
    catch {
      items = archive?.records.map(HistoryItem.init(record:)) ?? []
      ShelfState.shared.errorMessage = "历史未能保存，已保留上次成功保存的数据：\(error.localizedDescription)"
      Task { try? await History.shared.load() }
      return false
    }
  }

  func cleanupOrphanedContents() throws -> Int { 0 }
  func removeUnpersistableContents() throws -> Int {
    var count = 0
    for item in items {
      let before = item.contents.count
      item.contents.removeAll { !Clipboard.shared.isPersistable(NSPasteboard.PasteboardType($0.type)) }
      count += before - item.contents.count
    }
    if count > 0 { try save() }
    return count
  }
  func sanitizeTitles() throws -> Int {
    var count = 0
    for item in items where item.title.containsScalarsUnsafeForTitleLayout {
      item.title = item.title.removingScalarsUnsafeForTitleLayout(); count += 1
    }
    if count > 0 { try save() }
    return count
  }
}
