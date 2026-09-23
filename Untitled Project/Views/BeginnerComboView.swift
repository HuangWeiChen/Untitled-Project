import SwiftUI

struct BeginnerComboView: View {
    @Binding var crossfader: Double
    @Binding var filter: Double
    @Binding var reverb: Double
    @Binding var lowEQ: Double
    @Binding var midEQ: Double
    @Binding var highEQ: Double
    @Binding var leftDeck: DJDeckState
    @Binding var rightDeck: DJDeckState

    let audioController: DJAudioController
    @State private var activePresetID: String?
    @State private var executionBannerMessage: String?
    @State private var isExecutingMacro = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.horizontal.fill")
                        .foregroundStyle(.yellow)
                    Text("BEGINNER MIX COMBOS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.yellow)
                }

                Text("新手一鍵混音快捷鍵")
                    .font(.system(.title, design: .rounded, weight: .black))
                    .foregroundStyle(.white)

                Text("精選專業 DJ 常用組合手法，不必繁複手動調整 5 個旋鈕，一鍵實現流暢過渡與震撼切歌！")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
            }

            // Live status banner
            if let message = executionBannerMessage {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.yellow)
                        .scaleEffect(0.8)
                    Text(message)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.yellow.opacity(0.5), lineWidth: 1)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Live Parameter Dashboard
            LiveParameterDashboard(
                crossfader: crossfader,
                filter: filter,
                reverb: reverb,
                lowEQ: lowEQ
            )

            // Preset Grid Cards
            VStack(spacing: 14) {
                ForEach(BeginnerComboPreset.presets) { preset in
                    ComboPresetCard(
                        preset: preset,
                        isActive: activePresetID == preset.id,
                        isExecuting: isExecutingMacro,
                        onExecute: {
                            executePreset(preset)
                        }
                    )
                }
            }
        }
    }

    private func executePreset(_ preset: BeginnerComboPreset) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            activePresetID = preset.id
            isExecutingMacro = true
            executionBannerMessage = "⚡ 正在執行【\(preset.title)】：\(preset.actionDescription)"
        }

        // Apply audio actions
        switch preset.id {
        case "smooth_fade":
            withAnimation(.easeInOut(duration: 0.8)) {
                crossfader = preset.targetCrossfader
                filter = preset.targetFilter
                reverb = preset.targetReverb
                lowEQ = 0.5
            }
            audioController.updateMix(leftGain: leftDeck.gain, rightGain: rightDeck.gain, crossfader: preset.targetCrossfader)
            audioController.updateEffects(filter: preset.targetFilter, reverbAmount: preset.targetReverb)

        case "bass_drop":
            lowEQ = 0.1
            audioController.updateEQ(low: 0.1, mid: midEQ, high: highEQ)
            audioController.triggerSFX(.drop)
            withAnimation(.easeOut(duration: 0.5)) {
                crossfader = 1.0
                filter = preset.targetFilter
                reverb = preset.targetReverb
            }
            audioController.updateMix(leftGain: leftDeck.gain, rightGain: rightDeck.gain, crossfader: 1.0)
            rightDeck.isPlaying = true
            audioController.setPlaying(true, on: .right)

        case "filter_buildup":
            withAnimation(.easeInOut(duration: 1.2)) {
                filter = 0.88
                reverb = 0.75
                crossfader = 0.5
            }
            audioController.updateEffects(filter: 0.88, reverbAmount: 0.75)
            audioController.triggerSFX(.laser)

        case "echo_exit":
            audioController.setEchoEnabled(true, reverbAmount: 0.85)
            withAnimation(.easeOut(duration: 0.6)) {
                crossfader = 0.0
                filter = 0.35
                reverb = 0.85
            }
            audioController.updateMix(leftGain: leftDeck.gain, rightGain: rightDeck.gain, crossfader: 0.0)

        case "bpm_sync_blend":
            rightDeck.bpm = leftDeck.bpm
            rightDeck.pitch = leftDeck.pitch
            withAnimation(.easeInOut(duration: 1.0)) {
                crossfader = 0.5
                filter = 0.58
                reverb = 0.3
            }
            audioController.updateMix(leftGain: leftDeck.gain, rightGain: rightDeck.gain, crossfader: 0.5)

        case "hype_peak":
            leftDeck.isPlaying = true
            rightDeck.isPlaying = true
            audioController.setPlaying(true, on: .left)
            audioController.setPlaying(true, on: .right)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                crossfader = 0.5
                filter = 0.65
                reverb = 0.45
                lowEQ = 0.8
                highEQ = 0.8
            }
            audioController.updateEQ(low: 0.8, mid: midEQ, high: 0.8)
            audioController.triggerSFX(.airhorn)

        default:
            break
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                isExecutingMacro = false
                executionBannerMessage = "✅ 【\(preset.title)】已套用完畢！已進入最佳混音參數。"
            }
        }
    }
}

// MARK: - Live Parameter Dashboard
private struct LiveParameterDashboard: View {
    let crossfader: Double
    let filter: Double
    let reverb: Double
    let lowEQ: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("即時聲音控制狀態 (LIVE PARAMETERS)")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 8) {
                MetricPill(title: "FADER", value: String(format: "%d%%", Int(crossfader * 100)), color: .cyan)
                MetricPill(title: "FILTER", value: String(format: "%d%%", Int(filter * 100)), color: .yellow)
                MetricPill(title: "REVERB", value: String(format: "%d%%", Int(reverb * 100)), color: .pink)
                MetricPill(title: "LOW EQ", value: String(format: "%d%%", Int(lowEQ * 100)), color: .orange)
            }
        }
        .padding(12)
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct MetricPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .black))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Combo Preset Card
private struct ComboPresetCard: View {
    let preset: BeginnerComboPreset
    let isActive: Bool
    let isExecuting: Bool
    let onExecute: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(preset.color.opacity(0.2))
                    Image(systemName: preset.icon)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(preset.color)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(preset.title)
                            .font(.headline.weight(.black))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(preset.subtitle)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Text(preset.description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Tag List
            HStack(spacing: 6) {
                ForEach(preset.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(preset.color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(preset.color.opacity(0.14), in: Capsule())
                }

                Spacer()

                Button(action: onExecute) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.caption2)
                        Text(isActive && isExecuting ? "執行中..." : "一鍵觸發快捷鍵")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(preset.color, in: RoundedRectangle(cornerRadius: 8))
                    .shadow(color: preset.color.opacity(0.4), radius: 8)
                }
                .buttonStyle(.plain)
                .disabled(isActive && isExecuting)
            }
        }
        .padding(14)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? preset.color : .white.opacity(0.14), lineWidth: isActive ? 2 : 1)
        }
    }
}
