import AppKit
import Defaults
import Observation
import ShelfCore

@Observable
final class ShelfState {
  static let shared = ShelfState()
  var library: ShelfLibrary?
  var errorMessage: String?
  var notice = ""
  var folderSelection = "all"
  var filter = "全部"
  var selectedHistoryID: UUID?
  var selectedFavoriteID: UUID?
  var undoAction: (() -> Void)?
  private var noticeTask: Task<Void, Never>?

  var folders: [ShelfFolder] { library?.folders ?? [] }
  var entries: [ShelfEntry] { library?.entries ?? [] }
  var currentFolderID: UUID? { UUID(uuidString: folderSelection) }
  var canPaste: Bool { AXIsProcessTrusted() }

  init() {
    do {
      library = try ShelfLibrary(url: URL.applicationSupportDirectory.appending(path: "ZhanZhan/Favorites.json"))
    } catch { errorMessage = "收藏加载失败，原数据未改动：\(error.localizedDescription)" }
  }

  @discardableResult
  func change(_ operation: (inout ShelfLibrary) throws -> Void) -> Bool {
    guard var draft = library else { errorMessage = "收藏库尚未加载，请修复数据文件后重启。"; return false }
    do {
      try operation(&draft)
      library = draft
      return true
    } catch { errorMessage = error.localizedDescription; return false }
  }

  func announce(_ text: String, undo: (() -> Void)? = nil) {
    noticeTask?.cancel()
    notice = text
    undoAction = undo
    noticeTask = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(undo == nil ? 4 : 10)) } catch { return }
      self?.notice = ""
      self?.undoAction = nil
    }
  }

  func undo() {
    let action = undoAction
    undoAction = nil
    action?()
  }

  func visibleEntries(query: String) -> [ShelfEntry] {
    entries.filter { entry in
      let inFolder = folderSelection == "all" ||
        (folderSelection == "unfiled" && entry.folderID == nil) ||
        (currentFolderID != nil && entry.folderID == currentFolderID)
      return inFolder && (query.isEmpty || (entry.title + " " + (entry.text ?? "")).localizedCaseInsensitiveContains(query))
    }
  }

  func historyItems() -> [HistoryItemDecorator] {
    History.shared.items.toArray().filter { item in
      switch filter {
      case "图片": item.hasImage
      case "链接": webURL(item.item.text) != nil
      case "文件": item.hasFileURLs
      case "文字": !item.hasImage && !item.hasFileURLs && webURL(item.item.text) == nil
      default: true
      }
    }
  }

  func webURL(_ text: String?) -> URL? {
    guard let text, let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
          ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
    return url
  }

  func contents(of item: HistoryItem) -> [ShelfContent] {
    item.contents.compactMap {
      guard let data = $0.value, $0.type != NSPasteboard.PasteboardType.fromMaccy.rawValue else { return nil }
      return ShelfContent(type: $0.type, value: data)
    }
  }

  func bookmark(_ item: HistoryItemDecorator, folderID: UUID? = nil) {
    let payload = contents(of: item.item)
    let title = item.hasImage ? "图片 · \(Date.now.formatted(date: .abbreviated, time: .shortened))" :
      String((item.item.previewableText.isEmpty ? "收藏内容" : item.item.previewableText).prefix(40))
    if change({ try $0.saveEntry(title: title, contents: payload, folderID: folderID, application: item.item.application) }) {
      announce("已加入收藏")
    }
  }

  func historyItem(for entry: ShelfEntry) -> HistoryItem {
    let item = HistoryItem(contents: entry.contents.map { HistoryItemContent(type: $0.type, value: $0.value) })
    item.title = entry.title
    item.application = entry.application
    return item
  }

  func choose(_ item: HistoryItem) {
    selectedHistoryID = item.id
    selectedFavoriteID = nil
    use(item, paste: false, keepOpen: true)
    announce("已复制 · 双击卡片或按回车粘贴")
  }

  func chooseFavorite(_ entry: ShelfEntry) {
    selectedFavoriteID = entry.id
    selectedHistoryID = nil
    use(historyItem(for: entry), paste: false, keepOpen: true)
    announce("已复制收藏 · 双击粘贴，网址箭头打开")
  }

  func use(_ item: HistoryItem, paste: Bool, keepOpen: Bool = false) {
    Clipboard.shared.copy(item, removeFormatting: Defaults[.removeFormattingByDefault])
    if paste && !canPaste {
      announce("已复制。开启辅助功能后可自动粘贴，也可回到原窗口按 ⌘V。")
      return
    }
    if paste {
      AppState.shared.popup.close {
        Task {
          try? await Task.sleep(for: .milliseconds(120))
          guard AppState.shared.popup.isClosed() else { return }
          Clipboard.shared.paste()
        }
      }
    } else if !keepOpen {
      AppState.shared.popup.close()
    }
  }

  func open(_ entry: ShelfEntry) {
    guard let url = entry.webURL else { return }
    AppState.shared.popup.close()
    NSWorkspace.shared.open(url)
  }

  func requestPastePermission() {
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
      NSWorkspace.shared.open(url)
    }
  }

  func deleteHistory(_ decorator: HistoryItemDecorator) {
    let payload = contents(of: decorator.item)
    let title = decorator.item.title
    let source = decorator.item.application
    let first = decorator.item.firstCopiedAt, last = decorator.item.lastCopiedAt
    let rank = decorator.item.shelfRank
    let copies = decorator.item.numberOfCopies
    History.shared.delete(decorator)
    guard !History.shared.items.contains(where: { $0.id == decorator.id }) else { return }
    announce("记录已删除", undo: {
      let restored = HistoryItem(contents: payload.map { HistoryItemContent(type: $0.type, value: $0.value) })
      restored.title = title; restored.application = source
      restored.firstCopiedAt = first; restored.lastCopiedAt = last; restored.numberOfCopies = copies
      if #unavailable(macOS 15) { try? History.shared.insertIntoStorage(restored) }
      let added = History.shared.add(restored)
      added.item.shelfRank = rank
      do { try Storage.shared.save() } catch { self.errorMessage = error.localizedDescription }
      Task { try? await History.shared.load() }
      self.announce("已恢复记录")
    })
  }

  func deleteFavorite(_ entry: ShelfEntry) {
    let index = entries.firstIndex(where: { $0.id == entry.id }) ?? 0
    if change({ try $0.deleteEntry(entry.id) }) {
      announce("收藏已删除", undo: {
        if self.change({ try $0.restoreEntry(entry, at: index) }) { self.announce("已恢复收藏") }
      })
    }
  }

  func moveHistory(_ tokens: [String], before target: UUID, after: Bool = false) -> Bool {
    guard History.shared.searchQuery.isEmpty, filter == "全部", let token = tokens.first,
          token.hasPrefix("history:"), let id = UUID(uuidString: String(token.dropFirst(8))) else { return false }
    do { try History.shared.moveCard(id, before: target, after: after); return true }
    catch { errorMessage = error.localizedDescription; return false }
  }

  func moveFavorite(_ tokens: [String], before target: UUID, after: Bool = false) -> Bool {
    guard History.shared.searchQuery.isEmpty, let token = tokens.first, token.hasPrefix("favorite:"),
          let id = UUID(uuidString: String(token.dropFirst(9))) else { return false }
    return change { try $0.moveEntry(id, before: target, after: after) }
  }

  func dropInFolder(_ tokens: [String], folderID: UUID?) -> Bool {
    guard let token = tokens.first else { return false }
    if token.hasPrefix("favorite:"), let id = UUID(uuidString: String(token.dropFirst(9))) {
      let success = change { try $0.moveToFolder(id, folderID: folderID) }
      if success { announce("已移动收藏") }
      return success
    }
    if token.hasPrefix("history:"), let id = UUID(uuidString: String(token.dropFirst(8))),
       let item = History.shared.items.first(where: { $0.id == id }) {
      bookmark(item, folderID: folderID)
      return true
    }
    return false
  }
}
