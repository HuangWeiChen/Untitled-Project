import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var audioController = DJAudioController()
    @State private var importedTracks: [DJTrack] = []
    @State private var leftDeck = DJDeckState(track: DJTrack.samples[0], bpm: 124, pitch: 0.18, gain: 0.72, isPlaying: false)
    @State private var rightDeck = DJDeckState(track: DJTrack.samples[1], bpm: 128, pitch: 0.42, gain: 0.64, isPlaying: false)
    @State private var crossfader = 0.5
    @State private var filter = 0.58
    @State private var reverb = 0.34
    @State private var selectedPad = 2
    @State private var selectedTrack = DJTrack.samples[0].id
    @State private var boothLightsOn = true
    @State private var isImportingAudio = false
    @State private var importMessage: String?
    @State private var echoEngaged = false
    @State private var cutMuted = false

    private var tracks: [DJTrack] {
        DJTrack.samples + importedTracks
    }

    var body: some View {
        ZStack {
            DJAtmosphereBackground(isLit: boothLightsOn)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    DJHeader(
                        isLit: $boothLightsOn,
                        isAudioReady: audioController.isEngineRunning,
                        errorMessage: audioController.errorMessage,
                        importMessage: importMessage
                    )

                    DeckStage(
                        leftDeck: $leftDeck,
                        rightDeck: $rightDeck,
                        crossfader: $crossfader
                    )

                    MixerConsole(
                        filter: $filter,
                        reverb: $reverb,
                        leftGain: $leftDeck.gain,
                        rightGain: $rightDeck.gain,
                        selectedPad: $selectedPad,
                        onPadTrigger: triggerPad
                    )

                    TrackLibrary(
                        tracks: tracks,
                        selectedTrack: $selectedTrack,
                        onImport: { isImportingAudio = true },
                        onLoadLeft: loadSelectedTrackToLeftDeck,
                        onLoadRight: loadSelectedTrackToRightDeck
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 34)
            }
        }
        .tint(.cyan)
        .task {
            audioController.prepare(
                leftTrack: leftDeck.track,
                rightTrack: rightDeck.track,
                leftIsPlaying: leftDeck.isPlaying,
                rightIsPlaying: rightDeck.isPlaying,
                leftGain: leftDeck.gain,
                rightGain: rightDeck.gain,
                crossfader: crossfader,
                filter: filter,
                reverbAmount: reverb
            )
        }
        .fileImporter(
            isPresented: $isImportingAudio,
            allowedContentTypes: [.mp3, .mpeg4Audio, .wav, .aiff],
            allowsMultipleSelection: true,
            onCompletion: handleAudioImport
        )
        .onChange(of: leftDeck.isPlaying) { _, isPlaying in
            audioController.setPlaying(isPlaying, on: .left)
        }
        .onChange(of: rightDeck.isPlaying) { _, isPlaying in
            audioController.setPlaying(isPlaying, on: .right)
        }
        .onChange(of: leftDeck.gain) { _, _ in
            updateAudioMix()
        }
        .onChange(of: rightDeck.gain) { _, _ in
            updateAudioMix()
        }
        .onChange(of: crossfader) { _, _ in
            cutMuted = false
            updateAudioMix()
        }
        .onChange(of: filter) { _, value in
            audioController.updateEffects(filter: value, reverbAmount: reverb)
        }
        .onChange(of: reverb) { _, value in
            audioController.updateEffects(filter: filter, reverbAmount: value)
        }
    }

    private func loadSelectedTrackToLeftDeck() {
        guard let track = tracks.first(where: { $0.id == selectedTrack }) else { return }
        leftDeck.track = track
        leftDeck.bpm = track.bpm
        audioController.load(track, on: .left)
        audioController.setPlaying(leftDeck.isPlaying, on: .left)
    }

    private func loadSelectedTrackToRightDeck() {
        guard let track = tracks.first(where: { $0.id == selectedTrack }) else { return }
        rightDeck.track = track
        rightDeck.bpm = track.bpm
        audioController.load(track, on: .right)
        audioController.setPlaying(rightDeck.isPlaying, on: .right)
    }

    private func updateAudioMix() {
        audioController.updateMix(
            leftGain: leftDeck.gain,
            rightGain: rightDeck.gain,
            crossfader: crossfader
        )
    }

    private func triggerPad(_ pad: PadAction) {
        selectedPad = pad.rawValue

        switch pad {
        case .hot:
            leftDeck.isPlaying = true
            rightDeck.isPlaying = true
            crossfader = 0.5
            updateAudioMix()
        case .loop:
            audioController.reset(leftDeck.track, on: .left)
            audioController.reset(rightDeck.track, on: .right)
            audioController.setPlaying(leftDeck.isPlaying, on: .left)
            audioController.setPlaying(rightDeck.isPlaying, on: .right)
        case .fx:
            filter = 0.86
            reverb = min(1.0, reverb + 0.22)
            audioController.updateEffects(filter: filter, reverbAmount: reverb)
        case .drop:
            leftDeck.isPlaying = true
            rightDeck.isPlaying = true
            crossfader = 0.5
            audioController.triggerDrop()
        case .echo:
            echoEngaged.toggle()
            reverb = echoEngaged ? 0.82 : 0.34
            audioController.setEchoEnabled(echoEngaged, reverbAmount: reverb)
            audioController.updateEffects(filter: filter, reverbAmount: reverb)
        case .cut:
            cutMuted.toggle()
            audioController.cut(activeDeck, isMuted: cutMuted)
            if !cutMuted {
                updateAudioMix()
            }
        case .sync:
            rightDeck.bpm = leftDeck.bpm
            importMessage = "SYNC：Deck B 已對齊 Deck A 的 BPM 顯示。"
        case .cue:
            leftDeck.isPlaying = false
            rightDeck.isPlaying = false
            audioController.reset(leftDeck.track, on: .left)
            audioController.reset(rightDeck.track, on: .right)
        }
    }

    private var activeDeck: DJAudioController.Deck {
        crossfader > 0.5 ? .right : .left
    }

    private func handleAudioImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            let newTracks = try urls.map(makeImportedTrack)
            importedTracks.append(contentsOf: newTracks)
            if let first = newTracks.first {
                selectedTrack = first.id
            }
            importMessage = "已匯入 \(newTracks.count) 首音訊。"
        } catch {
            importMessage = "匯入失敗：\(error.localizedDescription)"
        }
    }

    private func makeImportedTrack(from sourceURL: URL) throws -> DJTrack {
        let shouldStopAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let copiedURL = try copyAudioIntoAppStorage(sourceURL)
        let metadata = audioMetadata(for: copiedURL)
        return DJTrack(
            title: copiedURL.deletingPathExtension().lastPathComponent,
            artist: "Imported MP3",
            duration: metadata.duration,
            bpm: metadata.bpm,
            color: DJTrack.importColors[(importedTracks.count + Int.random(in: 0...3)) % DJTrack.importColors.count],
            source: .file(copiedURL)
        )
    }

    private func copyAudioIntoAppStorage(_ sourceURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let importsURL = documentsURL.appendingPathComponent("Imported Audio", isDirectory: true)
        try fileManager.createDirectory(at: importsURL, withIntermediateDirectories: true)

        let cleanName = sourceURL.lastPathComponent.isEmpty ? "Imported.mp3" : sourceURL.lastPathComponent
        let destinationURL = importsURL.appendingPathComponent("\(UUID().uuidString)-\(cleanName)")
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    private func audioMetadata(for url: URL) -> (duration: String, bpm: Int) {
        guard let file = try? AVAudioFile(forReading: url) else {
            return ("--:--", 128)
        }

        let seconds = Double(file.length) / file.processingFormat.sampleRate
        let minutes = Int(seconds) / 60
        let remainder = Int(seconds) % 60
        let duration = String(format: "%02d:%02d", minutes, remainder)
        return (duration, 128)
    }
}

struct DJTrack: Identifiable, Equatable {
    let id: UUID
    let title: String
    let artist: String
    let duration: String
    let bpm: Int
    let color: Color
    let source: DJTrackSource

    var synthSeed: Int {
        switch source {
        case .synth(let seed): seed
        case .file: 17
        }
    }

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        duration: String,
        bpm: Int,
        color: Color,
        source: DJTrackSource
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.bpm = bpm
        self.color = color
        self.source = source
    }

    static let samples: [DJTrack] = [
        DJTrack(title: "Midnight Pulse", artist: "Neon Harbor", duration: "03:48", bpm: 124, color: .cyan, source: .synth(seed: 3)),
        DJTrack(title: "Glass Room", artist: "Mika Lane", duration: "04:12", bpm: 128, color: .pink, source: .synth(seed: 8)),
        DJTrack(title: "Afterglow Run", artist: "Tape Circuit", duration: "05:06", bpm: 122, color: .yellow, source: .synth(seed: 13)),
        DJTrack(title: "Signal Drift", artist: "East Terminal", duration: "03:35", bpm: 132, color: .green, source: .synth(seed: 21))
    ]

    static let importColors: [Color] = [.mint, .orange, .indigo, .teal, .red]
}

enum DJTrackSource: Equatable {
    case synth(seed: Int)
    case file(URL)
}

private enum PadAction: Int, CaseIterable, Identifiable {
    case hot
    case loop
    case fx
    case drop
    case echo
    case cut
    case sync
    case cue

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .hot: "HOT"
        case .loop: "LOOP"
        case .fx: "FX"
        case .drop: "DROP"
        case .echo: "ECHO"
        case .cut: "CUT"
        case .sync: "SYNC"
        case .cue: "CUE"
        }
    }

    var systemImage: String {
        switch self {
        case .hot: "flame.fill"
        case .loop: "repeat"
        case .fx: "sparkles"
        case .drop: "bolt.fill"
        case .echo: "dot.radiowaves.left.and.right"
        case .cut: "scissors"
        case .sync: "arrow.triangle.2.circlepath"
        case .cue: "record.circle"
        }
    }

    var color: Color {
        switch self {
        case .hot: .orange
        case .loop: .cyan
        case .fx: .pink
        case .drop: .yellow
        case .echo: .green
        case .cut: .red
        case .sync: .cyan
        case .cue: .pink
        }
    }
}

private struct DJDeckState: Equatable {
    var track: DJTrack
    var bpm: Int
    var pitch: Double
    var gain: Double
    var isPlaying: Bool
}

private struct DJAtmosphereBackground: View {
    let isLit: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.012, green: 0.014, blue: 0.026),
                    Color(red: 0.038, green: 0.02, blue: 0.075),
                    Color(red: 0.0, green: 0.06, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            StageBeam(color: .cyan, xOffset: -150, rotation: -24, opacity: isLit ? 0.32 : 0.12)
            StageBeam(color: .pink, xOffset: 150, rotation: 24, opacity: isLit ? 0.3 : 0.1)
            StageBeam(color: .yellow, xOffset: 0, rotation: 0, opacity: isLit ? 0.12 : 0.04)

            VStack(spacing: 20) {
                ForEach(0..<20, id: \.self) { index in
                    Rectangle()
                        .fill(.white.opacity(index.isMultiple(of: 4) ? 0.055 : 0.018))
                        .frame(height: 1)
                }
            }
            .rotationEffect(.degrees(-7))
            .scaleEffect(1.4)
            .blendMode(.screen)

            EqualizerFloor(isLit: isLit)
        }
        .ignoresSafeArea()
    }
}

private struct StageBeam: View {
    let color: Color
    let xOffset: CGFloat
    let rotation: Double
    let opacity: Double

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [color.opacity(opacity), color.opacity(0.05), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 120, height: 680)
            .blur(radius: 18)
            .offset(x: xOffset, y: -250)
            .rotationEffect(.degrees(rotation))
            .blendMode(.screen)
    }
}

private struct EqualizerFloor: View {
    let isLit: Bool

    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(0..<40, id: \.self) { index in
                    Capsule()
                        .fill(barColor(for: index))
                        .frame(width: 4, height: CGFloat(16 + (index * 17) % 92))
                        .opacity(isLit ? 0.44 : 0.16)
                }
            }
            .padding(.bottom, 22)
            .blur(radius: 0.4)
        }
    }

    private func barColor(for index: Int) -> Color {
        if index.isMultiple(of: 5) { return .pink }
        if index.isMultiple(of: 3) { return .yellow }
        return .cyan
    }
}

private struct DJHeader: View {
    @Binding var isLit: Bool
    let isAudioReady: Bool
    let errorMessage: String?
    let importMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                            .shadow(color: .red.opacity(0.85), radius: 8)
                        Text("LIVE MIX")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.cyan)
                    }

                    Text("Night Deck")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .foregroundStyle(.white)

                    Text("雙軌混音、熱鍵 Pad、MP3 匯入、即時氛圍燈光，讓手機像一座迷你 DJ Booth。")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(3)
                }

                Spacer(minLength: 12)

                Toggle("燈光", isOn: $isLit)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(.pink)
            }

            HStack(spacing: 10) {
                HeaderBadge(title: "128", caption: "BPM", systemImage: "metronome.fill", color: .yellow)
                HeaderBadge(
                    title: isAudioReady ? "READY" : "TAP",
                    caption: "AUDIO",
                    systemImage: isAudioReady ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    color: isAudioReady ? .green : .cyan
                )
                HeaderBadge(title: "MP3", caption: "IMPORT", systemImage: "square.and.arrow.down.fill", color: .pink)
            }

            if let importMessage {
                Text(importMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.cyan.opacity(0.9))
                    .lineLimit(2)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red.opacity(0.9))
                    .lineLimit(2)
            }
        }
        .padding(20)
        .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .cyan.opacity(0.28), .pink.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

private struct HeaderBadge: View {
    let title: String
    let caption: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption.weight(.heavy))
                Text(caption)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct DeckStage: View {
    @Binding var leftDeck: DJDeckState
    @Binding var rightDeck: DJDeckState
    @Binding var crossfader: Double

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Deck Stage", systemImage: "headphones")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(crossfader < 0.44 ? "DECK A" : crossfader > 0.56 ? "DECK B" : "CENTER")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.1), in: Capsule())
            }

            HStack(spacing: 12) {
                TurntableDeck(title: "DECK A", deck: $leftDeck, accent: .cyan)
                TurntableDeck(title: "DECK B", deck: $rightDeck, accent: .pink)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("CROSSFADER")
                    Spacer()
                    Text("A  /  B")
                }
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white.opacity(0.64))

                Slider(value: $crossfader, in: 0...1)
                    .tint(crossfader > 0.56 ? .pink : .cyan)
            }
        }
        .padding(14)
        .background(.black.opacity(0.46), in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.cyan.opacity(0.28), .pink.opacity(0.24), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct TurntableDeck: View {
    let title: String
    @Binding var deck: DJDeckState
    let accent: Color

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(accent)
                Spacer()
                Circle()
                    .fill(deck.isPlaying ? Color.green : Color.white.opacity(0.26))
                    .frame(width: 9, height: 9)
            }

            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.black, Color(red: 0.08, green: 0.09, blue: 0.12), .black],
                                center: .center,
                                startRadius: 8,
                                endRadius: 94
                            )
                        )
                        .overlay {
                            ForEach(0..<6, id: \.self) { index in
                                Circle()
                                    .stroke(.white.opacity(0.045 + Double(index) * 0.018), lineWidth: 1)
                                    .padding(CGFloat(index * 12 + 10))
                            }
                        }
                        .shadow(color: accent.opacity(0.32), radius: 18)

                    EnergyRing(level: deck.gain, accent: accent)
                        .padding(16)

                    VStack(spacing: 2) {
                        Text("\(deck.bpm)")
                            .font(.system(.title2, design: .rounded, weight: .black))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                        Text("BPM")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }

                TurntableNeedle(accent: accent)
                    .frame(width: 48, height: 86)
                    .offset(x: 8, y: 10)
            }
            .aspectRatio(1, contentMode: .fit)

            VStack(spacing: 4) {
                Text(deck.track.title)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(deck.track.artist)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }

            CueWaveform(level: deck.gain, accent: accent)

            Button {
                deck.isPlaying.toggle()
            } label: {
                Image(systemName: deck.isPlaying ? "pause.fill" : "play.fill")
                    .font(.headline.weight(.bold))
                    .frame(width: 42, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.black)
            .background(accent, in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel(deck.isPlaying ? "暫停" : "播放")
        }
        .padding(12)
        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct EnergyRing: View {
    let level: Double
    let accent: Color

    var body: some View {
        Circle()
            .trim(from: 0.08, to: min(0.94, max(0.12, level)))
            .stroke(
                AngularGradient(
                    colors: [.clear, accent, .white.opacity(0.8), accent, .clear],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 8, lineCap: .round)
            )
            .rotationEffect(.degrees(-110))
            .shadow(color: accent.opacity(0.45), radius: 10)
    }
}

private struct TurntableNeedle: View {
    let accent: Color

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: 16, height: 16)
                .shadow(color: accent.opacity(0.5), radius: 8)

            RoundedRectangle(cornerRadius: 2)
                .fill(.white.opacity(0.68))
                .frame(width: 5, height: 58)
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(accent)
                        .frame(width: 12, height: 8)
                }
        }
        .rotationEffect(.degrees(28))
    }
}

private struct CueWaveform: View {
    let level: Double
    let accent: Color

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<22, id: \.self) { index in
                Capsule()
                    .fill(index % 4 == 0 ? .white.opacity(0.72) : accent.opacity(0.76))
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .frame(height: 30)
        .padding(.horizontal, 8)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("波形預覽")
    }

    private func barHeight(for index: Int) -> CGFloat {
        let base = 8 + (index * 11) % 20
        return CGFloat(base) * (0.72 + level * 0.46)
    }
}

private struct MixerConsole: View {
    @Binding var filter: Double
    @Binding var reverb: Double
    @Binding var leftGain: Double
    @Binding var rightGain: Double
    @Binding var selectedPad: Int
    let onPadTrigger: (PadAction) -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Mixer", systemImage: "slider.horizontal.below.rectangle")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text("FX BANK")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.pink)
            }

            HStack(spacing: 14) {
                Knob(value: $leftGain, title: "A Gain", accent: .cyan)
                Knob(value: $filter, title: "Filter", accent: .yellow)
                Knob(value: $reverb, title: "Reverb", accent: .green)
                Knob(value: $rightGain, title: "B Gain", accent: .pink)
            }

            PadGrid(selectedPad: $selectedPad, onTrigger: onPadTrigger)
        }
        .padding(16)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct Knob: View {
    @Binding var value: Double
    let title: String
    let accent: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.55))
                    .overlay {
                        Circle().stroke(.white.opacity(0.16), lineWidth: 1)
                    }

                Circle()
                    .trim(from: 0, to: value)
                    .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .padding(6)

                Rectangle()
                    .fill(accent)
                    .frame(width: 3, height: 18)
                    .offset(y: -17)
                    .rotationEffect(.degrees(value * 270 - 135))
            }
            .frame(width: 58, height: 58)

            Slider(value: $value, in: 0...1)
                .labelsHidden()
                .frame(width: 64)
                .tint(accent)

            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PadGrid: View {
    @Binding var selectedPad: Int
    let onTrigger: (PadAction) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(PadAction.allCases) { pad in
                Button {
                    onTrigger(pad)
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: pad.systemImage)
                            .font(.caption.weight(.heavy))
                        Text(pad.title)
                            .font(.caption2.weight(.heavy))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(pad.color.opacity(selectedPad == pad.rawValue ? 0.34 : 0.16), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(pad.color.opacity(selectedPad == pad.rawValue ? 0.78 : 0.28), lineWidth: 1)
                    }
                    .shadow(color: pad.color.opacity(selectedPad == pad.rawValue ? 0.28 : 0.08), radius: 8)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedPad == pad.rawValue ? .isSelected : [])
            }
        }
    }
}

private struct TrackLibrary: View {
    let tracks: [DJTrack]
    @Binding var selectedTrack: UUID
    let onImport: () -> Void
    let onLoadLeft: () -> Void
    let onLoadRight: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Library")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                    Text("匯入 MP3，或選一首歌載入到任一 Deck。")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: onImport) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.headline.weight(.heavy))
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
                    .background(Color.yellow, in: Circle())
                    .accessibilityLabel("匯入 MP3")

                    Button(action: onLoadLeft) {
                        Text("A")
                            .font(.headline.weight(.heavy))
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
                    .background(Color.cyan, in: Circle())
                    .accessibilityLabel("載入到 Deck A")

                    Button(action: onLoadRight) {
                        Text("B")
                            .font(.headline.weight(.heavy))
                            .frame(width: 38, height: 38)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
                    .background(Color.pink, in: Circle())
                    .accessibilityLabel("載入到 Deck B")
                }
            }

            VStack(spacing: 10) {
                ForEach(tracks) { track in
                    TrackRow(
                        track: track,
                        isSelected: selectedTrack == track.id,
                        action: { selectedTrack = track.id }
                    )
                }
            }
        }
        .padding(16)
        .background(.black.opacity(0.36), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct TrackRow: View {
    let track: DJTrack
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.56))
                    Circle()
                        .stroke(track.color.opacity(0.9), lineWidth: 2)
                        .padding(6)
                    Image(systemName: track.sourceIcon)
                        .font(.headline)
                        .foregroundStyle(track.color)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(track.bpm) BPM")
                        .font(.caption.weight(.heavy))
                    Text(track.duration)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.52))
                }
                .foregroundStyle(track.color)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? track.color : .white.opacity(0.28))
            }
            .padding(12)
            .background(.white.opacity(isSelected ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isSelected ? track.color : .white.opacity(0.12))
                    .frame(width: 3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension DJTrack {
    var sourceIcon: String {
        switch source {
        case .synth: "waveform"
        case .file: "music.note.list"
        }
    }
}

#Preview {
    ContentView()
}
