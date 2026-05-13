import Foundation
import FluidAudio

actor WhisperService {
    enum LoadState { case unloaded, downloading(Double), loading, ready, failed(String) }

    private(set) var state: LoadState = .unloaded
    private var asrManager: AsrManager?
    private var asrDecoderState: TdtDecoderState?
    private var loadedModelID: String?

    func prepare(model: SpeechModelOption, progress: @escaping @Sendable (Double) -> Void) async {
        if case .ready = state, loadedModelID == model.id { return }
        if case .loading = state { return }
        if case .downloading = state { return }

        switch model.runtime {
        case .fluidAudioParakeet:
            await prepareParakeet(model: model, progress: progress)
        case .whisperKit:
            state = .failed("WhisperKit is not bundled in this build. Please use Parakeet.")
        }
    }

    private func prepareParakeet(model: SpeechModelOption, progress: @escaping @Sendable (Double) -> Void) async {
        do {
            asrManager = nil
            asrDecoderState = nil
            loadedModelID = nil
            state = .downloading(0)
            progress(0)

            let targetDirectory = model.configuredFolderURL ?? SpeechModelCatalog.parakeetModelURL()
            let models = try await AsrModels.downloadAndLoad(
                to: targetDirectory,
                version: .v3,
                progressHandler: { downloadProgress in
                    progress(downloadProgress.fractionCompleted)
                }
            )

            state = .loading
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            asrManager = manager
            asrDecoderState = try TdtDecoderState(decoderLayers: models.version.decoderLayers)
            loadedModelID = model.id
            state = .ready
        } catch {
            state = .failed(String(describing: error))
        }
    }

    func transcribe(samples: [Float]) async -> String {
        guard case .ready = state else { return "" }
        guard !samples.isEmpty else { return "" }

        guard let asrManager else { return "" }
        do {
            var decoderState = try asrDecoderState ?? TdtDecoderState()
            let result = try await asrManager.transcribe(samples, decoderState: &decoderState)
            asrDecoderState = decoderState
            return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return ""
        }
    }
}
