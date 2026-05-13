import Foundation

enum CleanupEngine: String, CaseIterable, Identifiable, Codable {
    case foundationModels
    case gemma

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .foundationModels: return "Apple Intelligence"
        case .gemma: return "Gemma 3 1B"
        }
    }

    var subtitle: String {
        switch self {
        case .foundationModels:
            return "Built into macOS 26. Instant, no download."
        case .gemma:
            return "Local 4-bit MLX model. ~720 MB on first use."
        }
    }
}

enum CleanupMode: String, CaseIterable, Identifiable, Codable {
    case off
    case conservative
    case aggressive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .conservative: return "Conservative"
        case .aggressive: return "Aggressive"
        }
    }

    var subtitle: String {
        switch self {
        case .off:
            return "Type exactly what was said."
        case .conservative:
            return "Strip fillers, stutters, repetitions, and course corrections."
        case .aggressive:
            return "Also tighten phrasing and fix obvious spoken-word slips."
        }
    }

    /// Short directive sent as the system prompt. Few-shot examples are sent as
    /// proper user/assistant message turns instead (see `fewShotExamples`).
    var systemPrompt: String {
        switch self {
        case .off:
            return ""
        case .conservative:
            return """
            You are a strict speech-to-text cleaner. Given a transcript, output only the cleaned version. Remove filler words (um, uh, er, like, you know, sort of, I mean), stutters, mid-word restarts, exact repetitions, and explicit course corrections (keep only the corrected phrase). Do not rephrase. Do not add words. Do not add commentary. Output only the cleaned text.
            """
        case .aggressive:
            return """
            You are a speech-to-text editor. Given a transcript, output only the cleaned version. Remove filler words, stutters, repetitions, and course corrections. Also tighten run-on sentences with punctuation and fix obvious spoken-word grammar slips. Do not invent information. Do not add commentary. Output only the cleaned text.
            """
        }
    }

    /// Few-shot examples sent as user/assistant message pairs before the real input.
    /// Each tuple is (user transcript, expected cleaned output).
    var fewShotExamples: [(String, String)] {
        switch self {
        case .off:
            return []
        case .conservative:
            return [
                ("um so like I went to the the store yesterday you know",
                 "I went to the store yesterday."),
                ("I-I think we should go to the park, I mean the beach, today",
                 "I think we should go to the beach today.")
            ]
        case .aggressive:
            return [
                ("so I went to the store um and I was gonna get milk but like I forgot my wallet so I had to go back home",
                 "I went to the store to get milk, but I forgot my wallet, so I had to go back home."),
                ("the the meeting it's at three I think yeah three o'clock tomorrow",
                 "The meeting is at three o'clock tomorrow.")
            ]
        }
    }
}
