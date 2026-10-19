import AppKit
import Defaults
import ShelfCore
import SwiftUI

struct ContentView: View {
  @State private var shelf = ShelfState.shared
  @State private var history = History.shared
  @State private var editor: ShelfEditor?
  @State private var deletingFolder: ShelfFolder?
  @State private var clearHistory = false
  @State private var pasteAccess = AXIsProcessTrusted()
  @Default(.ignoreEvents) private var paused
  @FocusState private var searchFocused: Bool
  @Environment(\.colorScheme) private var scheme

  private var visibleHistory: [HistoryItemDecorator] { shelf.historyItems() }
  private var visibleFavorites: [ShelfEntry] { shelf.visibleEntries(query: history.searchQuery) }

  var body: some View {
    VStack(spacing: 0) {
      header
      favorites
      Divider().opacity(0.35)
      historyHeader
      historyCards
      footer
    }
    .background(LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.02 : 0.09), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
    .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(scheme == .dark ? 0.18 : 0.7), lineWidth: 1))
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .frame(minWidth: 600)
    .sheet(item: $editor) { target in
      ShelfEditorView(editor: target, shelf: shelf) { editor = nil }
    }
    .onChange(of: editor) { _, value in AppState.shared.isEditingItem = value != nil }
    .onChange(of: deletingFolder) { _, value in AppState.shared.isEditingItem = value != nil }
    .onChange(of: clearHistory) { _, value in AppState.shared.isEditingItem = value }
    .alert("删除文件夹？", isPresented: Binding(get: { deletingFolder != nil }, set: { if !$0 { deletingFolder = nil } })) {
      Button("取消", role: .cancel) { deletingFolder = nil }
      Button("删除文件夹", role: .destructive) {
        guard let folder = deletingFolder else { return }
        if shelf.change({ try $0.deleteFolder(folder.id) }) { shelf.folderSelection = "unfiled" }
        deletingFolder = nil
      }
    } message: { Text("里面的收藏会移到“未分类”，不会被删除。") }
    .alert("清空复制历史？", isPresented: $clearHistory) {
      Button("取消", role: .cancel) {}
      Button("清空历史", role: .destructive) { history.clear(); shelf.announce("历史已清空，收藏仍然保留") }
    } message: { Text("这会删除复制历史。常用收藏及文件夹不受影响。") }
    .alert("暂时无法完成", isPresented: Binding(get: { shelf.errorMessage != nil }, set: { if !$0 { shelf.errorMessage = nil } })) {
      Button("知道了") { shelf.errorMessage = nil }
    } message: { Text(shelf.errorMessage ?? "") }
    .onExitCommand { if editor == nil { AppState.shared.popup.close() } }
    .onKeyPress(keys: [.leftArrow, .rightArrow]) { press in
      guard !searchFocused, editor == nil else { return .ignored }
      let items = visibleHistory
      guard !items.isEmpty else { return .ignored }
      let current = items.firstIndex { $0.id == shelf.selectedHistoryID } ?? 0
      let next = min(max(0, current + (press.key == .rightArrow ? 1 : -1)), items.count - 1)
      shelf.selectedHistoryID = items[next].id
      return .handled
    }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
      pasteAccess = AXIsProcessTrusted()
      if editor == nil { searchFocused = true }
    }
  }

  private var header: some View {
    HStack(spacing: 20) {
      HStack(spacing: 9) {
        Image(systemName: "square.on.square")
          .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
          .frame(width: 30, height: 30)
          .background(LinearGradient(colors: [.blue.opacity(0.7), .blue], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 9))
        Text("沾沾").font(.system(size: 19, weight: .semibold))
      }
      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
        TextField("搜索复制记录或收藏…", text: $history.searchQuery)
          .textFieldStyle(.plain).focused($searchFocused)
          .onSubmit { pasteSelection() }
        if !history.searchQuery.isEmpty {
          Button { history.searchQuery = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain)
        }
      }
      .font(.system(size: 12)).padding(.horizontal, 12).frame(width: 310, height: 35)
      .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
      Spacer(minLength: 0)
      if !pasteAccess {
        Button("开启自动粘贴") { shelf.requestPastePermission() }.buttonStyle(.borderless).font(.system(size: 11))
      }
      Circle().fill(paused ? Color.orange : Color.green.opacity(0.7)).frame(width: 5, height: 5)
      Text(paused ? "已暂停记录" : "本地保存").font(.system(size: 10)).foregroundStyle(.secondary)
      Menu {
        Button("设置…") { AppState.shared.openPreferences() }
        Button("打开数据文件夹") {
          NSWorkspace.shared.open(URL.applicationSupportDirectory.appending(path: "ZhanZhan"))
        }
        Divider()
        Button("清空复制历史…", role: .destructive) { clearHistory = true }
        Divider()
        Button("关于沾沾") { AppState.shared.openAbout() }
        Button("退出沾沾") { NSApp.terminate(nil) }
      } label: { Image(systemName: "ellipsis.circle") }
      .menuStyle(.borderlessButton).fixedSize().help("设置与更多操作")
      Button { AppState.shared.popup.close() } label: {
        Image(systemName: "xmark").font(.system(size: 10, weight: .medium))
          .frame(width: 25, height: 25).background(.primary.opacity(0.04), in: Circle())
      }.buttonStyle(.plain).accessibilityLabel("收起面板")
    }.padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 14)
  }

  private var favorites: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label("常用收藏", systemImage: "pin").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 5) {
            folderChip("全部", id: "all", folder: nil)
            folderChip("未分类", id: "unfiled", folder: nil)
            ForEach(shelf.folders) { folder in
              folderChip(folder.name, id: folder.id.uuidString, folder: folder)
                .contextMenu {
                  Button("重命名文件夹") { editor = .renameFolder(folder.id) }
                  Button("删除文件夹…", role: .destructive) { deletingFolder = folder }
                }
            }
          }
        }
        Button { editor = .newFolder } label: { Image(systemName: "folder.badge.plus") }
          .buttonStyle(.borderless).help("新建文件夹").accessibilityLabel("新建文件夹")
        Button { editor = .newEntry } label: { Label("添加收藏", systemImage: "plus") }
          .buttonStyle(.borderless).font(.system(size: 11))
      }
      ScrollView(.horizontal) {
        HStack(spacing: 10) {
          if visibleFavorites.isEmpty {
            HStack(spacing: 10) {
              Image(systemName: "tray").font(.system(size: 19)).foregroundStyle(.tertiary)
              Text(history.searchQuery.isEmpty ? "把常用网址、提示词留下来。点击 + 添加，或把历史卡片拖到文件夹。" : "没有匹配的收藏")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            }.frame(height: 66)
          }
          ForEach(visibleFavorites) { entry in
            ShelfFavoriteCard(entry: entry, shelf: shelf, edit: { editor = .editEntry(entry.id) })
              .draggable("favorite:\(entry.id.uuidString)")
              .dropDestination(for: String.self) { tokens, point in shelf.moveFavorite(tokens, before: entry.id, after: point.x > 92) }
          }
        }.padding(.vertical, 3)
      }.frame(height: 83)
    }.padding(.horizontal, 24).padding(.bottom, 9)
  }

  private func folderChip(_ title: String, id: String, folder: ShelfFolder?) -> some View {
    Button { shelf.folderSelection = id } label: {
      HStack(spacing: 4) {
        if folder != nil { Image(systemName: "folder").font(.system(size: 10)) }
        Text(title).lineLimit(1)
      }
      .font(.system(size: 10, weight: shelf.folderSelection == id ? .semibold : .regular))
      .padding(.horizontal, 9).padding(.vertical, 5)
      .background(shelf.folderSelection == id ? Color.primary.opacity(0.09) : Color.clear, in: Capsule())
    }.buttonStyle(.plain)
      .dropDestination(for: String.self) { tokens, _ in
        guard id != "all" else { return false }
        return shelf.dropInFolder(tokens, folderID: folder?.id)
      }
  }

  private var historyHeader: some View {
    HStack {
      Picker("类型", selection: $shelf.filter) {
        ForEach(["全部", "文字", "图片", "链接", "文件"], id: \.self) { Text($0).tag($0) }
      }.pickerStyle(.segmented).labelsHidden().frame(width: 285)
      Spacer()
      if !history.searchQuery.isEmpty || shelf.filter != "全部" {
        Text("筛选时暂停排序").font(.system(size: 10)).foregroundStyle(.secondary)
      }
      Text("\(visibleHistory.count) 条记录").font(.system(size: 10)).foregroundStyle(.secondary)
    }.padding(.horizontal, 24).padding(.vertical, 13)
  }

  private var historyCards: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal) {
        LazyHStack(spacing: 13) {
          if visibleHistory.isEmpty {
            VStack(spacing: 10) {
              Image(systemName: "doc.on.clipboard").font(.system(size: 26)).foregroundStyle(.tertiary)
              Text(history.searchQuery.isEmpty ? "复制一段文字，记录就会出现在这里" : "没有找到匹配的记录")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            }.frame(width: 600, height: 193)
          }
          ForEach(visibleHistory) { item in
            ShelfHistoryCard(item: item, shelf: shelf,
                             selected: shelf.selectedHistoryID == item.id)
              .id(item.id)
              .draggable("history:\(item.id.uuidString)")
              .dropDestination(for: String.self) { tokens, point in shelf.moveHistory(tokens, before: item.id, after: point.x > 109) }
          }
        }.padding(.horizontal, 24).padding(.vertical, 4)
      }.frame(minHeight: 210)
      .onChange(of: shelf.selectedHistoryID) { _, id in if let id { withAnimation { proxy.scrollTo(id) } } }
    }
  }

  private var footer: some View {
    HStack(spacing: 14) {
      if !shelf.notice.isEmpty {
        Text(shelf.notice).lineLimit(2)
        if shelf.undoAction != nil { Button("撤销") { shelf.undo() }.buttonStyle(.borderless) }
      } else {
        Text("单击选中并复制 · 双击 / ↵ 粘贴").help("未获得辅助功能权限时只复制")
        Text("esc 收起")
        Label("拖动排序", systemImage: "hand.draw")
        Spacer()
        Text("三指下滑唤起 · 右键管理收藏")
      }
      Spacer(minLength: 0)
    }.font(.system(size: 10)).foregroundStyle(.secondary)
      .padding(.horizontal, 24).frame(height: 35)
      .overlay(alignment: .top) { Divider().opacity(0.3) }
  }

  private func pasteSelection() {
    if let id = shelf.selectedFavoriteID, let entry = visibleFavorites.first(where: { $0.id == id }) {
      shelf.use(shelf.historyItem(for: entry), paste: Defaults[.pasteByDefault])
      return
    }
    let item = visibleHistory.first { $0.id == shelf.selectedHistoryID } ?? visibleHistory.first
    if let item { shelf.use(item.item, paste: Defaults[.pasteByDefault]) }
  }
}
