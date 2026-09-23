import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var audioController = DJAudioController()
    @State private var importedTracks: [DJTrack] = []
    @State private var leftDeck = DJDeckState(track: DJTrack.samples[0], bpm: 124, pitch: 0.0, gain: 0.75, isPlaying: false)
    @State private var rightDeck = DJDeckState(track: DJTrack.samples[1], bpm: 128, pitch: 0.0, gain: 0.75, isPlaying: false)
    @State private var crossfader = 0.5
    @State private var filter = 0.58
    @State private var reverb = 0.34
    @State private var lowEQ = 0.5
    @State private var midEQ = 0.5
    @State private var highEQ = 0.5
    @State private var selectedPad = 2
    @State private var selectedTrack = DJTrack.samples[0].id
    @State private var boothLightsOn = true
    @State private var isImportingAudio = false
    @State private var importMessage: String?
    @State private var selectedTab = 0

    private var tracks: [DJTrack] {
        DJTrack.samples + importedTracks
    }

    var body: some View {
        ZStack {
            DJAtmosphereBackground(isLit: boothLightsOn)

            VStack(spacing: 0) {
                // Top Global DJ Header
                DJHeader(
                    isLit: $boothLightsOn,
                    isAudioReady: audioController.isEngineRunning,
                    errorMessage: audioController.errorMessage,
                    importMessage: importMessage
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Page Navigation Tab Segment Selector
                NavigationSegmentBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                // Main Page Content Area
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case 0:
                            LiveMixerStageView(
                                leftDeck: $leftDeck,
                                rightDeck: $rightDeck,
                                crossfader: $crossfader,
                                filter: $filter,
                                reverb: $reverb,
                                lowEQ: $lowEQ,
                                midEQ: $midEQ,
                                highEQ: $highEQ,
                                selectedPad: $selectedPad,
                                selectedTrack: $selectedTrack,
                                tracks: tracks,
                                audioController: audioController,
                                onImportRequested: { isImportingAudio = true },
                                onLoadLeft: loadSelectedTrackToLeftDeck,
                                onLoadRight: loadSelectedTrackToRightDeck,
                                onTriggerPad: triggerPad
                            )

                        case 1:
                            BeginnerComboView(
                                crossfader: $crossfader,
                                filter: $filter,
                                reverb: $reverb,
                                lowEQ: $lowEQ,
                                midEQ: $midEQ,
                                highEQ: $highEQ,
                                leftDeck: $leftDeck,
                                rightDeck: $rightDeck,
                                audioController: audioController
                            )

                        case 2:
                            MixingGuideView(audioController: audioController)

                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 36)
                }
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
            audioController.updateEQ(low: lowEQ, mid: midEQ, high: highEQ)
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
            updateAudioMix()
        }
        .onChange(of: filter) { _, value in
            audioController.updateEffects(filter: value, reverbAmount: reverb)
        }
        .onChange(of: reverb) { _, value in
            audioController.updateEffects(filter: filter, reverbAmount: value)
        }
        .onChange(of: lowEQ) { _, _ in
            audioController.updateEQ(low: lowEQ, mid: midEQ, high: highEQ)
        }
        .onChange(of: midEQ) { _, _ in
            audioController.updateEQ(low: lowEQ, mid: midEQ, high: highEQ)
        }
        .onChange(of: highEQ) { _, _ in
            audioController.updateEQ(low: lowEQ, mid: midEQ, high: highEQ)
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

    private func triggerPad(_ padIndex: Int) {
        selectedPad = padIndex

        switch padIndex {
        case 0: // HOT CUE
            leftDeck.isPlaying = true
            rightDeck.isPlaying = true
            crossfader = 0.5
            updateAudioMix()
        case 1: // LOOP 4B
            audioController.reset(leftDeck.track, on: .left)
            audioController.reset(rightDeck.track, on: .right)
            audioController.setPlaying(leftDeck.isPlaying, on: .left)
            audioController.setPlaying(rightDeck.isPlaying, on: .right)
        case 2: // FX BOOST
            filter = 0.86
            reverb = min(1.0, reverb + 0.22)
            audioController.updateEffects(filter: filter, reverbAmount: reverb)
        case 3: // BASS DROP
            leftDeck.isPlaying = true
            rightDeck.isPlaying = true
            crossfader = 0.5
            audioController.triggerSFX(.drop)
        case 4: // ECHO DRY
            audioController.setEchoEnabled(true, reverbAmount: 0.82)
        case 5: // CUT MUTE
            audioController.cut(crossfader > 0.5 ? .right : .left, isMuted: true)
        case 6: // SYNC BPM
            rightDeck.bpm = leftDeck.bpm
            importMessage = "SYNC：Deck B 已對齊 Deck A 的 BPM 節奏！"
        case 7: // RESET CUE
            leftDeck.isPlaying = false
            rightDeck.isPlaying = false
            audioController.reset(leftDeck.track, on: .left)
            audioController.reset(rightDeck.track, on: .right)
        default:
            break
        }
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

// MARK: - Navigation Segment Bar
private struct NavigationSegmentBar: View {
    @Binding var selectedTab: Int

    private let tabs: [(id: Int, title: String, icon: String)] = [
        (0, "主控混音台", "headphones"),
        (1, "新手快捷組合", "bolt.horizontal.fill"),
        (2, "混音學院 & SFX", "book.closed.fill")
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tabs, id: \.id) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedTab = tab.id
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.caption.weight(.bold))
                        Text(tab.title)
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(selectedTab == tab.id ? .black : .white.opacity(0.75))
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(selectedTab == tab.id ? Color.cyan : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }
}

// MARK: - DJ Header
private struct DJHeader: View {
    @Binding var isLit: Bool
    let isAudioReady: Bool
    let errorMessage: String?
    let importMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.red)
                            .frame(width: 7, height: 7)
                            .shadow(color: .red.opacity(0.85), radius: 6)
                        Text("STUDIO LIVE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.cyan)
                    }

                    Text("Night Deck Pro")
                        .font(.system(.title2, design: .rounded, weight: .black))
                        .foregroundStyle(.white)
                }

                Spacer()

                Toggle("燈光", isOn: $isLit)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(.pink)
            }

            if let importMessage {
                Text(importMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.cyan.opacity(0.9))
                    .lineLimit(1)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red.opacity(0.9))
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
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

// MARK: - Background Atmosphere
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

#Preview {
    ContentView()
}
