import ShelfCore
import SwiftUI

enum ShelfEditor: Identifiable, Equatable {
  case newFolder, renameFolder(UUID), newEntry, editEntry(UUID)
  var id: String { String(describing: self) }
  var isFolder: Bool { switch self { case .newFolder, .renameFolder: true; default: false } }
}

struct ShelfEditorView: View {
  let editor: ShelfEditor
  let shelf: ShelfState
  let dismiss: () -> Void
  @State private var name = ""
  @State private var text = ""
  @State private var folderID: UUID?
  @State private var error: String?
  @FocusState private var nameFocused: Bool

  private var entry: ShelfEntry? {
    if case .editEntry(let id) = editor { return shelf.entries.first { $0.id == id } }
    return nil
  }
  private var title: String {
    switch editor { case .newFolder: "新建文件夹"; case .renameFolder: "重命名文件夹"; case .newEntry: "添加收藏"; case .editEntry: "编辑收藏" }
  }
  private var editableText: Bool { entry == nil || entry?.canEditText == true }

  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      Text(title).font(.system(size: 20, weight: .semibold))
      Text(editor.isFolder ? "按项目或用途整理常用内容。" : "收藏独立保存，清空历史也不会丢失。")
        .font(.system(size: 12)).foregroundStyle(.secondary)
      TextField(editor.isFolder ? "文件夹名称" : "收藏名称", text: $name)
        .textFieldStyle(.roundedBorder).focused($nameFocused)
      if !editor.isFolder {
        if editableText {
          Text("网址或文字").font(.system(size: 11)).foregroundStyle(.secondary)
          TextEditor(text: $text).font(.system(size: 12)).frame(height: 110)
            .padding(6).background(.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.2)))
        } else { Label("保留原图片或文件内容", systemImage: "photo").font(.system(size: 12)).foregroundStyle(.secondary) }
        Picker("文件夹", selection: $folderID) {
          Text("未分类").tag(nil as UUID?)
          ForEach(shelf.folders) { Text($0.name).tag(Optional($0.id)) }
        }
      }
      if let error { Text(error).font(.system(size: 11)).foregroundStyle(.red) }
      HStack {
        Spacer()
        Button("取消", action: dismiss).keyboardShortcut(.cancelAction)
        Button("保存", action: save).keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
          .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }.padding(.top, 6)
    }.padding(26).frame(width: 420)
      .onAppear {
        folderID = shelf.currentFolderID
        if case .renameFolder(let id) = editor { name = shelf.folders.first { $0.id == id }?.name ?? "" }
        if let entry { name = entry.title; text = entry.text ?? ""; folderID = entry.folderID }
        nameFocused = true
      }
  }

  private func save() {
    var success = false
    switch editor {
    case .newFolder:
      var created: ShelfFolder?
      success = shelf.change { created = try $0.createFolder(name) }
      if let created { shelf.folderSelection = created.id.uuidString }
    case .renameFolder(let id): success = shelf.change { try $0.renameFolder(id, to: name) }
    case .newEntry, .editEntry:
      let contents: [ShelfContent]
      if !editableText, let entry { contents = entry.contents }
      else {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { error = "请输入收藏内容。"; return }
        contents = entry?.contentsForEditedText(text) ?? [.init(type: "public.utf8-plain-text", value: Data(text.utf8))]
      }
      success = shelf.change { try $0.saveEntry(id: entry?.id, title: name, contents: contents, folderID: folderID, application: entry?.application) }
    }
    if success { dismiss(); shelf.announce("已保存") }
    else { error = shelf.errorMessage; shelf.errorMessage = nil }
  }
}
