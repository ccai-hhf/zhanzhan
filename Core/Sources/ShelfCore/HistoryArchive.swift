import Foundation

public struct HistoryRecord: Codable, Equatable, Sendable {
  public var id: UUID
  public var application: String?
  public var firstCopiedAt: Date
  public var lastCopiedAt: Date
  public var numberOfCopies: Int
  public var pin: String?
  public var title: String
  public var rank: Double
  public var contents: [ShelfContent]

  public init(id: UUID = UUID(), application: String? = nil, firstCopiedAt: Date = .now,
              lastCopiedAt: Date = .now, numberOfCopies: Int = 1, pin: String? = nil,
              title: String, rank: Double = 0, contents: [ShelfContent]) {
    self.id = id; self.application = application; self.firstCopiedAt = firstCopiedAt
    self.lastCopiedAt = lastCopiedAt; self.numberOfCopies = numberOfCopies
    self.pin = pin; self.title = title; self.rank = rank; self.contents = contents
  }
}

/// A versioned atomic snapshot. Failed loads are never treated as an empty store.
public struct HistoryArchive: Sendable {
  private struct Document: Codable { var version = 1; var records: [HistoryRecord] }
  public private(set) var records: [HistoryRecord]
  public let url: URL

  public init(url: URL) throws {
    self.url = url
    if FileManager.default.fileExists(atPath: url.path) {
      let document = try JSONDecoder().decode(Document.self, from: Data(contentsOf: url))
      guard document.version == 1 else { throw ShelfError.unsupportedVersion }
      records = document.records
    } else { records = [] }
  }

  public mutating func replace(with records: [HistoryRecord]) throws {
    let data = try JSONEncoder().encode(Document(records: records))
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: [.atomic])
    self.records = records
  }
}
