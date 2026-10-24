package com.neelspeak.cleanup

import org.junit.Assert.assertEquals
import org.junit.Test

/** Mirrors Tests/NeelSpeakTests/TranscriptCorrectorTests.swift case for case. */
class TranscriptCorrectorTest {
    private fun check(cases: List<Pair<String, String>>) {
        for ((input, expected) in cases) {
            assertEquals("input: \"$input\"", expected, TranscriptCorrector.correct(input))
        }
    }

    @Test
    fun leavesOrdinaryProseAlone() {
        check(
            listOf(
                "Hello world. This is a test.",
                "Are you there? Yes, I am.",
                "The point is that we need a period of rest.",
                "Note: call me at 3 - 4 pm.",
                "Add a dash of salt and dot the i's.",
                "The dot com bubble burst in 2000.",
                "I live in the U.K. now.",
                "Use a comma-separated list.",
                "Meet me at the station.",
                "We met at signal processing class.",
                "There is a red dot in the corner of the image.",
                "Put one dot in each box, then send me a text dot me later.",
                "They plan to slash prices next week.",
                "This should underscore the point.",
                "Use a hyphen there.",
            ).map { it to it }
        )
    }

    @Test
    fun formatsSpokenAddresses() {
        check(
            listOf(
                "go to google dot com" to "go to google.com",
                "email me at john at sign gmail dot com" to "email me at john@gmail.com",
                "open git hub dot com slash neelash" to "open github.com/neelash",
                "read docs dot python dot org" to "read docs.python.org",
                "Visit Google.com today." to "Visit google.com today.",
                "Check google. Com for it" to "Check google.com for it",
                "try goggle dot calm" to "try google.com",
                "the file is report underscore final dot pdf" to "the file is report_final.pdf",
                "ask on stack over flow dot com" to "ask on stackoverflow.com",
                "send it to John at signgmail.com before Friday?" to "send it to John@gmail.com before Friday?",
            )
        )
    }

    @Test
    fun normalizesBrandsAndSymbols() {
        check(
            listOf(
                "I use git hub and you tube every day." to "I use GitHub and YouTube every day.",
                "ask chat gpt or open ai" to "ask ChatGPT or OpenAI",
                "designer slash developer" to "designer/developer",
                "my handle is user underscore name underscore two" to "my handle is user_name_two",
                "see C colon back slash users" to "see C colon\\users",
                "a well hyphen known fact" to "a well-known fact",
                "Johnson ampersand Johnson" to "Johnson & Johnson",
                "a quick test of NeilSpeak today" to "a quick test of NeelSpeak today",
            )
        )
    }

    @Test
    fun convertsSpokenPunctuation() {
        check(
            listOf(
                "Hello comma how are you question mark i am fine" to "Hello, how are you? I am fine",
                "Hello, comma, how are you" to "Hello, how are you",
                "Hello comma John" to "Hello, John",
                "that is amazing exclamation mark" to "that is amazing!",
                "first semicolon second" to "first; second",
            )
        )
    }

    @Test
    fun collapsesWhitespaceAndHandlesEmpty() {
        assertEquals("hello there", TranscriptCorrector.correct("  hello   there  "))
        assertEquals("", TranscriptCorrector.correct("   "))
    }
}
