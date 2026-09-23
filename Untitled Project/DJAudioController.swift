import AVFoundation
import Observation

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
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)!

    // AVPlayer instances for universal file playback (MP3, M4A, AAC, DASH, WAV, AIFF, etc.)
    private var leftFilePlayer: AVPlayer?
    private var rightFilePlayer: AVPlayer?
    private var leftLoopObserver: NSObjectProtocol?
    private var rightLoopObserver: NSObjectProtocol?

    private var leftTrackID: DJTrack.ID?
    private var rightTrackID: DJTrack.ID?
    private var isGraphConfigured = false
    private var echoEnabled = false
    private var currentLeftGain: Double = 0.85
    private var currentRightGain: Double = 0.85
    private var currentCrossfader: Double = 0.5

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
            try configureAudioSession()
            try configureGraphIfNeeded()
            try startEngineIfNeeded()
            currentLeftGain = leftGain
            currentRightGain = rightGain
            currentCrossfader = crossfader
            load(leftTrack, on: .left, isPlaying: leftIsPlaying)
            load(rightTrack, on: .right, isPlaying: rightIsPlaying)
            updateMix(leftGain: leftGain, rightGain: rightGain, crossfader: crossfader)
            updateEffects(filter: filter, reverbAmount: reverbAmount)
            errorMessage = nil
        } catch {
            errorMessage = "音訊啟動失敗：\(error.localizedDescription)"
        }
    }

    func load(_ track: DJTrack, on deck: Deck, isPlaying: Bool = false) {
        do {
            try configureAudioSession()
            try configureGraphIfNeeded()
            try startEngineIfNeeded()

            let player = playerNode(for: deck)
            let wasPlaying = player.isPlaying || isDeckPlaying(deck)

            player.stop()
            stopFilePlayer(for: deck)

            switch track.source {
            case .synth:
                let buffer = makeLoopBuffer(for: track)
                player.scheduleBuffer(buffer, at: nil, options: .loops)

            case .file(let url):
                let playerItem = AVPlayerItem(url: url)
                let filePlayer = AVPlayer(playerItem: playerItem)
                filePlayer.automaticallyWaitsToMinimizeStalling = false

                let loopObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: playerItem,
                    queue: .main
                ) { [weak filePlayer] _ in
                    filePlayer?.seek(to: .zero)
                    filePlayer?.play()
                }

                setFilePlayer(filePlayer, observer: loopObserver, for: deck)
                updateFilePlayerVolume(for: deck)
            }

            switch deck {
            case .left:
                leftTrackID = track.id
            case .right:
                rightTrackID = track.id
            }
            errorMessage = nil

            if isPlaying || wasPlaying {
                setPlaying(true, on: deck)
            }
        } catch {
            errorMessage = "載入音軌失敗：\(error.localizedDescription)"
        }
    }

    func reset(_ track: DJTrack, on deck: Deck) {
        if let filePlayer = filePlayer(for: deck) {
            filePlayer.seek(to: .zero)
        }
        load(track, on: deck)
    }

    func setPlaying(_ isPlaying: Bool, on deck: Deck) {
        do {
            try configureAudioSession()
            try configureGraphIfNeeded()
            try startEngineIfNeeded()
        } catch {
            errorMessage = "播放失敗：\(error.localizedDescription)"
            return
        }

        let player = playerNode(for: deck)
        let filePlayer = filePlayer(for: deck)

        if isPlaying {
            if let filePlayer {
                updateFilePlayerVolume(for: deck)
                filePlayer.play()
            } else {
                if !player.isPlaying {
                    player.play()
                }
            }
        } else {
            filePlayer?.pause()
            player.pause()
        }
        errorMessage = nil
    }

    private func isDeckPlaying(_ deck: Deck) -> Bool {
        switch deck {
        case .left:
            if let filePlayer = leftFilePlayer {
                return filePlayer.timeControlStatus == .playing || filePlayer.rate > 0
            }
            return leftPlayer.isPlaying
        case .right:
            if let filePlayer = rightFilePlayer {
                return filePlayer.timeControlStatus == .playing || filePlayer.rate > 0
            }
            return rightPlayer.isPlaying
        }
    }

    func updateMix(leftGain: Double, rightGain: Double, crossfader: Double) {
        currentLeftGain = leftGain
        currentRightGain = rightGain
        currentCrossfader = crossfader

        let clampedCF = max(0.0, min(1.0, crossfader))
        // Equal power / smooth crossfader curve: at center (0.5), both tracks remain at 100% volume
        let leftFade: Float = clampedCF <= 0.5 ? 1.0 : Float(max(0.0, 2.0 * (1.0 - clampedCF)))
        let rightFade: Float = clampedCF >= 0.5 ? 1.0 : Float(max(0.0, 2.0 * clampedCF))

        let leftVol = Float(leftGain) * leftFade
        let rightVol = Float(rightGain) * rightFade

        leftMixer.outputVolume = leftVol
        rightMixer.outputVolume = rightVol

        leftFilePlayer?.volume = leftVol
        rightFilePlayer?.volume = rightVol
    }

    private func updateFilePlayerVolume(for deck: Deck) {
        let clampedCF = max(0.0, min(1.0, currentCrossfader))
        let leftFade: Float = clampedCF <= 0.5 ? 1.0 : Float(max(0.0, 2.0 * (1.0 - clampedCF)))
        let rightFade: Float = clampedCF >= 0.5 ? 1.0 : Float(max(0.0, 2.0 * clampedCF))

        switch deck {
        case .left:
            leftFilePlayer?.volume = Float(currentLeftGain) * leftFade
        case .right:
            rightFilePlayer?.volume = Float(currentRightGain) * rightFade
        }
    }

    func updateEQ(low: Double, mid: Double, high: Double) {
        guard masterEQ.bands.count >= 3 else { return }

        let lowBand = masterEQ.bands[0]
        lowBand.filterType = .lowShelf
        lowBand.frequency = 180.0
        lowBand.gain = Float((low - 0.5) * 24.0)
        lowBand.bypass = false

        let midBand = masterEQ.bands[1]
        midBand.filterType = .parametric
        midBand.frequency = 1000.0
        midBand.bandwidth = 1.2
        midBand.gain = Float((mid - 0.5) * 18.0)
        midBand.bypass = false

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
        let vol: Float = isMuted ? 0 : 0.85
        mixerNode(for: deck).outputVolume = vol
        switch deck {
        case .left: leftFilePlayer?.volume = vol
        case .right: rightFilePlayer?.volume = vol
        }
    }

    func triggerDrop() { triggerSFX(.drop) }

    func triggerSFX(_ sfx: SFXType) {
        do {
            try configureAudioSession()
            try configureGraphIfNeeded()
            try startEngineIfNeeded()

            sfxPlayer.stop()
            let buffer: AVAudioPCMBuffer
            switch sfx {
            case .drop: buffer = makeDropBuffer()
            case .scratch: buffer = makeScratchBuffer()
            case .airhorn: buffer = makeAirhornBuffer()
            case .laser: buffer = makeLaserBuffer()
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

        engine.connect(leftPlayer, to: leftMixer, format: format)
        engine.connect(rightPlayer, to: rightMixer, format: format)
        engine.connect(sfxPlayer, to: sfxMixer, format: format)

        engine.connect(leftMixer, to: masterMixer, format: format)
        engine.connect(rightMixer, to: masterMixer, format: format)
        engine.connect(sfxMixer, to: masterMixer, format: format)

        engine.connect(masterMixer, to: masterEQ, format: format)
        engine.connect(masterEQ, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)

        leftMixer.outputVolume = 0.85
        rightMixer.outputVolume = 0.85
        sfxMixer.outputVolume = 0.95
        masterMixer.outputVolume = 1.0
        reverb.loadFactoryPreset(.mediumRoom)
        reverb.wetDryMix = 18

        engine.prepare()
        isGraphConfigured = true
    }

    private func configureAudioSession() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
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
        case .left: return leftPlayer
        case .right: return rightPlayer
        }
    }

    private func mixerNode(for deck: Deck) -> AVAudioMixerNode {
        switch deck {
        case .left: return leftMixer
        case .right: return rightMixer
        }
    }

    private func filePlayer(for deck: Deck) -> AVPlayer? {
        switch deck {
        case .left: return leftFilePlayer
        case .right: return rightFilePlayer
        }
    }

    private func setFilePlayer(_ player: AVPlayer?, observer: NSObjectProtocol?, for deck: Deck) {
        switch deck {
        case .left:
            if let obs = leftLoopObserver { NotificationCenter.default.removeObserver(obs) }
            leftFilePlayer?.pause()
            leftFilePlayer = player
            leftLoopObserver = observer
        case .right:
            if let obs = rightLoopObserver { NotificationCenter.default.removeObserver(obs) }
            rightFilePlayer?.pause()
            rightFilePlayer = player
            rightLoopObserver = observer
        }
    }

    private func stopFilePlayer(for deck: Deck) {
        switch deck {
        case .left:
            if let obs = leftLoopObserver { NotificationCenter.default.removeObserver(obs) }
            leftLoopObserver = nil
            leftFilePlayer?.pause()
            leftFilePlayer = nil
        case .right:
            if let obs = rightLoopObserver { NotificationCenter.default.removeObserver(obs) }
            rightLoopObserver = nil
            rightFilePlayer?.pause()
            rightFilePlayer = nil
        }
    }

    // MARK: - Synth Buffers

    private func makeLoopBuffer(for track: DJTrack) -> AVAudioPCMBuffer {
        let beatsPerLoop = 8.0
        let secondsPerBeat = 60.0 / Double(track.bpm)
        let loopDuration = beatsPerLoop * secondsPerBeat
        let frameCapacity = AVAudioFrameCount(loopDuration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)!
        buffer.frameLength = frameCapacity

        guard let channels = buffer.floatChannelData else { return buffer }
        let frameCount = Int(frameCapacity)
        let seed = Double(track.synthSeed)
        let sampleRate = format.sampleRate

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
        let frameCapacity = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)!
        buffer.frameLength = frameCapacity

        guard let channels = buffer.floatChannelData else { return buffer }
        let frameCount = Int(frameCapacity)
        let sampleRate = format.sampleRate

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
        let frameCapacity = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)!
        buffer.frameLength = frameCapacity

        guard let channels = buffer.floatChannelData else { return buffer }
        let frameCount = Int(frameCapacity)
        let sampleRate = format.sampleRate

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
        let frameCapacity = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)!
        buffer.frameLength = frameCapacity

        guard let channels = buffer.floatChannelData else { return buffer }
        let frameCount = Int(frameCapacity)
        let sampleRate = format.sampleRate

        for frame in 0..<frameCount {
            let progress = Double(frame) / Double(frameCount)
            let time = Double(frame) / sampleRate
            let env = pow(sin(progress * .pi), 0.5)

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
        let frameCapacity = AVAudioFrameCount(duration * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)!
        buffer.frameLength = frameCapacity

        guard let channels = buffer.floatChannelData else { return buffer }
        let frameCount = Int(frameCapacity)
        let sampleRate = format.sampleRate

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
