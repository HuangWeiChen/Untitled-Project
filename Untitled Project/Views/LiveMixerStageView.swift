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
                onLoadRight: onLoadRight
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
            HStack {
                Label("Deck Stage (主對軌台)", systemImage: "headphones")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(crossfader < 0.44 ? "DECK A" : crossfader > 0.56 ? "DECK B" : "CENTER 50/50")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 12) {
                TurntableDeckView(title: "DECK A", deck: $leftDeck, accent: .cyan)
                TurntableDeckView(title: "DECK B", deck: $rightDeck, accent: .pink)
            }

            // Crossfader + Quick Presets
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("CROSSFADER 交叉推桿")
                    Spacer()
                    Text("A (\(Int((1 - crossfader) * 100))%) / B (\(Int(crossfader * 100))%)")
                }
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white.opacity(0.64))

                Slider(value: $crossfader, in: 0...1)
                    .tint(crossfader > 0.56 ? .pink : .cyan)

                HStack(spacing: 8) {
                    Button("全切 A (100:0)") {
                        withAnimation(.easeInOut(duration: 0.3)) { crossfader = 0.0 }
                    }
                    .buttonStyle(PresetButtonStyle(accent: .cyan))

                    Button("居中 (50:50)") {
                        withAnimation(.easeInOut(duration: 0.3)) { crossfader = 0.5 }
                    }
                    .buttonStyle(PresetButtonStyle(accent: .yellow))

                    Button("全切 B (0:100)") {
                        withAnimation(.easeInOut(duration: 0.3)) { crossfader = 1.0 }
                    }
                    .buttonStyle(PresetButtonStyle(accent: .pink))
                }
            }
        }
        .padding(14)
        .background(.black.opacity(0.46), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct PresetButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(accent.opacity(configuration.isPressed ? 0.4 : 0.18), in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(accent.opacity(0.4), lineWidth: 1)
            }
    }
}

// MARK: - Turntable Deck View
private struct TurntableDeckView: View {
    let title: String
    @Binding var deck: DJDeckState
    let accent: Color

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(accent)
                Spacer()
                Circle()
                    .fill(deck.isPlaying ? Color.green : Color.white.opacity(0.26))
                    .frame(width: 9, height: 9)
            }

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
                    .shadow(color: accent.opacity(0.32), radius: 14)

                EnergyRingView(level: deck.gain, accent: accent)
                    .padding(14)

                VStack(spacing: 2) {
                    Text("\(deck.effectiveBPM)")
                        .font(.system(.title3, design: .rounded, weight: .black))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("BPM")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
            .aspectRatio(1, contentMode: .fit)

            VStack(spacing: 2) {
                Text(deck.track.title)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(deck.track.artist)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.58))
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
        VStack(spacing: 16) {
            HStack {
                Label("3-Band EQ & Master FX (等化器與特效)", systemImage: "slider.horizontal.below.rectangle")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text("PRO EQ")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.pink)
            }

            // 3-Band EQ Knobs
            HStack(spacing: 12) {
                KnobControl(value: $lowEQ, title: "LOW (低音)", accent: .orange)
                KnobControl(value: $midEQ, title: "MID (中音)", accent: .yellow)
                KnobControl(value: $highEQ, title: "HIGH (高音)", accent: .green)
                KnobControl(value: $filter, title: "FILTER (濾波)", accent: .cyan)
                KnobControl(value: $reverb, title: "REVERB (迴音)", accent: .pink)
            }

            PadGridSection(selectedPad: $selectedPad, onTrigger: onTriggerPad)
        }
        .padding(14)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct KnobControl: View {
    @Binding var value: Double
    let title: String
    let accent: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.55))
                    .overlay {
                        Circle().stroke(.white.opacity(0.16), lineWidth: 1)
                    }

                Circle()
                    .trim(from: 0, to: value)
                    .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .padding(5)

                Rectangle()
                    .fill(accent)
                    .frame(width: 2.5, height: 14)
                    .offset(y: -13)
                    .rotationEffect(.degrees(value * 270 - 135))
            }
            .frame(width: 48, height: 48)

            Slider(value: $value, in: 0...1)
                .labelsHidden()
                .frame(width: 52)
                .tint(accent)

            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PadGridSection: View {
    @Binding var selectedPad: Int
    let onTrigger: (Int) -> Void

    private let pads: [(id: Int, title: String, icon: String, color: Color)] = [
        (0, "HOT CUE", "flame.fill", .orange),
        (1, "LOOP 4B", "repeat", .cyan),
        (2, "FX BOOST", "sparkles", .pink),
        (3, "BASS DROP", "bolt.fill", .yellow),
        (4, "ECHO DRY", "dot.radiowaves.left.and.right", .green),
        (5, "CUT MUTE", "scissors", .red),
        (6, "SYNC BPM", "arrow.triangle.2.circlepath", .cyan),
        (7, "RESET CUE", "record.circle", .pink)
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
                        .padding(10)
                        .background(.white.opacity(selectedTrack == track.id ? 0.12 : 0.05), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(selectedTrack == track.id ? track.color : .white.opacity(0.12))
                                .frame(width: 3)
                        }
                    }
                    .buttonStyle(.plain)
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
