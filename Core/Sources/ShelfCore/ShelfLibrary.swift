import Foundation

public struct ShelfContent: Codable, Equatable, Sendable {
  public var type: String
  public var value: Data
  public init(type: String, value: Data) { self.type = type; self.value = value }
}

public struct ShelfFolder: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var name: String
}

public struct ShelfEntry: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var title: String
  public var contents: [ShelfContent]
  public var folderID: UUID?
  public var application: String?
  public var createdAt: Date
  public var text: String? {
    contents.first { $0.type == "public.utf8-plain-text" }.flatMap { String(data: $0.value, encoding: .utf8) }
  }
  public var canEditText: Bool {
    let attachmentTypes = ["public.file-url", "public.png", "public.tiff", "public.jpeg", "public.heic", "com.adobe.pdf"]
    return text != nil && !contents.contains { attachmentTypes.contains($0.type) }
  }
  public func contentsForEditedText(_ edited: String) -> [ShelfContent] {
    guard canEditText, edited != text else { return contents }
    return [.init(type: "public.utf8-plain-text", value: Data(edited.utf8))]
  }
  public var webURL: URL? {
    guard let text, let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
          ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
    return url
  }
}

public enum ShelfError: LocalizedError {
  case invalidName, duplicateName, missingFolder, missingEntry, emptyContents, unsupportedVersion
  public var errorDescription: String? {
    switch self {
    case .invalidName: "请输入名称，最多 80 个字符。"
    case .duplicateName: "已经有同名文件夹，请换个名称。"
    case .missingFolder: "文件夹已不存在，请重新选择。"
    case .missingEntry: "这条收藏已不存在。"
    case .emptyContents: "收藏内容不能为空。"
    case .unsupportedVersion: "收藏数据来自更新版本，已保护原文件，请使用更新版本打开。"
    }
  }
}

public struct ShelfLibrary: Sendable {
  private struct Document: Codable, Sendable {
    var version = 1
    var folders: [ShelfFolder] = []
    var entries: [ShelfEntry] = []
  }
  private var document: Document
  public let url: URL
  public var folders: [ShelfFolder] { document.folders }
  public var entries: [ShelfEntry] { document.entries }

  public init(url: URL) throws {
    self.url = url
    if FileManager.default.fileExists(atPath: url.path) {
      document = try JSONDecoder().decode(Document.self, from: Data(contentsOf: url))
      guard document.version == 1 else { throw ShelfError.unsupportedVersion }
    } else { document = Document() }
  }

  @discardableResult
  public mutating func createFolder(_ name: String) throws -> ShelfFolder {
    let name = try validName(name)
    guard !folders.contains(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) else {
      throw ShelfError.duplicateName
    }
    let folder = ShelfFolder(id: UUID(), name: name)
    try transaction { $0.folders.append(folder) }
    return folder
  }

  public mutating func renameFolder(_ id: UUID, to name: String) throws {
    let name = try validName(name)
    guard let index = folders.firstIndex(where: { $0.id == id }) else { throw ShelfError.missingFolder }
    guard !folders.contains(where: { $0.id != id && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) else {
      throw ShelfError.duplicateName
    }
    try transaction { $0.folders[index].name = name }
  }

  public mutating func deleteFolder(_ id: UUID) throws {
    try transaction { draft in
      draft.folders.removeAll { $0.id == id }
      for index in draft.entries.indices where draft.entries[index].folderID == id {
        draft.entries[index].folderID = nil
      }
    }
  }

  @discardableResult
  public mutating func saveEntry(id: UUID? = nil, title: String, contents: [ShelfContent], folderID: UUID? = nil,
                                 application: String? = nil) throws -> ShelfEntry {
    let title = try validName(title)
    guard !contents.isEmpty, contents.contains(where: { !$0.value.isEmpty }) else { throw ShelfError.emptyContents }
    try validateFolder(folderID)
    if let id, !entries.contains(where: { $0.id == id }) { throw ShelfError.missingEntry }
    let entry = ShelfEntry(id: id ?? UUID(), title: title, contents: contents, folderID: folderID,
                           application: application, createdAt: entries.first { $0.id == id }?.createdAt ?? .now)
    try transaction { draft in
      if let index = draft.entries.firstIndex(where: { $0.id == entry.id }) { draft.entries[index] = entry }
      else { draft.entries.append(entry) }
    }
    return entry
  }

  public mutating func moveToFolder(_ id: UUID, folderID: UUID?) throws {
    try validateFolder(folderID)
    guard let index = entries.firstIndex(where: { $0.id == id }) else { throw ShelfError.missingEntry }
    try transaction { $0.entries[index].folderID = folderID }
  }

  public mutating func deleteEntry(_ id: UUID) throws {
    try transaction { $0.entries.removeAll { $0.id == id } }
  }

  public mutating func restoreEntry(_ entry: ShelfEntry, at index: Int) throws {
    guard !entries.contains(where: { $0.id == entry.id }) else { return }
    var restored = entry
    if let folderID = entry.folderID, !folders.contains(where: { $0.id == folderID }) { restored.folderID = nil }
    try transaction { $0.entries.insert(restored, at: min(max(0, index), $0.entries.count)) }
  }

  public mutating func moveEntry(_ id: UUID, before target: UUID, after: Bool = false) throws {
    guard id != target, entries.contains(where: { $0.id == target }),
          let from = entries.firstIndex(where: { $0.id == id }) else { return }
    try transaction { draft in
      let entry = draft.entries.remove(at: from)
      let targetIndex = draft.entries.firstIndex(where: { $0.id == target })!
      draft.entries.insert(entry, at: targetIndex + (after ? 1 : 0))
    }
  }

  private func validateFolder(_ id: UUID?) throws {
    if let id, !folders.contains(where: { $0.id == id }) { throw ShelfError.missingFolder }
  }
  private func validName(_ name: String) throws -> String {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, name.count <= 80 else { throw ShelfError.invalidName }
    return name
  }
  private mutating func transaction(_ mutate: (inout Document) -> Void) throws {
    var draft = document
    mutate(&draft)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(draft)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
    document = draft
  }
}
