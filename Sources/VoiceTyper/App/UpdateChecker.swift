import Foundation

/// Looks for a newer NeelSpeak release on GitHub. Only the public releases
/// API is contacted; nothing about the user or their dictations is sent.
enum UpdateChecker {
    struct Release: Equatable {
        let version: String
        let pageURL: URL
    }

    static let releasesPage = URL(string: "https://github.com/neelashkannan/neelSpeak/releases")!
    private static let latestReleaseAPI = URL(string: "https://api.github.com/repos/neelashkannan/neelSpeak/releases/latest")!

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// The latest published release if it is newer than this build, else nil.
    static func newerRelease(than version: String = currentVersion) async throws -> Release? {
        var request = URLRequest(url: latestReleaseAPI, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("NeelSpeak/\(version)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        let page = (json["html_url"] as? String).flatMap(URL.init(string:)) ?? releasesPage
        let remote = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return isVersion(remote, newerThan: version) ? Release(version: remote, pageURL: page) : nil
    }

    /// Numeric dotted-version comparison; pre-release suffixes ("1.2.0-beta") are ignored.
    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        func components(_ version: String) -> [Int] {
            let core = version.split(separator: "-", maxSplits: 1).first ?? ""
            return core.split(separator: ".").map { Int($0) ?? 0 }
        }
        let lhs = components(candidate)
        let rhs = components(current)
        for index in 0..<max(lhs.count, rhs.count) {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0
            if a != b { return a > b }
        }
        return false
    }
}
