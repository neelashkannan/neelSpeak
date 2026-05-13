import Foundation

enum CleanupEngine: String, CaseIterable, Identifiable, Codable {
    case foundationModels
    case gemma

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .foundationModels: return "Apple Intelligence"
        case .gemma: return "Gemma 3 4B"
        }
    }

    var subtitle: String {
        switch self {
        case .foundationModels:
            return "Built into macOS 26. Instant, no download."
        case .gemma:
            return "Local 4-bit MLX model. ~2.5 GB on first use."
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

    var systemPrompt: String {
        switch self {
        case .off:
            return ""
        case .conservative:
            return Self.conservativePrompt
        case .aggressive:
            return Self.aggressivePrompt
        }
    }

    private static let conservativePrompt: String = """
    You clean up speech-to-text transcripts. Remove only:
    - filler words: um, uh, er, ah, like, you know, sort of, kind of, I mean
    - stutters and mid-word restarts (I-I, th-the, wa- wait)
    - exact word or short-phrase repetitions (the the cat -> the cat)
    - explicit course corrections: keep only the corrected phrase
      ("go to the store, I mean the market" -> "go to the market")

    Preserve everything else verbatim. Do not rephrase. Do not add words.
    Keep the speaker's original tone, slang, and capitalization style.
    Only adjust punctuation when removal would leave it stranded.
    Output ONLY the cleaned transcript with no preamble, no quotes, no commentary.

    Examples:

    Input: um so like I went to the the store yesterday you know
    Output: I went to the store yesterday.

    Input: I-I think we should go to the park, I mean the beach, today
    Output: I think we should go to the beach today.

    Input: send the email to John uh I mean to Sarah by Friday
    Output: send the email to Sarah by Friday.
    """

    private static let aggressivePrompt: String = """
    You clean up and lightly edit speech-to-text transcripts. Do everything in the
    conservative pass:
    - remove fillers (um, uh, like, you know, sort of, I mean)
    - remove stutters, mid-word restarts, exact repetitions
    - resolve course corrections (keep only the corrected phrase)

    AND additionally:
    - tighten run-on sentences with sensible punctuation
    - fix obvious grammar slips that come from spoken word order
    - prefer concise phrasing while preserving the speaker's meaning and voice

    Do NOT add information the speaker did not say. Do not invent details.
    Output ONLY the cleaned transcript with no preamble, no quotes, no commentary.

    Examples:

    Input: so I went to the store um and I was gonna get milk but like I forgot my wallet so I had to go back home
    Output: I went to the store to get milk, but I forgot my wallet, so I had to go back home.

    Input: the the meeting it's at three I think yeah three o'clock tomorrow
    Output: The meeting is at three o'clock tomorrow.
    """
}
