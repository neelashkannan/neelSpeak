import Foundation
import FluidAudio
import WhisperKit

actor WhisperService {
    enum LoadState { case unloaded, downloading(Double), loading, ready, failed(String) }

    private(set) var state: LoadState = .unloaded
    private var kit: WhisperKit?
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
            await prepareWhisper(model: model, progress: progress)
        }
    }

    private func prepareParakeet(model: SpeechModelOption, progress: @escaping @Sendable (Double) -> Void) async {
        do {
            kit = nil
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

    private func prepareWhisper(model: SpeechModelOption, progress: @escaping @Sendable (Double) -> Void) async {
        do {
            kit = nil
            asrManager = nil
            asrDecoderState = nil
            loadedModelID = nil

            let folder: URL
            if let variant = model.whisperVariant {
                state = .downloading(0)
                progress(0)
                folder = try await WhisperKit.download(
                    variant: variant,
                    useBackgroundSession: true,
                    progressCallback: { downloadProgress in
                        let fraction = max(0, min(1, downloadProgress.fractionCompleted))
                        progress(fraction)
                    }
                )
            } else {
                throw WhisperError.modelsUnavailable("No local model folder or downloadable model variant is configured for \(model.displayName).")
            }

            state = .loading
            let config = WhisperKitConfig(
                model: model.whisperVariant,
                modelFolder: folder.path,
                verbose: false,
                logLevel: .error,
                prewarm: false,
                load: false,
                download: false
            )
            let pipeline = try await WhisperKit(config)
            try await pipeline.prewarmModels()
            try await pipeline.loadModels()
            kit = pipeline
            loadedModelID = model.id
            state = .ready
        } catch {
            state = .failed(String(describing: error))
        }
    }

    func transcribe(samples: [Float]) async -> String {
        guard case .ready = state else { return "" }
        guard !samples.isEmpty else { return "" }

        if let asrManager {
            do {
                var decoderState = try asrDecoderState ?? TdtDecoderState()
                let result = try await asrManager.transcribe(samples, decoderState: &decoderState)
                asrDecoderState = decoderState
                return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                return ""
            }
        }

        guard let kit else { return "" }
        do {
            let options = DecodingOptions(
                task: .transcribe,
                language: "en",
                temperature: 0.0,
                temperatureFallbackCount: 2,
                sampleLength: 224,
                usePrefillPrompt: true,
                skipSpecialTokens: true,
                withoutTimestamps: true
            )
            let results = try await kit.transcribe(audioArray: samples, decodeOptions: options)
            return results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return ""
        }
    }
}
