import Foundation

/// Deterministic fix-ups applied to every Parakeet transcript before the
/// optional LLM cleanup.
///
/// Parakeet already punctuates and capitalises, so this deliberately leaves
/// ordinary prose alone — the space after a full stop, and everyday words such
/// as "point", "period", "dot" or "dash" are never touched. It only handles what
/// the model can't: spoken symbols ("at sign", "underscore"), a few spoken
/// punctuation commands ("comma", "question mark"), web addresses spoken as
/// "google dot com", and brand casing.
enum TranscriptCorrector {
    static func correct(_ text: String) -> String {
        var result = collapseWhitespace(text)
        guard !result.isEmpty else { return result }

        result = normalizeBrandNames(result)
        result = normalizeSpokenAddresses(result)
        result = normalizeSpokenSymbols(result)
        result = normalizeSpokenPunctuation(result)
        result = lowercaseDomains(result)

        return collapseWhitespace(result)
    }

    /// Drops pure hesitation sounds (um, uh, er, hmm) before AI cleanup.
    /// These never carry meaning, and removing them up front gives the
    /// smaller on-device model less to get wrong. Matching is case-sensitive
    /// so "the ER" or "UM campus" survive, and "err" is a different word.
    static func removeHesitations(_ text: String) -> String {
        // A hesitation that opens a sentence (Parakeet capitalises it): drop it
        // and capitalise the word that now starts the sentence.
        var result = replaceGroups(#"(^|[.!?]\s+)(?:Um+|Uh+m*|Erm*|Hm+)[,.]?(?:\s+|$)(\p{Ll})?"#, in: text) { groups in
            (groups[1] ?? "") + (groups[2]?.uppercased() ?? "")
        }
        // Mid-sentence hesitations are lowercase.
        result = replace(#"\s+(?:um+|uh+m*|erm*|hm+)[,.]?(?=\s|$)"#, in: result, caseInsensitive: false) { _ in "" }
        return collapseWhitespace(result)
    }

    // MARK: - Vocabulary

    private static let topLevelDomains = "com|org|net|io|ai|dev|app|co|uk|us|in|me|edu|gov|info|tv|xyz"
    /// Endings that turn "<word> dot <ending>" into an address. Leaves out
    /// TLDs that are everyday words ("a red dot in the corner", "dot me").
    private static let spokenAddressEndings = "com|org|net|io|ai|dev|app|edu|gov|uk|info|xyz"
    private static let fileExtensions = "pdf|txt|md|json|csv|swift|py|js|ts|html|css|png|jpg|jpeg|zip"

    /// Words that are never the first label of a spoken address, so
    /// "the dot com bubble" stays prose.
    private static let addressStopWords: Set<String> = [
        "the", "a", "an", "this", "that", "my", "your", "our", "their", "his", "her", "its",
        "of", "in", "on", "at", "to", "and", "or", "for", "with", "from", "by", "is", "was"
    ]

    private struct Brand {
        let variants: String
        let prose: String
        let domainLabel: String
    }

    private static let brands: [Brand] = [
        Brand(variants: #"git\s+hub|get\s+hub|github"#, prose: "GitHub", domainLabel: "github"),
        Brand(variants: #"you\s+tube|u\s+tube|youtube"#, prose: "YouTube", domainLabel: "youtube"),
        Brand(variants: #"g\s+mail|gee\s+mail|gmail"#, prose: "Gmail", domainLabel: "gmail"),
        Brand(variants: #"open\s+a\s+i|open\s+ai|openai"#, prose: "OpenAI", domainLabel: "openai"),
        Brand(variants: #"chat\s+g\s*p\s*t|chat\s*gpt"#, prose: "ChatGPT", domainLabel: "chatgpt"),
        Brand(variants: #"stack\s+over\s*flow"#, prose: "Stack Overflow", domainLabel: "stackoverflow"),
        Brand(variants: #"neel\s*speak|neil\s*speak"#, prose: "NeelSpeak", domainLabel: "neelspeak")
    ]

    /// Neighbours that mean a bare "slash", "underscore" or "hyphen" is being
    /// used as a word ("plan to slash prices"), not dictated as a symbol.
    private static let symbolStopWords: Set<String> = [
        "the", "a", "an", "to", "of", "in", "on", "at", "for", "with", "by", "from", "and", "or", "but",
        "not", "no", "this", "that", "these", "those", "it", "its", "we", "they", "you", "i", "he", "she",
        "our", "their", "my", "your", "his", "her", "should", "would", "could", "can", "will", "shall",
        "may", "might", "must", "do", "does", "did", "is", "are", "was", "were", "be", "been", "also",
        "further", "really", "just", "then", "there", "here", "very"
    ]

    /// Mail providers Parakeet sometimes glues onto "at sign": "at signgmail.com".
    private static let mailProviders = "gmail|googlemail|outlook|hotmail|live|yahoo|icloud|me|mac|proton|protonmail|aol"

    // MARK: - Passes

    private static func collapseWhitespace(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeBrandNames(_ text: String) -> String {
        var result = text
        let domainFollows = #"(?=(?:\s*\.\s*|\s+dot\s+)(?:\#(spokenAddressEndings))\b)"#
        for brand in brands {
            result = replace(#"\b(?:\#(brand.variants))\#(domainFollows)"#, in: result) { _ in brand.domainLabel }
            result = replace(#"\b(?:\#(brand.variants))\b"#, in: result) { _ in brand.prose }
        }
        return result
    }

    private static func normalizeSpokenAddresses(_ text: String) -> String {
        var result = text

        // Misheard ".com" endings: "google dot calm", "see o m".
        result = replace(#"\bdot\s+(?:c\s+o\s+m|see\s+o\s+m|calm|comm|come|comb|kom|con)\b"#, in: result) { _ in "dot com" }
        result = replace(#"(?:γκουγκλ|γουγλ)\s*(?:\.|τελεία)\s*(?:κομ|com)\b"#, in: result) { _ in "google.com" }

        // "docs dot python dot org" → "docs.python.org"
        let suffixes = "\(spokenAddressEndings)|\(fileExtensions)"
        result = replace(#"\b[A-Za-z0-9][A-Za-z0-9-]*(?:\s+dot\s+[A-Za-z0-9-]+)*\s+dot\s+(?:\#(suffixes))\b"#, in: result) { match in
            let firstLabel = match.prefix { !$0.isWhitespace }.lowercased()
            guard !addressStopWords.contains(firstLabel) else { return match }
            return match.replacingOccurrences(
                of: #"\s+dot\s+"#,
                with: ".",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        // Parakeet sometimes writes the address as a sentence break: "google. Com".
        result = replace(#"\b([A-Za-z0-9-]+)\s*\.\s+com\b"#, in: result) { match in
            let label = match.prefix { $0 != "." && !$0.isWhitespace }
            return "\(label).com"
        }
        result = replace(#"\b(?:goggle|googol|googel|gugal|gooble)\.com\b"#, in: result) { _ in "google.com" }
        result = replace(#"\b([A-Za-z0-9][A-Za-z0-9-]{1,62})\.(?:calm|comm|come|comb|kom|con)\b"#, in: result) { match in
            let label = match.prefix { $0 != "." }
            return "\(label).com"
        }
        return result
    }

    /// Spoken symbols join the words on either side: "john at sign gmail.com" → "john@gmail.com".
    private static func normalizeSpokenSymbols(_ text: String) -> String {
        // Unambiguous phrases always become symbols.
        let symbols: [(String, String)] = [
            (#"\s*\bat\s+(?:sign|symbol)\s*(?=(?:\#(mailProviders))\.)"#, "@"),
            (#"\s*\bat\s+(?:sign|symbol)\b\s*"#, "@"),
            (#"\s*\bback\s*slash\b\s*"#, "\\"),
            (#"\s*\bforward\s+slash\b\s*"#, "/"),
            (#"\s*\bampersand\b\s*"#, " & ")
        ]
        var result = text
        for (pattern, symbol) in symbols {
            result = replace(pattern, in: result) { _ in symbol }
        }

        // "slash", "underscore" and "hyphen" are also ordinary words, so only
        // join two neighbours when neither is a function word:
        // "user underscore name" → "user_name", but "plan to slash prices" stays.
        let ambiguous: [(String, String)] = [("slash", "/"), ("underscore", "_"), ("hyphen", "-")]
        for (word, symbol) in ambiguous {
            let pattern = #"([\p{L}\p{N}][\p{L}\p{N}._@/-]*)\s+\#(word)\s+([\p{L}\p{N}][\p{L}\p{N}._@/-]*)"#
            // Repeat so chains like "a underscore b underscore c" fully join.
            for _ in 0..<4 {
                let next = replaceGroups(pattern, in: result) { groups in
                    let left = groups[1] ?? "", right = groups[2] ?? ""
                    let isWord = symbolStopWords.contains(left.lowercased()) || symbolStopWords.contains(right.lowercased())
                    return isWord ? (groups[0] ?? "") : left + symbol + right
                }
                if next == result { break }
                result = next
            }
        }
        return result
    }

    /// "Hello comma how are you question mark i'm fine" → "Hello, how are you? I'm fine".
    /// Any punctuation Parakeet already put around the spoken word is absorbed.
    private static func normalizeSpokenPunctuation(_ text: String) -> String {
        let commands: [(words: String, symbol: String, endsSentence: Bool)] = [
            (#"comma"#, ",", false),
            (#"semi\s*colon"#, ";", false),
            (#"question\s+mark"#, "?", true),
            (#"exclamation\s+(?:mark|point)"#, "!", true)
        ]
        var result = text
        for command in commands {
            // Case-sensitive so \p{Ll} only captures a lowercase letter to capitalise.
            let pattern = #"\s*[,;:.!?]?\s*\b(?i:\#(command.words))\b(?!-)[,;:.!?]?(\s+\p{Ll})?"#
            result = replace(pattern, in: result, caseInsensitive: false) { match in
                guard let tailRange = match.range(of: #"\s+\p{Ll}$"#, options: .regularExpression) else {
                    return command.symbol
                }
                let letter = match[tailRange].trimmingCharacters(in: .whitespaces)
                return command.symbol + " " + (command.endsSentence ? letter.uppercased() : letter)
            }
        }
        return result
    }

    private static func lowercaseDomains(_ text: String) -> String {
        replace(#"\b[A-Za-z0-9][A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.(?:\#(topLevelDomains))\b"#, in: text) { $0.lowercased() }
    }

    // MARK: - Regex helper

    /// Regex replace where each match is rewritten by `transform`.
    private static func replace(
        _ pattern: String,
        in text: String,
        caseInsensitive: Bool = true,
        transform: (String) -> String
    ) -> String {
        replaceGroups(pattern, in: text, caseInsensitive: caseInsensitive) { transform($0[0] ?? "") }
    }

    /// Like `replace`, but `transform` receives the whole match (index 0) and
    /// each capture group (nil when the group didn't participate).
    private static func replaceGroups(
        _ pattern: String,
        in text: String,
        caseInsensitive: Bool = false,
        transform: ([String?]) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : []) else {
            assertionFailure("Bad TranscriptCorrector pattern: \(pattern)")
            return text
        }
        let ns = text as NSString
        var output = ""
        var cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            output += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let groups: [String?] = (0..<match.numberOfRanges).map { index in
                let range = match.range(at: index)
                return range.location == NSNotFound ? nil : ns.substring(with: range)
            }
            output += transform(groups)
            cursor = match.range.location + match.range.length
        }
        output += ns.substring(from: cursor)
        return output
    }
}
