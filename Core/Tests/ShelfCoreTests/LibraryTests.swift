import Foundation
import ShelfCore

func foldersSurviveReloadAndDeletionKeepsContents() throws {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("library.json")
  defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
  var library = try ShelfLibrary(url: url)
  let folder = try library.createFolder("工作")
  let entry = try library.saveEntry(title: "网址", contents: [.init(type: "public.utf8-plain-text", value: Data("https://example.com".utf8))], folderID: folder.id)
  library = try ShelfLibrary(url: url)
  try check(library.entries.first?.folderID == folder.id)
  try library.deleteFolder(folder.id)
  library = try ShelfLibrary(url: url)
  try check(library.folders.isEmpty)
  try check(library.entries.first?.id == entry.id)
  try check(library.entries.first?.folderID == nil)
  try check(library.entries.first?.contents.first?.value == Data("https://example.com".utf8))
}

func imageSnapshotAndOrderSurviveReload() throws {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("library.json")
  defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
  var library = try ShelfLibrary(url: url)
  let a = try library.saveEntry(title: "图片", contents: [.init(type: "public.png", value: Data([1, 2, 3]))])
  let b = try library.saveEntry(title: "文字", contents: [.init(type: "public.utf8-plain-text", value: Data("hello".utf8))])
  try library.moveEntry(b.id, before: a.id)
  library = try ShelfLibrary(url: url)
  try check(library.entries.map(\.id) == [b.id, a.id])
  try check(library.entries.last?.contents.first?.value == Data([1, 2, 3]))
  try library.deleteEntry(a.id)
  try library.restoreEntry(a, at: 1)
  try check(try ShelfLibrary(url: url).entries.count == 2)
}

func invalidNamesAndDestinationsDoNotMutateLibrary() throws {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("library.json")
  defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
  var library = try ShelfLibrary(url: url)
  let folder = try library.createFolder("工作")
  try expectThrows { try library.createFolder(" 工作 ") }
  try expectThrows { try library.createFolder(" ") }
  let entry = try library.saveEntry(title: "文字", contents: [.init(type: "public.utf8-plain-text", value: Data("hello".utf8))])
  try expectThrows { try library.moveToFolder(entry.id, folderID: UUID()) }
  try library.moveToFolder(entry.id, folderID: folder.id)
  try library.renameFolder(folder.id, to: "项目")
  try check(library.folders.first?.name == "项目")
  try check(library.entries.first?.folderID == folder.id)
}

func corruptFileIsNotOverwritten() throws {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  let bad = Data("broken data".utf8)
  try bad.write(to: url)
  try expectThrows { try ShelfLibrary(url: url) }
  try check(try Data(contentsOf: url) == bad)
}

func failedWriteDoesNotChangeInMemoryState() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let url = root.appendingPathComponent("library.json")
  defer { try? FileManager.default.removeItem(at: root) }
  var library = try ShelfLibrary(url: url)
  try Data("a file cannot hold children".utf8).write(to: root)
  try expectThrows { try library.createFolder("不可保存") }
  try check(library.folders.isEmpty)
}

func historySnapshotsSurviveRestartAndRemainIndependent() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let historyURL = root.appendingPathComponent("History.json")
  var history = try HistoryArchive(url: historyURL)
  let a = HistoryRecord(title: "图片", rank: 1, contents: [.init(type: "public.png", value: Data([1, 2, 3]))])
  let b = HistoryRecord(title: "文字", rank: 2, contents: [.init(type: "public.utf8-plain-text", value: Data("hello".utf8))])
  try history.replace(with: [b, a])
  try check(try HistoryArchive(url: historyURL).records == [b, a])
  var favorites = try ShelfLibrary(url: root.appendingPathComponent("Favorites.json"))
  _ = try favorites.saveEntry(title: a.title, contents: a.contents)
  try history.replace(with: [])
  try check(try HistoryArchive(url: historyURL).records.isEmpty)
  try check(try ShelfLibrary(url: favorites.url).entries.first?.contents == a.contents)
  try history.replace(with: [a])
  try check(try HistoryArchive(url: historyURL).records == [a])
}

func historyFailureAndCorruptionAreProtected() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let url = root.appendingPathComponent("History.json")
  var history = try HistoryArchive(url: url)
  let a = HistoryRecord(title: "saved", contents: [.init(type: "public.utf8-plain-text", value: Data("hello".utf8))])
  try history.replace(with: [a])
  try FileManager.default.removeItem(at: root)
  try Data("blocked".utf8).write(to: root)
  try expectThrows { try history.replace(with: []) }
  try check(history.records == [a])
  try FileManager.default.removeItem(at: root)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  let corrupted = Data("corrupted".utf8)
  try corrupted.write(to: url)
  try expectThrows { try HistoryArchive(url: url) }
  try check(try Data(contentsOf: url) == corrupted)
  let futureVersion = Data("{\"version\":2,\"records\":[]}".utf8)
  try futureVersion.write(to: url)
  try expectThrows { try HistoryArchive(url: url) }
  try check(try Data(contentsOf: url) == futureVersion)
}

func editingAndForwardDragPreserveContents() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  var library = try ShelfLibrary(url: root.appendingPathComponent("Favorites.json"))
  let mixed: [ShelfContent] = [.init(type: "public.utf8-plain-text", value: Data("file".utf8)), .init(type: "public.file-url", value: Data("file:///test.png".utf8)), .init(type: "public.png", value: Data([1,2]))]
  let a = try library.saveEntry(title: "Mixed", contents: mixed)
  let b = try library.saveEntry(title: "Text", contents: [.init(type: "public.utf8-plain-text", value: Data("text".utf8)), .init(type: "public.html", value: Data("<b>text</b>".utf8))])
  try check(!a.canEditText)
  try check(a.contentsForEditedText("changed") == mixed)
  try check(b.contentsForEditedText("text") == b.contents)
  try check(b.contentsForEditedText("new") == [.init(type: "public.utf8-plain-text", value: Data("new".utf8))])
  try library.moveEntry(a.id, before: b.id, after: true)
  try check(library.entries.map(\.id) == [b.id,a.id])
  try check(try ShelfLibrary(url: library.url).entries.map(\.id) == [b.id,a.id])
  try library.moveEntry(a.id, before: b.id)
  try check(library.entries.map(\.id) == [a.id,b.id])
}

private struct TestFailure: Error { let message: String }
private func check(_ condition: @autoclosure () throws -> Bool, file: String = #fileID, line: Int = #line) throws {
  guard try condition() else { throw TestFailure(message: "Assertion failed at \(file):\(line)") }
}
private func expectThrows<T>(_ operation: () throws -> T) throws {
  do { _ = try operation() } catch { return }
  throw TestFailure(message: "Expected an error")
}
@main struct LibraryChecks {
  static func main() throws {
    let checks: [(String, () throws -> Void)] = [
      ("folders survive reload and deletion keeps contents", foldersSurviveReloadAndDeletionKeepsContents),
      ("image snapshot and order survive reload", imageSnapshotAndOrderSurviveReload),
      ("invalid names and destinations do not mutate", invalidNamesAndDestinationsDoNotMutateLibrary),
      ("corrupt file is not overwritten", corruptFileIsNotOverwritten),
      ("failed write leaves memory unchanged", failedWriteDoesNotChangeInMemoryState),
      ("history restart, undo and independent favorites", historySnapshotsSurviveRestartAndRemainIndependent),
      ("history protects failures, corruption and future versions", historyFailureAndCorruptionAreProtected),
      ("editing payload and forward drag", editingAndForwardDragPreserveContents)
    ]
    for (name, run) in checks { try run(); print("PASS: \(name)") }
    print("\(checks.count) checks passed")
  }
}
