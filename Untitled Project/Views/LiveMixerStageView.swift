import SwiftUI

struct LiveMixerStageView: View {
    @Binding var leftDeck: DJDeckState
    @Binding var rightDeck: DJDeckState
    @Binding var crossfader: Double
    @Binding var filter: Double
    @Binding var reverb: Double
    @Binding var lowEQ: Double
    @Binding var midEQ: Double
    @Binding var highEQ: Double
    @Binding var selectedPad: Int
    @Binding var selectedTrack: UUID

    let tracks: [DJTrack]
    let audioController: DJAudioController
    let onImportRequested: () -> Void
    let onLoadLeft: () -> Void
    let onLoadRight: () -> Void
    let onTriggerPad: (Int) -> Void
    var onDeleteTrack: ((DJTrack) -> Void)? = nil

    var body: some View {
        VStack(spacing: 18) {
            // Deck Stage (Turntables + Crossfader)
            DeckStageSection(
                leftDeck: $leftDeck,
                rightDeck: $rightDeck,
                crossfader: $crossfader
            )

            // Equalizer & FX Mixer
            EQMixerSection(
                lowEQ: $lowEQ,
                midEQ: $midEQ,
                highEQ: $highEQ,
                filter: $filter,
                reverb: $reverb,
                leftGain: $leftDeck.gain,
                rightGain: $rightDeck.gain,
                selectedPad: $selectedPad,
                onTriggerPad: onTriggerPad
            )

            // Track Library
            TrackLibrarySection(
                tracks: tracks,
                selectedTrack: $selectedTrack,
                onImport: onImportRequested,
                onLoadLeft: onLoadLeft,
                onLoadRight: onLoadRight,
                onDelete: onDeleteTrack
            )
        }
    }
}

// MARK: - Deck Stage Section
private struct DeckStageSection: View {
    @Binding var leftDeck: DJDeckState
    @Binding var rightDeck: DJDeckState
    @Binding var crossfader: Double

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                TurntableDeckView(
                    deck: $leftDeck,
                    label: "DECK A",
                    accent: .cyan
                )

                TurntableDeckView(
                    deck: $rightDeck,
                    label: "DECK B",
                    accent: .pink
                )
            }

            // Crossfader Control Section
            VStack(spacing: 6) {
                HStack {
                    Text("CH-A")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)
                    Spacer()
                    Text("CROSSFADER")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("CH-B")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.pink)
                }

                Slider(value: $crossfader, in: 0.0...1.0)
                    .tint(crossfaderColor)

                HStack {
                    Button("100% A") { withAnimation { crossfader = 0.0 } }
                    Spacer()
                    Button("CENTER") { withAnimation { crossfader = 0.5 } }
                    Spacer()
                    Button("100% B") { withAnimation { crossfader = 1.0 } }
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
        }
    }

    private var crossfaderColor: Color {
        if crossfader < 0.45 { return .cyan }
        if crossfader > 0.55 { return .pink }
        return .yellow
    }
}

// MARK: - Turntable Deck View
private struct TurntableDeckView: View {
    @Binding var deck: DJDeckState
    let label: String
    let accent: Color

    @State private var platterAngle: Double = 0.0

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(label)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(accent, in: Capsule())

                Spacer()

                Text("\(deck.bpm) BPM")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(accent)
            }

            // Vinyl Turntable Disc
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.15), Color(white: 0.04)],
                            center: .center,
                            startRadius: 8,
                            endRadius: 75
                        )
                    )
                    .frame(width: 140, height: 140)
                    .shadow(color: accent.opacity(deck.isPlaying ? 0.35 : 0.08), radius: 10)

                // Vinyl Grooves
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 1).frame(width: 120, height: 120)
                Circle().stroke(Color.white.opacity(0.06), lineWidth: 1).frame(width: 95, height: 95)
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 1).frame(width: 70, height: 70)

                // Vinyl Center Label
                Circle()
                    .fill(deck.track.color.opacity(0.85))
                    .frame(width: 44, height: 44)

                Circle()
                    .fill(.black)
                    .frame(width: 10, height: 10)

                // Marker dot to show rotation
                Circle()
                    .fill(.white)
                    .frame(width: 7, height: 7)
                    .offset(y: -48)
                    .rotationEffect(.degrees(platterAngle))

                EnergyRingView(level: deck.isPlaying ? 0.88 : 0.18, accent: accent)
                    .frame(width: 136, height: 136)
            }
            .onChange(of: deck.isPlaying) { _, isPlaying in
                if isPlaying {
                    withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                        platterAngle += 360
                    }
                }
            }

            VStack(spacing: 2) {
                Text(deck.track.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(deck.track.artist)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            // Pitch Control Slider (-10% ~ +10%)
            VStack(spacing: 2) {
                HStack {
                    Text("PITCH")
                    Spacer()
                    Text(String(format: "%+.1f%%", deck.pitch * 10))
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.6))

                Slider(value: $deck.pitch, in: -1.0...1.0)
                    .tint(accent)
            }

            Button {
                deck.isPlaying.toggle()
            } label: {
                Image(systemName: deck.isPlaying ? "pause.fill" : "play.fill")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.black)
            .background(accent, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(10)
        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct EnergyRingView: View {
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
                style: StrokeStyle(lineWidth: 6, lineCap: .round)
            )
            .rotationEffect(.degrees(-110))
            .shadow(color: accent.opacity(0.45), radius: 8)
    }
}

// MARK: - EQ & Mixer Section
private struct EQMixerSection: View {
    @Binding var lowEQ: Double
    @Binding var midEQ: Double
    @Binding var highEQ: Double
    @Binding var filter: Double
    @Binding var reverb: Double
    @Binding var leftGain: Double
    @Binding var rightGain: Double
    @Binding var selectedPad: Int
    let onTriggerPad: (Int) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // 3-Band Equalizer
                VStack(alignment: .leading, spacing: 6) {
                    Text("3-BAND EQ")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white.opacity(0.6))

                    HStack(spacing: 8) {
                        EQKnobColumn(title: "HI", value: $highEQ, tint: .cyan)
                        EQKnobColumn(title: "MID", value: $midEQ, tint: .yellow)
                        EQKnobColumn(title: "LOW", value: $lowEQ, tint: .pink)
                    }
                }
                .padding(10)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

                // FX Knobs
                VStack(alignment: .leading, spacing: 6) {
                    Text("FX UNITS")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white.opacity(0.6))

                    HStack(spacing: 8) {
                        EQKnobColumn(title: "FILTER", value: $filter, tint: .orange)
                        EQKnobColumn(title: "REVERB", value: $reverb, tint: .purple)
                    }
                }
                .padding(10)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            }

            // Channel Gains
            HStack(spacing: 12) {
                HStack {
                    Text("GAIN A")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.cyan)
                    Slider(value: $leftGain, in: 0.0...1.0)
                        .tint(.cyan)
                }

                HStack {
                    Text("GAIN B")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.pink)
                    Slider(value: $rightGain, in: 0.0...1.0)
                        .tint(.pink)
                }
            }
            .padding(.horizontal, 4)

            // 8 Performance Pads
            PerformancePadsGrid(selectedPad: selectedPad, onTrigger: onTriggerPad)
        }
        .padding(12)
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct EQKnobColumn: View {
    let title: String
    @Binding var value: Double
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 4)
                    .frame(width: 36, height: 36)

                Circle()
                    .trim(from: 0.0, to: CGFloat(value))
                    .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))

                Text(String(format: "%.0f", value * 100))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(title)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(.white.opacity(0.7))

            Slider(value: $value, in: 0.0...1.0)
                .tint(tint)
                .labelsHidden()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Performance Pads Grid
private struct PerformancePadsGrid: View {
    let selectedPad: Int
    let onTrigger: (Int) -> Void

    private let pads: [(id: Int, title: String, icon: String, color: Color)] = [
        (0, "HOT CUE", "bolt.fill", .yellow),
        (1, "LOOP 4B", "arrow.triangle.2.circlepath", .green),
        (2, "FX BOOST", "sparkles", .purple),
        (3, "BASS DROP", "waveform.path.ecg", .pink),
        (4, "ECHO DRY", "waveform.badge.magnifyingglass", .blue),
        (5, "CUT MUTE", "speaker.slash.fill", .red),
        (6, "SYNC BPM", "link", .cyan),
        (7, "RESET CUE", "arrow.counterclockwise", .orange)
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
            ForEach(pads, id: \.id) { pad in
                Button {
                    onTrigger(pad.id)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: pad.icon)
                            .font(.caption.weight(.heavy))
                        Text(pad.title)
                            .font(.system(size: 9, weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(pad.color.opacity(selectedPad == pad.id ? 0.38 : 0.14), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(pad.color.opacity(selectedPad == pad.id ? 0.8 : 0.25), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Track Library Section
private struct TrackLibrarySection: View {
    let tracks: [DJTrack]
    @Binding var selectedTrack: UUID
    let onImport: () -> Void
    let onLoadLeft: () -> Void
    let onLoadRight: () -> Void
    var onDelete: ((DJTrack) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Track Library (歌曲媒體庫)")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                    Text("匯入 MP3 或選擇樂曲載入 Deck A / B")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: onImport) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.subheadline.weight(.heavy))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
                    .background(Color.yellow, in: Circle())

                    Button(action: onLoadLeft) {
                        Text("A")
                            .font(.subheadline.weight(.heavy))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
                    .background(Color.cyan, in: Circle())

                    Button(action: onLoadRight) {
                        Text("B")
                            .font(.subheadline.weight(.heavy))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
                    .background(Color.pink, in: Circle())
                }
            }

            VStack(spacing: 8) {
                ForEach(tracks) { track in
                    HStack(spacing: 8) {
                        Button {
                            selectedTrack = track.id
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle().fill(.black.opacity(0.56))
                                    Circle().stroke(track.color.opacity(0.9), lineWidth: 2).padding(4)
                                    Image(systemName: track.sourceIcon)
                                        .font(.subheadline)
                                        .foregroundStyle(track.color)
                                }
                                .frame(width: 40, height: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(track.artist)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.58))
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 8)

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(track.bpm) BPM")
                                        .font(.caption2.weight(.heavy))
                                    Text(track.duration)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .foregroundStyle(track.color)

                                Image(systemName: selectedTrack == track.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedTrack == track.id ? track.color : .white.opacity(0.28))
                            }
                        }
                        .buttonStyle(.plain)

                        // Delete button for imported tracks
                        if case .file = track.source {
                            Button {
                                onDelete?(track)
                            } label: {
                                Image(systemName: "trash.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.red.opacity(0.9))
                                    .frame(width: 32, height: 32)
                                    .background(.red.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(.white.opacity(selectedTrack == track.id ? 0.12 : 0.05), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(selectedTrack == track.id ? track.color : .white.opacity(0.12))
                            .frame(width: 3)
                    }
                }
            }
        }
        .padding(14)
        .background(.black.opacity(0.36), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
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
