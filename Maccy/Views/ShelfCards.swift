import AppKit
import Defaults
import ShelfCore
import SwiftUI

struct ShelfHistoryCard: View {
  let item: HistoryItemDecorator
  let shelf: ShelfState
  let selected: Bool
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 6) {
        Image(systemName: item.hasImage ? "photo" : item.hasFileURLs ? "doc" : "doc.text")
        Text(item.application ?? "剪贴板").lineLimit(1)
        Spacer()
        Button { shelf.deleteHistory(item) } label: {
          Image(systemName: "xmark").font(.system(size: 9, weight: .medium)).frame(width: 20, height: 20)
        }.buttonStyle(.plain).help("删除记录").accessibilityLabel("删除记录")
      }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 12).frame(height: 34)
      Button {
        shelf.selectedHistoryID = item.id
        shelf.use(item.item, paste: !NSEvent.modifierFlags.contains(.option) && Defaults[.pasteByDefault])
      } label: {
        Group {
          if let image = item.item.image {
            Image(nsImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 8))
          } else if let url = shelf.webURL(item.item.text) {
            VStack(alignment: .leading, spacing: 9) {
              Text(url.host ?? "网址").font(.system(size: 18, weight: .semibold)).lineLimit(2)
              Text(url.absoluteString).font(.system(size: 10)).foregroundStyle(.blue).lineLimit(3)
            }.frame(maxWidth: .infinity, alignment: .leading)
          } else {
            Text(item.item.previewableText).font(.system(size: 12)).lineSpacing(4).lineLimit(5)
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.horizontal, 14).padding(.vertical, 10)
          .contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityLabel("粘贴：\(String(item.title.prefix(40)))")
      HStack {
        Text(item.item.lastCopiedAt, style: .relative).lineLimit(1)
        Spacer()
        Button { shelf.bookmark(item, folderID: shelf.currentFolderID) } label: { Label("收藏", systemImage: "pin") }
          .buttonStyle(.plain).help("添加到当前收藏文件夹")
      }.font(.system(size: 9)).foregroundStyle(.secondary).padding(.horizontal, 12).frame(height: 30)
        .overlay(alignment: .top) { Divider().opacity(0.25) }
    }
    .frame(width: 218, height: 193)
    .background(.white.opacity(scheme == .dark ? 0.055 : 0.37), in: RoundedRectangle(cornerRadius: 16))
    .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? .blue.opacity(0.7) : .white.opacity(0.35), lineWidth: 1))
    .shadow(color: .black.opacity(0.035), radius: 5, y: 2)
    .contextMenu {
      Button("仅复制") { shelf.use(item.item, paste: false) }
      Menu("收藏到") {
        Button("未分类") { shelf.bookmark(item) }
        ForEach(shelf.folders) { folder in Button(folder.name) { shelf.bookmark(item, folderID: folder.id) } }
      }
      Button("删除", role: .destructive) { shelf.deleteHistory(item) }
    }
  }
}

struct ShelfFavoriteCard: View {
  let entry: ShelfEntry
  let shelf: ShelfState
  let edit: () -> Void
  @Environment(\.colorScheme) private var scheme

  private var image: NSImage? {
    entry.contents.first { ["public.png", "public.tiff", "public.jpeg", "public.heic"].contains($0.type) }
      .flatMap { NSImage(data: $0.value) }
  }

  var body: some View {
    HStack(spacing: 9) {
      Group {
        if let image { Image(nsImage: image).resizable().scaledToFill() }
        else { Image(systemName: entry.webURL == nil ? "text.alignleft" : "link").foregroundStyle(.blue) }
      }.frame(width: 30, height: 30).background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
        .clipShape(RoundedRectangle(cornerRadius: 9))
      Button { shelf.use(shelf.historyItem(for: entry), paste: false) } label: {
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
          Text(entry.webURL?.host ?? (image == nil ? "文字片段" : "图片"))
            .font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
      }.buttonStyle(.plain).help("复制收藏内容")
      VStack(spacing: 10) {
        Button { shelf.deleteFavorite(entry) } label: { Image(systemName: "xmark").font(.system(size: 8)).frame(width: 16, height: 16) }
          .buttonStyle(.plain).help("删除收藏").accessibilityLabel("删除收藏")
        if entry.webURL != nil {
          Button { shelf.open(entry) } label: { Image(systemName: "arrow.up.right").font(.system(size: 10)) }
            .buttonStyle(.plain).help("在浏览器打开").accessibilityLabel("打开网址")
        }
      }.foregroundStyle(.secondary)
    }.padding(11).frame(width: 185, height: 64)
      .background(.white.opacity(scheme == .dark ? 0.055 : 0.22), in: RoundedRectangle(cornerRadius: 13))
      .overlay(RoundedRectangle(cornerRadius: 13).stroke(.white.opacity(0.25)))
      .contextMenu {
        Button("复制") { shelf.use(shelf.historyItem(for: entry), paste: false) }
        Button("粘贴") { shelf.use(shelf.historyItem(for: entry), paste: true) }
        if entry.webURL != nil { Button("打开网址") { shelf.open(entry) } }
        Button("编辑收藏…", action: edit)
        Menu("移动到文件夹") {
          Button("未分类") { shelf.change { try $0.moveToFolder(entry.id, folderID: nil) } }
          ForEach(shelf.folders) { folder in
            Button(folder.name) { shelf.change { try $0.moveToFolder(entry.id, folderID: folder.id) } }
          }
        }
        Divider()
        Button("删除收藏", role: .destructive) { shelf.deleteFavorite(entry) }
      }
  }
}
