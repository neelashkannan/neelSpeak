import AVFoundation
import Foundation

final class AudioEngine {
    private let engine = AVAudioEngine()
    private let targetSampleRate: Double = 16_000
    private var converter: AVAudioConverter?
    private var converterInputFormat: AVAudioFormat?

    private let bufferQueue = DispatchQueue(label: "neelspeak.audio.buffer")
    private var samples: [Float] = []
    private var capturing = false

    static let targetFormat: AVAudioFormat = {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!
    }()

    func start() throws {
        guard !capturing else { return }

        let input = engine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)

        if inputFormat.sampleRate != targetSampleRate || inputFormat.channelCount != 1 {
            converter = AVAudioConverter(from: inputFormat, to: Self.targetFormat)
            converterInputFormat = inputFormat
        } else {
            converter = nil
        }

        bufferQueue.sync { samples.removeAll(keepingCapacity: true) }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.handle(buffer: buffer)
        }

        engine.prepare()
        try engine.start()
        capturing = true
    }

    func stopAndDrain() -> [Float] {
        guard capturing else { return [] }
        capturing = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return bufferQueue.sync {
            let copy = samples
            samples.removeAll(keepingCapacity: true)
            return copy
        }
    }

    private func handle(buffer: AVAudioPCMBuffer) {
        let converted = convertIfNeeded(buffer: buffer)
        guard let channelData = converted.floatChannelData?[0] else { return }
        let frameCount = Int(converted.frameLength)
        let chunk = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        bufferQueue.async { [weak self] in
            self?.samples.append(contentsOf: chunk)
        }
    }

    private func convertIfNeeded(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard let converter = converter else { return buffer }

        // Output frame capacity scaled to the target sample rate.
        let ratio = targetSampleRate / buffer.format.sampleRate
        let outCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 16)
        guard let outBuffer = AVAudioPCMBuffer(
            pcmFormat: Self.targetFormat,
            frameCapacity: outCapacity
        ) else { return buffer }

        var supplied = false
        let status = converter.convert(to: outBuffer, error: nil) { _, outStatus in
            if supplied {
                outStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            outStatus.pointee = .haveData
            return buffer
        }

        if status == .error { return buffer }
        return outBuffer
    }
}
