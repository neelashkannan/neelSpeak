import Foundation

struct TranscriptEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    /// Transcript before AI cleanup, when cleanup changed it.
    let rawText: String?
    let date: Date
    let duration: TimeInterval

    init(result: DictationResult, date: Date = Date()) {
        id = UUID()
        text = result.text
        rawText = result.rawText
        self.date = date
        duration = result.audioDuration
    }
}

/// Persists dictation history to Application Support as JSON readable only by
/// the current user. Nothing leaves the Mac.
enum TranscriptHistoryStore {
    static let limit = 200

    static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NeelSpeak", isDirectory: true)
            .appendingPathComponent("History.json")
    }

    private static let queue = DispatchQueue(label: "neelspeak.history", qos: .utility)

    static func load() -> [TranscriptEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([TranscriptEntry].self, from: data)) ?? []
    }

    static func save(_ entries: [TranscriptEntry]) {
        queue.async {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(Array(entries.prefix(limit))) else { return }
            let url = fileURL
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: [.atomic])
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    }

    static func delete() {
        queue.async {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
