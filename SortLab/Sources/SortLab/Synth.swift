import AVFoundation
import os

/// Tiny polyphonic sine-blip synth. Each blip is a sine with a smooth envelope so it never clicks.
final class Synth {
    private struct Voice {
        var phase: Double
        var inc: Double
        var age: Int
        var life: Int
        var amp: Float
    }

    private let engine = AVAudioEngine()
    private var node: AVAudioSourceNode!
    private let sampleRate: Double
    private let voices = OSAllocatedUnfairLock(initialState: [Voice]())

    var volume: Float = 0.5
    var muted = false

    init() {
        let out = engine.outputNode.outputFormat(forBus: 0)
        sampleRate = out.sampleRate > 0 ? out.sampleRate : 44100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        node = AVAudioSourceNode(format: format) { [voices, weak self] _, _, frames, abl in
            let buffers = UnsafeMutableAudioBufferListPointer(abl)
            let vol = (self?.muted ?? true) ? 0 : (self?.volume ?? 0)
            let n = Int(frames)
            guard let first = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            voices.withLock { vs in
                for f in 0..<n {
                    var sum: Float = 0
                    for k in vs.indices where vs[k].age < vs[k].life {
                        let env = sin(Float.pi * Float(vs[k].age) / Float(vs[k].life))
                        sum += Float(sin(vs[k].phase)) * env * vs[k].amp
                        vs[k].phase += vs[k].inc
                        if vs[k].phase > 2 * .pi { vs[k].phase -= 2 * .pi }
                        vs[k].age += 1
                    }
                    first[f] = sum * vol
                }
                vs.removeAll { $0.age >= $0.life }
            }
            for b in 1..<max(buffers.count, 1) {
                if let p = buffers[b].mData { memcpy(p, first, n * MemoryLayout<Float>.size) }
            }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    /// `fraction` 0...1 → 150 Hz ... 2400 Hz (four octaves), so taller line = higher pitch.
    func play(fraction: Double, duration: Double = 0.06) {
        guard !muted else { return }
        let freq = 150 * pow(2, 4 * fraction)
        let voice = Voice(phase: 0, inc: 2 * .pi * freq / sampleRate, age: 0,
                          life: max(64, Int(duration * sampleRate)), amp: 0.18)
        voices.withLock { vs in
            vs.append(voice)
            if vs.count > 12 { vs.removeFirst() }
        }
    }
}
