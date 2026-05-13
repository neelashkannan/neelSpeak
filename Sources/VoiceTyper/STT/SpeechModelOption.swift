import Foundation

struct SpeechModelOption: Identifiable, Equatable {
    enum Runtime {
        case whisperKit
        case fluidAudioParakeet
    }

    let id: String
    let displayName: String
    let subtitle: String
    let runtime: Runtime
    let whisperVariant: String?
    let localFolderPath: String?
    let badge: String

    var isSupportedInCurrentBuild: Bool {
        switch runtime {
        case .whisperKit:
            return false
        case .fluidAudioParakeet:
            return true
        }
    }

    var isInstalled: Bool {
        guard let localFolderPath else { return false }
        guard FileManager.default.fileExists(atPath: localFolderPath) else { return false }
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: localFolderPath) else { return false }
        return files.contains { $0.hasSuffix(".mlmodelc") || $0 == "vocabulary.txt" || $0 == "vocab.json" }
    }

    var localFolderURL: URL? {
        guard let localFolderPath, FileManager.default.fileExists(atPath: localFolderPath) else { return nil }
        return URL(fileURLWithPath: localFolderPath)
    }

    var configuredFolderURL: URL? {
        guard let localFolderPath else { return nil }
        return URL(fileURLWithPath: localFolderPath)
    }
}

enum SpeechModelCatalog {
    static let parakeetModelFolderName = "parakeet-tdt-0.6b-v3"
    static let parakeetModelPath = "\(NSHomeDirectory())/Library/Application Support/NeelSpeak/Models/FluidAudio/\(parakeetModelFolderName)"

    static let parakeet = SpeechModelOption(
        id: "nvidia-parakeet-v3",
        displayName: "NVIDIA Parakeet V3",
        subtitle: "Local Parakeet TDT v3 via FluidAudio. Downloads into NeelSpeak's own model folder.",
        runtime: .fluidAudioParakeet,
        whisperVariant: nil,
        localFolderPath: parakeetModelPath,
        badge: FileManager.default.fileExists(atPath: parakeetModelPath) ? "Downloaded" : "Preferred"
    )

    static let whisperTurbo = SpeechModelOption(
        id: "whisper-large-v3-turbo",
        displayName: "Whisper Large V3 Turbo",
        subtitle: "Best supported model in this open-source WhisperKit build.",
        runtime: .whisperKit,
        whisperVariant: "openai_whisper-large-v3-v20240930_turbo",
        localFolderPath: nil,
        badge: "Works now"
    )

    static let whisperBase = SpeechModelOption(
        id: "whisper-base",
        displayName: "Whisper Base",
        subtitle: "Smaller download and faster first setup, with lower accuracy.",
        runtime: .whisperKit,
        whisperVariant: "openai_whisper-base",
        localFolderPath: nil,
        badge: "Small"
    )

    static let all: [SpeechModelOption] = [
        parakeet
    ]

    static let defaultSelectionID = parakeet.id
    static let currentBuildFallbackID = parakeet.id

    static func option(id: String) -> SpeechModelOption {
        all.first { $0.id == id } ?? parakeet
    }

    static func parakeetModelURL() -> URL {
        URL(fileURLWithPath: parakeetModelPath)
    }
}
