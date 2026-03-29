import Foundation

public final class CommitWAL: @unchecked Sendable {
    private let walURL: URL
    private let encoder = JSONEncoder()

    public init(root: URL) throws {
        let walDir = root.appendingPathComponent("wal", isDirectory: true)
        try FileManager.default.createDirectory(at: walDir, withIntermediateDirectories: true)
        walURL = walDir.appendingPathComponent("pending-commit.json")
    }

    public func writePending(_ envelopes: [EventEnvelope]) throws {
        let data = try encoder.encode(envelopes)
        try data.write(to: walURL, options: .atomic)
    }

    public func clear() throws {
        if FileManager.default.fileExists(atPath: walURL.path) {
            try FileManager.default.removeItem(at: walURL)
        }
    }

    public var hasPendingCommit: Bool {
        FileManager.default.fileExists(atPath: walURL.path)
    }
}
