import Foundation

extension DictationCoordinator.State {
    var title: String {
        switch self {
        case .setupRequired:
            return "Setup required"
        case .downloadingModel:
            return "Downloading model"
        case .warming:
            return "Getting ready"
        case .idle:
            return "Ready"
        case .recording:
            return "Listening"
        case .transcribing:
            return "Transcribing"
        case .cleaning:
            return "Cleaning up"
        case .error:
            return "Needs attention"
        }
    }

    var detail: String {
        switch self {
        case .setupRequired:
            return "Finish permissions and choose a speech model before dictation starts."
        case .downloadingModel(let progress):
            return "Downloading speech model \(Int(progress * 100))%. Keep NeelSpeak open until this finishes."
        case .warming:
            return "Specializing and loading the speech model. This can take a moment after download."
        case .idle:
            return "Hold Option anywhere to dictate."
        case .recording:
            return "Speak naturally. Release to insert the text into the active app."
        case .transcribing:
            return "Converting speech to text and preparing to paste."
        case .cleaning:
            return "Local AI is removing fillers, stutters, and course corrections."
        case .error(let message):
            return message
        }
    }

    var symbolName: String {
        switch self {
        case .setupRequired:
            return "checklist"
        case .downloadingModel:
            return "arrow.down.circle.fill"
        case .warming:
            return "hourglass"
        case .idle:
            return "checkmark.circle.fill"
        case .recording:
            return "waveform"
        case .transcribing:
            return "text.bubble.fill"
        case .cleaning:
            return "wand.and.stars"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}
