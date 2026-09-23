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
                                onTriggerPad: triggerPad,
                                onDeleteTrack: deleteImportedTrack
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
            loadExistingImportedTracks()

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
            allowedContentTypes: [.audio, .mp3, .mpeg4Audio, .wav, .aiff],
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

    private func deleteImportedTrack(_ track: DJTrack) {
        withAnimation(.easeInOut(duration: 0.25)) {
            // If loaded on deck A, revert deck A to sample 0
            if leftDeck.track.id == track.id {
                leftDeck.track = DJTrack.samples[0]
                leftDeck.bpm = DJTrack.samples[0].bpm
                audioController.load(DJTrack.samples[0], on: .left, isPlaying: leftDeck.isPlaying)
            }
            // If loaded on deck B, revert deck B to sample 1
            if rightDeck.track.id == track.id {
                rightDeck.track = DJTrack.samples[1]
                rightDeck.bpm = DJTrack.samples[1].bpm
                audioController.load(DJTrack.samples[1], on: .right, isPlaying: rightDeck.isPlaying)
            }

            // Remove physical file from disk
            if case .file(let url) = track.source {
                try? FileManager.default.removeItem(at: url)
            }

            // Remove from imported list
            importedTracks.removeAll(where: { $0.id == track.id })

            if selectedTrack == track.id {
                selectedTrack = tracks.first?.id ?? DJTrack.samples[0].id
            }

            importMessage = "已成功刪除「\(track.title)」！"
        }
    }

    private func loadExistingImportedTracks() {
        let fileManager = FileManager.default
        guard let documentsURL = try? fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }

        let importsURL = documentsURL.appendingPathComponent("Imported Audio", isDirectory: true)
        guard let files = try? fileManager.contentsOfDirectory(at: importsURL, includingPropertiesForKeys: [.fileSizeKey]) else { return }

        var loaded: [DJTrack] = []
        for file in files {
            let attributes = (try? fileManager.attributesOfItem(atPath: file.path)) ?? [:]
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            if size == 0 {
                try? fileManager.removeItem(at: file)
                continue
            }

            var cleanName = file.deletingPathExtension().lastPathComponent
            // Remove UUID prefix if present
            if cleanName.count > 37 && cleanName.dropFirst(36).starts(with: "-") {
                cleanName = String(cleanName.dropFirst(37))
            }

            let metadata = audioMetadata(for: file)
            let track = DJTrack(
                title: cleanName.isEmpty ? "Imported Track" : cleanName,
                artist: "已匯入樂曲",
                duration: metadata.duration,
                bpm: metadata.bpm,
                color: DJTrack.importColors[loaded.count % DJTrack.importColors.count],
                source: .file(file)
            )
            loaded.append(track)
        }

        if !loaded.isEmpty {
            importedTracks = loaded
            if let first = loaded.first {
                selectedTrack = first.id
                leftDeck.track = first
                leftDeck.bpm = first.bpm
            }
        }
    }

    private func loadSelectedTrackToLeftDeck() {
        guard let track = tracks.first(where: { $0.id == selectedTrack }) else { return }
        leftDeck.track = track
        leftDeck.bpm = track.bpm
        leftDeck.isPlaying = true
        audioController.load(track, on: .left, isPlaying: true)
        updateAudioMix()
    }

    private func loadSelectedTrackToRightDeck() {
        guard let track = tracks.first(where: { $0.id == selectedTrack }) else { return }
        rightDeck.track = track
        rightDeck.bpm = track.bpm
        rightDeck.isPlaying = true
        audioController.load(track, on: .right, isPlaying: true)
        updateAudioMix()
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
            audioController.setPlaying(true, on: .left)
            audioController.setPlaying(true, on: .right)
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
            audioController.setPlaying(true, on: .left)
            audioController.setPlaying(true, on: .right)
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
            guard !urls.isEmpty else { return }

            var loadedTracks: [DJTrack] = []
            for url in urls {
                let track = try makeImportedTrack(from: url)
                loadedTracks.append(track)
            }

            importedTracks.append(contentsOf: loadedTracks)
            if let first = loadedTracks.first {
                selectedTrack = first.id
                // 自動載入匯入歌曲至 Deck A 並啟動播放
                leftDeck.track = first
                leftDeck.bpm = first.bpm
                leftDeck.isPlaying = true
                if crossfader > 0.8 {
                    crossfader = 0.5
                }
                updateAudioMix()
                audioController.load(first, on: .left, isPlaying: true)
            }
            importMessage = "已成功載入「\(loadedTracks.first?.title ?? "")」，音訊解碼就緒！"
        } catch {
            importMessage = "匯入失敗：\(error.localizedDescription)"
        }
    }

    private func makeImportedTrack(from sourceURL: URL) throws -> DJTrack {
        let isAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let originalTitle = sourceURL.deletingPathExtension().lastPathComponent
        let copiedURL = try copyAudioIntoAppStorage(sourceURL)
        let metadata = audioMetadata(for: copiedURL)

        return DJTrack(
            title: originalTitle.isEmpty ? "Imported Track" : originalTitle,
            artist: "匯入音訊",
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

        let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let baseName = sourceURL.deletingPathExtension().lastPathComponent.isEmpty ? "Track" : sourceURL.deletingPathExtension().lastPathComponent
        let destinationURL = importsURL.appendingPathComponent("\(UUID().uuidString)-\(baseName).\(ext)")

        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }

        var coordinationError: NSError?
        var readData: Data?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: sourceURL, options: [], error: &coordinationError) { coordinatedURL in
            readData = try? Data(contentsOf: coordinatedURL)
        }

        if let coordinationError = coordinationError {
            throw coordinationError
        }

        if let data = readData, !data.isEmpty {
            try data.write(to: destinationURL, options: .atomic)
        } else {
            // Direct file read fallback
            if let directData = try? Data(contentsOf: sourceURL), !directData.isEmpty {
                try directData.write(to: destinationURL, options: .atomic)
            } else {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            }
        }

        let attributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard fileSize > 0 else {
            throw NSError(
                domain: "DJAudioImport",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "音訊檔案為空 (0 bytes)，無法播放。請確認檔案來源正常。"]
            )
        }

        return destinationURL
    }

    private func audioMetadata(for url: URL) -> (duration: String, bpm: Int) {
        let asset = AVURLAsset(url: url)
        let durationSeconds = CMTimeGetSeconds(asset.duration)
        if durationSeconds.isFinite && durationSeconds > 0 {
            let minutes = Int(durationSeconds) / 60
            let remainder = Int(durationSeconds) % 60
            let duration = String(format: "%02d:%02d", minutes, remainder)
            return (duration, 128)
        }

        if let file = try? AVAudioFile(forReading: url), file.length > 0 {
            let seconds = Double(file.length) / file.processingFormat.sampleRate
            let minutes = Int(seconds) / 60
            let remainder = Int(seconds) % 60
            let duration = String(format: "%02d:%02d", minutes, remainder)
            return (duration, 128)
        }

        return ("--:--", 128)
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
