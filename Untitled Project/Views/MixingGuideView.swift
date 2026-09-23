import SwiftUI

struct MixingGuideView: View {
    let audioController: DJAudioController
    @State private var activeSFXMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "book.closed.fill")
                        .foregroundStyle(.pink)
                    Text("DJ ACADEMY & SOUNDBOARD")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.pink)
                }

                Text("混音學院與音效打擊板")
                    .font(.system(.title, design: .rounded, weight: .black))
                    .foregroundStyle(.white)

                Text("輕鬆學習 DJ 專有名詞與接歌技巧，隨時觸發即時派對音效增添現場氣氛！")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
            }

            // Live SFX Soundboard Section
            SFXSoundboardSection(
                audioController: audioController,
                activeSFXMessage: $activeSFXMessage
            )

            // Beginner Guide Cards Section
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text("新手必讀混音技巧指南")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 12) {
                    ForEach(MixingGuideItem.guides) { guide in
                        GuideCardView(guide: guide)
                    }
                }
            }
        }
    }
}

// MARK: - SFX Soundboard Section
private struct SFXSoundboardSection: View {
    let audioController: DJAudioController
    @Binding var activeSFXMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("SFX 音效打擊板", systemImage: "waveform.path.badge.plus")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text("INSTANT TRIGGER")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.yellow)
            }

            if let message = activeSFXMessage {
                Text(message)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.yellow.opacity(0.16), in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(SFXType.allCases) { sfx in
                    Button {
                        audioController.triggerSFX(sfx)
                        withAnimation {
                            activeSFXMessage = "🔊 已播放【\(sfx.rawValue)】音效"
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(sfx.color.opacity(0.2))
                                Image(systemName: sfx.icon)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(sfx.color)
                            }
                            .frame(width: 42, height: 42)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(sfx.rawValue)
                                    .font(.subheadline.weight(.black))
                                    .foregroundStyle(.white)
                                Text(sfx.description)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.65))
                                    .lineLimit(2)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .frame(height: 72)
                        .background(sfx.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                               .stroke(sfx.color.opacity(0.4), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(.black.opacity(0.44), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }
}

// MARK: - Guide Card View
private struct GuideCardView: View {
    let guide: MixingGuideItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(guide.color.opacity(0.2))
                    Image(systemName: guide.icon)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(guide.color)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(guide.category)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(guide.color)
                    Text(guide.title)
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(.white)
                }

                Spacer()
            }

            Text(guide.content)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .lineSpacing(4)

            Text(guide.tip)
                .font(.caption2.weight(.bold))
                .foregroundStyle(guide.color)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(guide.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(14)
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}
