import Foundation

enum TranscriptCorrector {
    static func correct(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return result }

        result = collapseWhitespace(result)
        result = normalizeSpokenSymbols(result)
        result = normalizeKnownBrandPhrases(result)
        result = normalizeDomainHomophones(result)
        result = normalizeDomainSpacing(result)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func collapseWhitespace(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
    }

    private static func normalizeSpokenSymbols(_ text: String) -> String {
        var result = text
        let replacements: [(String, String)] = [
            (#"\b(?:period|dot|point)\b"#, "."),
            (#"\b(?:slash|forward slash)\b"#, "/"),
            (#"\bback slash\b"#, "\\"),
            (#"\bcolon\b"#, ":"),
            (#"\b(?:dash|hyphen)\b"#, "-"),
            (#"\bunderscore\b"#, "_"),
            (#"\b(?:at sign|at symbol)\b"#, "@"),
            (#"\bcomma\b"#, ","),
            (#"\bquestion mark\b"#, "?"),
            (#"\bampersand\b"#, "&")
        ]

        for (pattern, replacement) in replacements {
            result = result.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return result
    }

    private static func normalizeKnownBrandPhrases(_ text: String) -> String {
        var result = text
        let replacements: [(String, String)] = [
            (#"\b(?:c o m|see o m)\b"#, "com"),
            (#"\b(?:g mail|gee mail)\b"#, "gmail"),
            (#"\b(?:you tube|u tube)\b"#, "youtube"),
            (#"\b(?:git hub|get hub)\b"#, "github"),
            (#"\b(?:stack overflow|stack over flow)\b"#, "stackoverflow"),
            (#"\b(?:open ai|open a i)\b"#, "openai"),
            (#"\b(?:chat g p t|chat gpt)\b"#, "chatgpt")
        ]

        for (pattern, replacement) in replacements {
            result = result.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return result
    }

    private static func normalizeDomainHomophones(_ text: String) -> String {
        var result = text
        let replacements: [(String, String)] = [
            (#"\b(?:γκουγκλ|γουγλ)\s*(?:\.|τελεία)\s*(?:κομ|com)\b"#, "google.com"),
            (#"\b(?:goggle|googol|googel|gugal|gooble|google)\s*(?:\.|\s+dot\s+|\s+period\s+|\s+point\s+)\s*(?:calm|comm|come|comb|kom|con|com)\b"#, "google.com"),
            (#"\b(?:g mail|gmail|gee mail)\s*(?:\.|\s+dot\s+|\s+period\s+|\s+point\s+)\s*(?:calm|comm|come|comb|kom|con|com)\b"#, "gmail.com"),
            (#"\b(?:you tube|youtube|u tube)\s*(?:\.|\s+dot\s+|\s+period\s+|\s+point\s+)\s*(?:calm|comm|come|comb|kom|con|com)\b"#, "youtube.com"),
            (#"\b(?:git hub|github|get hub)\s*(?:\.|\s+dot\s+|\s+period\s+|\s+point\s+)\s*(?:calm|comm|come|comb|kom|con|com)\b"#, "github.com"),
            (#"\b(?:open ai|openai|open a i)\s*(?:\.|\s+dot\s+|\s+period\s+|\s+point\s+)\s*(?:calm|comm|come|comb|kom|con|com)\b"#, "openai.com")
        ]

        for (pattern, replacement) in replacements {
            result = result.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return result
    }

    private static func normalizeDomainSpacing(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(
            of: #"\s*([./:@?&=_-])\s*"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?i)\b([a-z0-9][a-z0-9-]{1,62})\.(calm|comm|come|comb|kom|con)\b"#,
            with: "$1.com",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?i)\b([a-z0-9][a-z0-9-]{1,62})\.(com|org|net|io|ai|dev|app|edu|gov|co|us|uk)\b"#,
            with: "$1.$2",
            options: .regularExpression
        )
        return result
    }
}
