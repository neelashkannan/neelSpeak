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
            return "Grant permissions and download the speech model to start dictating."
        case .downloadingModel(let progress):
            return "Downloading the speech model (\(Int(progress * 100))%). This happens once."
        case .warming:
            return "Loading the speech model. The first launch after a download takes a little longer."
        case .idle:
            return "Hold the dictation key in any app, speak, and let go to paste."
        case .recording:
            return "Speak naturally. Let go to paste into the active app."
        case .transcribing:
            return "Turning your speech into text on this Mac."
        case .cleaning:
            return "Removing fillers, stutters, and course corrections before pasting."
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
