import AVFoundation
import Observation

private enum AudioDecodeError: LocalizedError {
    case bufferAllocationFailed
    case converterUnavailable
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .bufferAllocationFailed:
            "無法建立音訊暫存區。"
        case .converterUnavailable:
            "這個音檔格式無法轉成播放格式。"
        case .conversionFailed:
            "音檔解碼後沒有可播放資料。"
        }
    }
}

@MainActor
@Observable
final class DJAudioController {
    enum Deck {
        case left
        case right
    }

    private let engine = AVAudioEngine()
    private let leftPlayer = AVAudioPlayerNode()
    private let rightPlayer = AVAudioPlayerNode()
    private let sfxPlayer = AVAudioPlayerNode()
    private let leftMixer = AVAudioMixerNode()
    private let rightMixer = AVAudioMixerNode()
    private let sfxMixer = AVAudioMixerNode()
    private let masterMixer = AVAudioMixerNode()
    private let masterEQ = AVAudioUnitEQ(numberOfBands: 3)
    private let reverb = AVAudioUnitReverb()
    private let sampleRate = 44_100.0

    private var leftTrackID: DJTrack.ID?
    private var rightTrackID: DJTrack.ID?
    private var isGraphConfigured = false
    private var echoEnabled = false
    private var decodedFileBuffers: [URL: AVAudioPCMBuffer] = [:]

    var isEngineRunning = false
    var errorMessage: String?
    var activeSFXName: String?

    func prepare(
        leftTrack: DJTrack,
        rightTrack: DJTrack,
        leftIsPlaying: Bool,
        rightIsPlaying: Bool,
        leftGain: Double,
        rightGain: Double,
        crossfader: Double,
        filter: Double,
        reverbAmount: Double
    ) {
        do {
            try configureGraphIfNeeded()
            try configureAudioSession()
            try startEngineIfNeeded()
            load(leftTrack, on: .left)
            load(rightTrack, on: .right)
            setPlaying(leftIsPlaying, on: .left)
            setPlaying(rightIsPlaying, on: .right)
            updateMix(leftGain: leftGain, rightGain: rightGain, crossfader: crossfader)
            updateEffects(filter: filter, reverbAmount: reverbAmount)
            errorMessage = nil
        } catch {
            errorMessage = "音訊啟動失敗：\(error.localizedDescription)"
        }
    }

    func load(_ track: DJTrack, on deck: Deck) {
        do {
            try configureGraphIfNeeded()
            let player = playerNode(for: deck)
            player.stop()

            switch track.source {
            case .synth:
                let buffer = makeLoopBuffer(for: track)
                player.scheduleBuffer(buffer, at: nil, options: .loops)
            case .file(let url):
                let buffer = try decodedBuffer(for: url)
                player.scheduleBuffer(buffer, at: nil)
            }

            switch deck {
            case .left:
                leftTrackID = track.id
            case .right:
                rightTrackID = track.id
            }
            errorMessage = nil
        } catch {
            errorMessage = "載入音軌失敗：\(error.localizedDescription)"
        }
    }

    func reset(_ track: DJTrack, on deck: Deck) {
        load(track, on: deck)
    }

    func setPlaying(_ isPlaying: Bool, on deck: Deck) {
        do {
            try configureGraphIfNeeded()
            try configureAudioSession()
            try startEngineIfNeeded()
        } catch {
            errorMessage = "播放失敗：\(error.localizedDescription)"
            return
        }

        let player = playerNode(for: deck)
        if isPlaying {
            if !player.isPlaying {
                do {
                    player.play()
                    errorMessage = nil
                } catch {
                    errorMessage = "播放失敗：\(error.localizedDescription)"
                }
            }
        } else {
            player.pause()
        }
    }

    func updateMix(leftGain: Double, rightGain: Double, crossfader: Double) {
        let leftFade = Float(1.0 - max(0.0, min(1.0, crossfader)))
        let rightFade = Float(max(0.0, min(1.0, crossfader)))
        leftMixer.outputVolume = Float(leftGain) * max(0.08, leftFade)
        rightMixer.outputVolume = Float(rightGain) * max(0.08, rightFade)
    }

    func updateEQ(low: Double, mid: Double, high: Double) {
        guard masterEQ.bands.count >= 3 else { return }

        // Low band
        let lowBand = masterEQ.bands[0]
        lowBand.filterType = .lowShelf
        lowBand.frequency = 180.0
        lowBand.gain = Float((low - 0.5) * 24.0)
        lowBand.bypass = false

        // Mid band
        let midBand = masterEQ.bands[1]
        midBand.filterType = .parametric
        midBand.frequency = 1000.0
        midBand.bandwidth = 1.2
        midBand.gain = Float((mid - 0.5) * 18.0)
        midBand.bypass = false

        // High band
        let highBand = masterEQ.bands[2]
        highBand.filterType = .highShelf
        highBand.frequency = 6000.0
        highBand.gain = Float((high - 0.5) * 20.0)
        highBand.bypass = false
    }

    func updateEffects(filter: Double, reverbAmount: Double) {
        let echoBoost = echoEnabled ? 28.0 : 0.0
        reverb.wetDryMix = Float(max(0.0, min(1.0, reverbAmount)) * 55 + echoBoost)
    }

    func setEchoEnabled(_ isEnabled: Bool, reverbAmount: Double) {
        echoEnabled = isEnabled
        updateEffects(filter: 0.58, reverbAmount: reverbAmount)
    }

    func cut(_ deck: Deck, isMuted: Bool) {
        mixerNode(for: deck).outputVolume = isMuted ? 0 : 0.75
    }

    func triggerDrop() {
        triggerSFX(.drop)
    }

    func triggerSFX(_ sfx: SFXType) {
        do {
            try configureGraphIfNeeded()
            try configureAudioSession()
            try startEngineIfNeeded()

            sfxPlayer.stop()
            let buffer: AVAudioPCMBuffer
            switch sfx {
            case .drop:
                buffer = makeDropBuffer()
            case .scratch:
                buffer = makeScratchBuffer()
            case .airhorn:
                buffer = makeAirhornBuffer()
            case .laser:
                buffer = makeLaserBuffer()
            }

            sfxPlayer.scheduleBuffer(buffer, at: nil)
            sfxPlayer.play()
            activeSFXName = sfx.rawValue
            errorMessage = nil
        } catch {
            errorMessage = "SFX 播放失敗：\(error.localizedDescription)"
        }
    }

    private func configureGraphIfNeeded() throws {
        guard !isGraphConfigured else { return }

        engine.attach(leftPlayer)
        engine.attach(rightPlayer)
        engine.attach(sfxPlayer)
        engine.attach(leftMixer)
        engine.attach(rightMixer)
        engine.attach(sfxMixer)
        engine.attach(masterMixer)
        engine.attach(masterEQ)
        engine.attach(reverb)

        let format = engineFormat
        try connect(leftPlayer, to: leftMixer, format: format)
        try connect(rightPlayer, to: rightMixer, format: format)
        try connect(sfxPlayer, to: sfxMixer, format: format)
        try connect(leftMixer, to: masterMixer, format: format)
        try connect(rightMixer, to: masterMixer, format: format)
        try connect(sfxMixer, to: masterMixer, format: format)
        try connect(masterMixer, to: masterEQ, format: format)
        try connect(masterEQ, to: reverb, format: format)
        try connect(reverb, to: engine.mainMixerNode, format: format)

        sfxMixer.outputVolume = 0.85
        reverb.loadFactoryPreset(.mediumRoom)
        reverb.wetDryMix = 18
        engine.prepare()
        isGraphConfigured = true
    }

    private func connect(_ sourceNode: AVAudioNode, to destinationNode: AVAudioNode, format: AVAudioFormat?) throws {
        try engine.connectNode(sourceNode, to: destinationNode, format: format)
    }

    private func configureAudioSession() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
        #endif
    }

    private func startEngineIfNeeded() throws {
        guard !engine.isRunning else {
            isEngineRunning = true
            return
        }
        try engine.start()
        isEngineRunning = true
    }

    private func playerNode(for deck: Deck) -> AVAudioPlayerNode {
        switch deck {
        case .left: leftPlayer
        case .right: rightPlayer
        }
    }

    private func mixerNode(for deck: Deck) -> AVAudioMixerNode {
        switch deck {
        case .left: leftMixer
        case .right: rightMixer
        }
    }

    private func decodedBuffer(for url: URL) throws -> AVAudioPCMBuffer {
        if let cachedBuffer = decodedFileBuffers[url] {
            return cachedBuffer
        }

        let file = try AVAudioFile(forReading: url)
        let inputFormat = file.processingFormat
        guard let inputBuffer = AVAudioPCMBuffer(
            pcmFormat: inputFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw AudioDecodeError.bufferAllocationFailed
        }
        try file.read(into: inputBuffer)

        let outputFormat = engineFormat
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioDecodeError.converterUnavailable
        }

        let sampleRateRatio = outputFormat.sampleRate / inputFormat.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * sampleRateRatio) + 1
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            throw AudioDecodeError.bufferAllocationFailed
        }

        var didProvideInput = false
        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .endOfStream
                return nil
            }

            didProvideInput = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        if let conversionError {
            throw conversionError
        }

        guard status != .error, outputBuffer.frameLength > 0 else {
            throw AudioDecodeError.conversionFailed
        }

        decodedFileBuffers[url] = outputBuffer
        return outputBuffer
    }

    private var engineFormat: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
    }

    private func makeLoopBuffer(for track: DJTrack) -> AVAudioPCMBuffer {
        let beatsPerLoop = 8.0
        let secondsPerBeat = 60.0 / Double(track.bpm)
        let loopDuration = beatsPerLoop * secondsPerBeat
        let frameCapacity = AVAudioFrameCount(loopDuration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: engineFormat, frameCapacity: frameCapacity)!
        buffer.frameLength = frameCapacity

        guard let channels = buffer.floatChannelData else { return buffer }
        let frameCount = Int(frameCapacity)
        let seed = Double(track.synthSeed)

        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            let beatPosition = time / secondsPerBeat
            let beatFraction = beatPosition - floor(beatPosition)
            let eighthFraction = (beatPosition * 2) - floor(beatPosition * 2)
            let barPosition = Int(floor(beatPosition)) % Int(beatsPerLoop)

            let kick = drumEnvelope(beatFraction, length: 0.24) * sin(2.0 * .pi * (56.0 + seed * 1.7) * time) * 0.82
            let clapHit = (barPosition == 2 || barPosition == 6) ? drumEnvelope(beatFraction, length: 0.12) : 0.0
            let clap = clapHit * deterministicNoise(frame + track.synthSeed * 97) * 0.22
            let hat = drumEnvelope(eighthFraction, length: 0.07) * deterministicNoise(frame + track.synthSeed * 211) * 0.12
            let bassGate = beatFraction < 0.5 ? 1.0 : 0.32
            let bassFrequency = 92.0 + Double((track.synthSeed % 5) * 9)
            let bass = sin(2.0 * .pi * bassFrequency * time) * 0.22 * bassGate
            let lead = sin(2.0 * .pi * (220.0 + seed * 18.0) * time + sin(time * 4.0) * 0.8) * 0.045
            let sample = Float((kick + clap + hat + bass + lead) * 0.72)

            channels[0][frame] = sample
            channels[1][frame] = sample * 0.92
        }

        return buffer
    }

    private func makeDropBuffer() -> AVAudioPCMBuffer {
        let duration = 1.2
        let frameCapacity = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: engineFormat, frameCapacity: frameCapacity)!
        buffer.frameLength = frameCapacity

        guard let channels = buffer.floatChannelData else { return buffer }
        let frameCount = Int(frameCapacity)

        for frame in 0..<frameCount {
            let progress = Double(frame) / Double(frameCount)
            let time = Double(frame) / sampleRate
            let pitch = 260.0 - progress * 190.0
            let envelope = pow(1.0 - progress, 1.8)
            let tone = sin(2.0 * .pi * pitch * time) * envelope * 0.65
            let sweep = deterministicNoise(frame * 17) * envelope * 0.08
            let sample = Float(tone + sweep)
            channels[0][frame] = sample
            channels[1][frame] = sample * 0.92
        }

        return buffer
    }

    private func makeScratchBuffer() -> AVAudioPCMBuffer {
        let duration = 0.65
        let frameCapacity = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: engineFormat, frameCapacity: frameCapacity)!
        buffer.frameLength = frameCapacity

        guard let channels = buffer.floatChannelData else { return buffer }
        let frameCount = Int(frameCapacity)

        for frame in 0..<frameCount {
            let progress = Double(frame) / Double(frameCount)
            let speedMod = sin(progress * .pi * 8.0) * 1.5
            let pitch = 450.0 + speedMod * 320.0
            let envelope = sin(progress * .pi)
            let tone = sin(2.0 * .pi * pitch * (Double(frame) / sampleRate)) * envelope * 0.5
            let noise = deterministicNoise(frame * 31) * envelope * 0.25
            let sample = Float(tone + noise)
            channels[0][frame] = sample
            channels[1][frame] = sample
        }

        return buffer
    }

    private func makeAirhornBuffer() -> AVAudioPCMBuffer {
        let duration = 0.85
        let frameCapacity = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: engineFormat, frameCapacity: frameCapacity)!
        buffer.frameLength = frameCapacity

        guard let channels = buffer.floatChannelData else { return buffer }
        let frameCount = Int(frameCapacity)

        for frame in 0..<frameCount {
            let progress = Double(frame) / Double(frameCount)
            let time = Double(frame) / sampleRate
            let env = pow(sin(progress * .pi), 0.5)

            // Multi-tone chord for reggae airhorn
            let f1 = sin(2.0 * .pi * 466.16 * time)
            let f2 = sin(2.0 * .pi * 587.33 * time)
            let f3 = sin(2.0 * .pi * 698.46 * time)
            let sample = Float((f1 + f2 + f3) * 0.28 * env)

            channels[0][frame] = sample
            channels[1][frame] = sample
        }

        return buffer
    }

    private func makeLaserBuffer() -> AVAudioPCMBuffer {
        let duration = 0.7
        let frameCapacity = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: engineFormat, frameCapacity: frameCapacity)!
        buffer.frameLength = frameCapacity

        guard let channels = buffer.floatChannelData else { return buffer }
        let frameCount = Int(frameCapacity)

        for frame in 0..<frameCount {
            let progress = Double(frame) / Double(frameCount)
            let time = Double(frame) / sampleRate
            let pitch = 300.0 + pow(progress, 2.0) * 2400.0
            let env = pow(1.0 - progress, 0.8)
            let tone = sin(2.0 * .pi * pitch * time) * env * 0.55
            let sample = Float(tone)

            channels[0][frame] = sample
            channels[1][frame] = sample
        }

        return buffer
    }

    private func drumEnvelope(_ phase: Double, length: Double) -> Double {
        guard phase < length else { return 0.0 }
        return pow(1.0 - phase / length, 3.0)
    }

    private func deterministicNoise(_ value: Int) -> Double {
        let hashed = (value &* 1_103_515_245 &+ 12_345) & 0x7fffffff
        return Double(hashed % 2_000) / 1_000.0 - 1.0
    }
}
