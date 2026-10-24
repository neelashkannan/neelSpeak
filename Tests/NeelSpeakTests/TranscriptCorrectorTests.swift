import Testing
@testable import VoiceTyper

struct TranscriptCorrectorTests {
    @Test(arguments: [
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
    ])
    func leavesOrdinaryProseAlone(_ text: String) {
        #expect(TranscriptCorrector.correct(text) == text)
    }

    @Test(arguments: [
        ("go to google dot com", "go to google.com"),
        ("email me at john at sign gmail dot com", "email me at john@gmail.com"),
        ("open git hub dot com slash neelash", "open github.com/neelash"),
        ("read docs dot python dot org", "read docs.python.org"),
        ("Visit Google.com today.", "Visit google.com today."),
        ("Check google. Com for it", "Check google.com for it"),
        ("try goggle dot calm", "try google.com"),
        ("the file is report underscore final dot pdf", "the file is report_final.pdf"),
        ("ask on stack over flow dot com", "ask on stackoverflow.com"),
        ("send it to John at signgmail.com before Friday?", "send it to John@gmail.com before Friday?"),
    ])
    func formatsSpokenAddresses(_ input: String, _ expected: String) {
        #expect(TranscriptCorrector.correct(input) == expected)
    }

    @Test(arguments: [
        ("I use git hub and you tube every day.", "I use GitHub and YouTube every day."),
        ("ask chat gpt or open ai", "ask ChatGPT or OpenAI"),
        ("designer slash developer", "designer/developer"),
        ("my handle is user underscore name underscore two", "my handle is user_name_two"),
        ("see C colon back slash users", "see C colon\\users"),
        ("a well hyphen known fact", "a well-known fact"),
        ("Johnson ampersand Johnson", "Johnson & Johnson"),
        ("a quick test of NeilSpeak today", "a quick test of NeelSpeak today"),
    ])
    func normalizesBrandsAndSymbols(_ input: String, _ expected: String) {
        #expect(TranscriptCorrector.correct(input) == expected)
    }

    @Test(arguments: [
        ("Hello comma how are you question mark i am fine", "Hello, how are you? I am fine"),
        ("Hello, comma, how are you", "Hello, how are you"),
        ("Hello comma John", "Hello, John"),
        ("that is amazing exclamation mark", "that is amazing!"),
        ("first semicolon second", "first; second"),
    ])
    func convertsSpokenPunctuation(_ input: String, _ expected: String) {
        #expect(TranscriptCorrector.correct(input) == expected)
    }

    @Test(arguments: [
        ("Um so I I think we should uh meet at 3.", "So I I think we should meet at 3."),
        ("Hmm, that works. Uh, see you then.", "That works. See you then."),
        ("The umbrella is under the hummingbird feeder.", "The umbrella is under the hummingbird feeder."),
        ("Call Herman, er, tomorrow.", "Call Herman, tomorrow."),
        ("We spent the night in the ER after the accident.", "We spent the night in the ER after the accident."),
        ("To err is human. The UM campus is big.", "To err is human. The UM campus is big."),
        ("iPhone sales rose at 9 a.m. today, e.g. the first.", "iPhone sales rose at 9 a.m. today, e.g. the first."),
        ("Um, the ER is on the left.", "The ER is on the left."),
        ("I said uh-huh.", "I said uh-huh."),
    ])
    func removesHesitationsBeforeCleanup(_ input: String, _ expected: String) {
        #expect(TranscriptCorrector.removeHesitations(input) == expected)
    }

    @Test func collapsesWhitespaceAndHandlesEmpty() {
        #expect(TranscriptCorrector.correct("  hello   there  ") == "hello there")
        #expect(TranscriptCorrector.correct("   ") == "")
    }
}
