import AVFoundation
import Foundation

/// Headless entry point behind `NeelSpeak --transcribe`.
enum CommandLineTranscriber {
    static func run(arguments: [String]) -> Int32 {
        guard let path = arguments.first else {
            FileHandle.standardError.write(Data("usage: NeelSpeak --transcribe <audio-file> [--cleanup conservative|aggressive]\n".utf8))
            return 64
        }
        let mode = arguments.firstIndex(of: "--cleanup")
            .flatMap { arguments.indices.contains($0 + 1) ? CleanupMode(rawValue: arguments[$0 + 1]) : nil } ?? .off

        let samples: [Float]
        do {
            samples = try loadSamples(url: URL(fileURLWithPath: path))
        } catch {
            FileHandle.standardError.write(Data("Could not read \(path): \(error.localizedDescription)\n".utf8))
            return 66
        }

        let semaphore = DispatchSemaphore(value: 0)
        var status: Int32 = 0
        Task {
            let whisper = WhisperService()
            await whisper.prepare(model: SpeechModelCatalog.parakeet) { _ in }
            if case .failed(let message) = await whisper.state {
                FileHandle.standardError.write(Data("Model failed to load: \(message)\n".utf8))
                status = 70
                semaphore.signal()
                return
            }
            let started = Date()
            let raw = await whisper.transcribe(samples: samples)
            let corrected = TranscriptCorrector.correct(raw)
            print("raw:       \(raw)")
            print("corrected: \(corrected)")
            if mode != .off {
                let cleaner = LLMTranscriptCleaner()
                await cleaner.prepare { _ in }
                let result = await cleaner.clean(TranscriptCorrector.removeHesitations(corrected), mode: mode)
                print("cleaned:   \(result.text)")
                if let issue = result.issue { print("cleanup issue: \(issue)") }
            }
            print(String(format: "audio %.1fs, transcribed in %.2fs", Double(samples.count) / 16_000, Date().timeIntervalSince(started)))
            semaphore.signal()
        }
        semaphore.wait()
        return status
    }

    private static func loadSamples(url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let target = AudioEngine.targetFormat
        guard let converter = AVAudioConverter(from: file.processingFormat, to: target),
              let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try file.read(into: input)
        let capacity = AVAudioFrameCount(Double(input.frameLength) * target.sampleRate / file.processingFormat.sampleRate) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var supplied = false
        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, outStatus in
            if supplied {
                outStatus.pointee = .endOfStream
                return nil
            }
            supplied = true
            outStatus.pointee = .haveData
            return input
        }
        if let conversionError { throw conversionError }
        guard let channel = output.floatChannelData?[0] else { return [] }
        return Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
    }
}
