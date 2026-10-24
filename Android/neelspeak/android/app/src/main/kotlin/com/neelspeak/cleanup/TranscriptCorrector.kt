package com.neelspeak.cleanup

/**
 * Deterministic fix-ups applied to every Parakeet transcript before the
 * optional LLM cleanup. Port of
 * Sources/VoiceTyper/Pipeline/TranscriptCorrector.swift — keep the passes,
 * vocabulary and behaviour in sync.
 *
 * Parakeet already punctuates and capitalises, so this deliberately leaves
 * ordinary prose alone — the space after a full stop, and everyday words such
 * as "point", "period", "dot" or "dash" are never touched. It only handles what
 * the model can't: spoken symbols ("at sign", "underscore"), a few spoken
 * punctuation commands ("comma", "question mark"), web addresses spoken as
 * "google dot com", and brand casing.
 */
object TranscriptCorrector {
    fun correct(text: String): String {
        var result = collapseWhitespace(text)
        if (result.isEmpty()) return result

        result = normalizeBrandNames(result)
        result = normalizeSpokenAddresses(result)
        result = normalizeSpokenSymbols(result)
        result = normalizeSpokenPunctuation(result)
        result = lowercaseDomains(result)

        return collapseWhitespace(result)
    }

    // Vocabulary

    private const val TOP_LEVEL_DOMAINS = "com|org|net|io|ai|dev|app|co|uk|us|in|me|edu|gov|info|tv|xyz"
    /** Endings that turn "<word> dot <ending>" into an address. Leaves out
     *  TLDs that are everyday words ("a red dot in the corner", "dot me"). */
    private const val SPOKEN_ADDRESS_ENDINGS = "com|org|net|io|ai|dev|app|edu|gov|uk|info|xyz"
    private const val FILE_EXTENSIONS = "pdf|txt|md|json|csv|swift|py|js|ts|html|css|png|jpg|jpeg|zip"

    /** Words that are never the first label of a spoken address, so
     *  "the dot com bubble" stays prose. */
    private val addressStopWords = setOf(
        "the", "a", "an", "this", "that", "my", "your", "our", "their", "his", "her", "its",
        "of", "in", "on", "at", "to", "and", "or", "for", "with", "from", "by", "is", "was",
    )

    private class Brand(val variants: String, val prose: String, val domainLabel: String)

    private val brands = listOf(
        Brand("""git\s+hub|get\s+hub|github""", "GitHub", "github"),
        Brand("""you\s+tube|u\s+tube|youtube""", "YouTube", "youtube"),
        Brand("""g\s+mail|gee\s+mail|gmail""", "Gmail", "gmail"),
        Brand("""open\s+a\s+i|open\s+ai|openai""", "OpenAI", "openai"),
        Brand("""chat\s+g\s*p\s*t|chat\s*gpt""", "ChatGPT", "chatgpt"),
        Brand("""stack\s+over\s*flow""", "Stack Overflow", "stackoverflow"),
        Brand("""neel\s*speak|neil\s*speak""", "NeelSpeak", "neelspeak"),
    )

    /** Neighbours that mean a bare "slash", "underscore" or "hyphen" is being
     *  used as a word ("plan to slash prices"), not dictated as a symbol. */
    private val symbolStopWords = setOf(
        "the", "a", "an", "to", "of", "in", "on", "at", "for", "with", "by", "from", "and", "or", "but",
        "not", "no", "this", "that", "these", "those", "it", "its", "we", "they", "you", "i", "he", "she",
        "our", "their", "my", "your", "his", "her", "should", "would", "could", "can", "will", "shall",
        "may", "might", "must", "do", "does", "did", "is", "are", "was", "were", "be", "been", "also",
        "further", "really", "just", "then", "there", "here", "very",
    )

    /** Mail providers Parakeet sometimes glues onto "at sign": "at signgmail.com". */
    private const val MAIL_PROVIDERS = "gmail|googlemail|outlook|hotmail|live|yahoo|icloud|me|mac|proton|protonmail|aol"

    // Passes

    // [\s\p{Z}] so non-breaking and other Unicode spaces collapse on the JVM
    // too (ICU's \s already includes them on-device and on macOS).
    private val whitespace = Regex("""[\s\p{Z}]+""")

    private fun collapseWhitespace(text: String): String =
        text.replace(whitespace, " ").trim()

    private fun normalizeBrandNames(text: String): String {
        var result = text
        val domainFollows = """(?=(?:\s*\.\s*|\s+dot\s+)(?:$SPOKEN_ADDRESS_ENDINGS)\b)"""
        for (brand in brands) {
            result = replace("""\b(?:${brand.variants})$domainFollows""", result) { brand.domainLabel }
            result = replace("""\b(?:${brand.variants})\b""", result) { brand.prose }
        }
        return result
    }

    private val dotSeparator = Regex("""\s+dot\s+""", RegexOption.IGNORE_CASE)

    private fun normalizeSpokenAddresses(text: String): String {
        var result = text

        // Misheard ".com" endings: "google dot calm", "see o m".
        result = replace("""\bdot\s+(?:c\s+o\s+m|see\s+o\s+m|calm|comm|come|comb|kom|con)\b""", result) { "dot com" }
        // Trailing boundary spelled out as a lookahead: the JVM's \b is
        // ASCII-only, ICU's (Android, macOS) is Unicode-aware.
        result = replace("""(?:γκουγκλ|γουγλ)\s*(?:\.|τελεία)\s*(?:κομ|com)(?![\p{L}\p{N}_])""", result) { "google.com" }

        // "docs dot python dot org" → "docs.python.org"
        val suffixes = "$SPOKEN_ADDRESS_ENDINGS|$FILE_EXTENSIONS"
        result = replace("""\b[A-Za-z0-9][A-Za-z0-9-]*(?:\s+dot\s+[A-Za-z0-9-]+)*\s+dot\s+(?:$suffixes)\b""", result) { match ->
            val firstLabel = match.takeWhile { !it.isWhitespace() }.lowercase()
            if (firstLabel in addressStopWords) match else match.replace(dotSeparator, ".")
        }

        // Parakeet sometimes writes the address as a sentence break: "google. Com".
        result = replace("""\b([A-Za-z0-9-]+)\s*\.\s+com\b""", result) { match ->
            val label = match.takeWhile { it != '.' && !it.isWhitespace() }
            "$label.com"
        }
        result = replace("""\b(?:goggle|googol|googel|gugal|gooble)\.com\b""", result) { "google.com" }
        result = replace("""\b([A-Za-z0-9][A-Za-z0-9-]{1,62})\.(?:calm|comm|come|comb|kom|con)\b""", result) { match ->
            val label = match.takeWhile { it != '.' }
            "$label.com"
        }
        return result
    }

    /** Spoken symbols join the words on either side: "john at sign gmail.com" → "john@gmail.com". */
    private fun normalizeSpokenSymbols(text: String): String {
        // Unambiguous phrases always become symbols.
        val symbols = listOf(
            """\s*\bat\s+(?:sign|symbol)\s*(?=(?:$MAIL_PROVIDERS)\.)""" to "@",
            """\s*\bat\s+(?:sign|symbol)\b\s*""" to "@",
            """\s*\bback\s*slash\b\s*""" to "\\",
            """\s*\bforward\s+slash\b\s*""" to "/",
            """\s*\bampersand\b\s*""" to " & ",
        )
        var result = text
        for ((pattern, symbol) in symbols) {
            result = replace(pattern, result) { symbol }
        }

        // "slash", "underscore" and "hyphen" are also ordinary words, so only
        // join two neighbours when neither is a function word:
        // "user underscore name" → "user_name", but "plan to slash prices" stays.
        for ((word, symbol) in ambiguousSymbols) {
            // Repeat so chains like "a underscore b underscore c" fully join.
            for (pass in 0 until 4) {
                val next = word.replace(result) { m ->
                    val left = m.groupValues[1]
                    val right = m.groupValues[2]
                    val isWord = left.lowercase() in symbolStopWords || right.lowercase() in symbolStopWords
                    if (isWord) m.value else left + symbol + right
                }
                if (next == result) break
                result = next
            }
        }
        return result
    }

    // Case-sensitive, like the Swift original's replaceGroups default.
    private val ambiguousSymbols = listOf("slash" to "/", "underscore" to "_", "hyphen" to "-").map { (word, symbol) ->
        Regex("""([\p{L}\p{N}][\p{L}\p{N}._@/-]*)\s+$word\s+([\p{L}\p{N}][\p{L}\p{N}._@/-]*)""") to symbol
    }

    private class PunctuationCommand(val words: String, val symbol: String, val endsSentence: Boolean)

    private val punctuationCommands = listOf(
        PunctuationCommand("""comma""", ",", false),
        PunctuationCommand("""semi\s*colon""", ";", false),
        PunctuationCommand("""question\s+mark""", "?", true),
        PunctuationCommand("""exclamation\s+(?:mark|point)""", "!", true),
    )

    /** "Hello comma how are you question mark i'm fine" → "Hello, how are you? I'm fine".
     *  Any punctuation Parakeet already put around the spoken word is absorbed. */
    private fun normalizeSpokenPunctuation(text: String): String {
        var result = text
        for (command in punctuationCommands) {
            // Case-sensitive so \p{Ll} only captures a lowercase letter to capitalise.
            val pattern = """\s*[,;:.!?]?\s*\b(?i:${command.words})\b(?!-)[,;:.!?]?(\s+\p{Ll})?"""
            result = Regex(pattern).replace(result) { match ->
                val tail = match.groups[1]?.value ?: return@replace command.symbol
                val letter = tail.trim()
                command.symbol + " " + if (command.endsSentence) letter.uppercase() else letter
            }
        }
        return result
    }

    private fun lowercaseDomains(text: String): String =
        replace("""\b[A-Za-z0-9][A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.(?:$TOP_LEVEL_DOMAINS)\b""", text) { it.lowercase() }

    // Regex helper

    private val cache = HashMap<String, Regex>()

    /** Case-insensitive regex replace where each match is rewritten by [transform]. */
    private fun replace(pattern: String, text: String, transform: (String) -> String): String {
        val regex = synchronized(cache) {
            cache.getOrPut(pattern) { Regex(pattern, RegexOption.IGNORE_CASE) }
        }
        return regex.replace(text) { transform(it.value) }
    }
}
