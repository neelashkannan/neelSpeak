import AppKit

/// Optional start/stop sounds for dictation.
@MainActor
final class SoundFeedback {
    var isEnabled = false

    private var previousState: DictationCoordinator.State = .setupRequired
    private var pendingStart: DispatchWorkItem?

    /// Matches the overlay's reveal delay so an Option shortcut that cancels
    /// the hold straight away stays silent.
    private static let startDelay: TimeInterval = 0.12

    func update(state: DictationCoordinator.State) {
        defer { previousState = state }
        guard isEnabled else { return }

        switch (previousState, state) {
        case (.idle, .recording):
            let start = DispatchWorkItem { Self.play("Tink") }
            pendingStart = start
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.startDelay, execute: start)
        case (.recording, .transcribing):
            pendingStart = nil
            Self.play("Pop")
        case (.recording, _):
            pendingStart?.cancel()
            pendingStart = nil
        default:
            break
        }
    }

    private static func play(_ name: String) {
        guard let sound = NSSound(named: NSSound.Name(name))?.copy() as? NSSound else { return }
        sound.volume = 0.35
        sound.play()
    }
}
