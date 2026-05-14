package com.neelspeak.cleanup

/**
 * Regex pipeline that normalizes Parakeet output before the LLM sees it.
 * Verbatim port of Sources/VoiceTyper/Pipeline/TranscriptCorrector.swift.
 */
object TranscriptCorrector {
    fun correct(text: String): String {
        var result = text.trim()
        if (result.isEmpty()) return result
        result = collapseWhitespace(result)
        result = normalizeSpokenSymbols(result)
        result = normalizeKnownBrandPhrases(result)
        result = normalizeDomainHomophones(result)
        result = normalizeDomainSpacing(result)
        return result.trim()
    }

    private fun collapseWhitespace(text: String): String =
        text.replace(Regex("\\s+"), " ")

    private fun normalizeSpokenSymbols(text: String): String {
        var r = text
        val replacements = listOf(
            "\\b(?:period|dot|point)\\b" to ".",
            "\\b(?:slash|forward slash)\\b" to "/",
            "\\bback slash\\b" to "\\\\",
            "\\bcolon\\b" to ":",
            "\\b(?:dash|hyphen)\\b" to "-",
            "\\bunderscore\\b" to "_",
            "\\b(?:at sign|at symbol)\\b" to "@",
            "\\bcomma\\b" to ",",
            "\\bquestion mark\\b" to "?",
            "\\bampersand\\b" to "&",
        )
        for ((pattern, replacement) in replacements) {
            r = r.replace(Regex(pattern, RegexOption.IGNORE_CASE), replacement)
        }
        return r
    }

    private fun normalizeKnownBrandPhrases(text: String): String {
        var r = text
        val replacements = listOf(
            "\\b(?:c o m|see o m)\\b" to "com",
            "\\b(?:g mail|gee mail)\\b" to "gmail",
            "\\b(?:you tube|u tube)\\b" to "youtube",
            "\\b(?:git hub|get hub)\\b" to "github",
            "\\b(?:stack overflow|stack over flow)\\b" to "stackoverflow",
            "\\b(?:open ai|open a i)\\b" to "openai",
            "\\b(?:chat g p t|chat gpt)\\b" to "chatgpt",
        )
        for ((pattern, replacement) in replacements) {
            r = r.replace(Regex(pattern, RegexOption.IGNORE_CASE), replacement)
        }
        return r
    }

    private fun normalizeDomainHomophones(text: String): String {
        var r = text
        val replacements = listOf(
            "\\b(?:goggle|googol|googel|gugal|gooble|google)\\s*(?:\\.|\\s+dot\\s+|\\s+period\\s+|\\s+point\\s+)\\s*(?:calm|comm|come|comb|kom|con|com)\\b" to "google.com",
            "\\b(?:g mail|gmail|gee mail)\\s*(?:\\.|\\s+dot\\s+|\\s+period\\s+|\\s+point\\s+)\\s*(?:calm|comm|come|comb|kom|con|com)\\b" to "gmail.com",
            "\\b(?:you tube|youtube|u tube)\\s*(?:\\.|\\s+dot\\s+|\\s+period\\s+|\\s+point\\s+)\\s*(?:calm|comm|come|comb|kom|con|com)\\b" to "youtube.com",
            "\\b(?:git hub|github|get hub)\\s*(?:\\.|\\s+dot\\s+|\\s+period\\s+|\\s+point\\s+)\\s*(?:calm|comm|come|comb|kom|con|com)\\b" to "github.com",
            "\\b(?:open ai|openai|open a i)\\s*(?:\\.|\\s+dot\\s+|\\s+period\\s+|\\s+point\\s+)\\s*(?:calm|comm|come|comb|kom|con|com)\\b" to "openai.com",
        )
        for ((pattern, replacement) in replacements) {
            r = r.replace(Regex(pattern, RegexOption.IGNORE_CASE), replacement)
        }
        return r
    }

    private fun normalizeDomainSpacing(text: String): String {
        var r = text
        r = r.replace(Regex("\\s*([./:@?&=_\\-])\\s*"), "$1")
        r = r.replace(
            Regex("(?i)\\b([a-z0-9][a-z0-9-]{1,62})\\.(calm|comm|come|comb|kom|con)\\b")
        ) { "${it.groupValues[1]}.com" }
        return r
    }
}
