import Foundation
import SwiftUI

public struct DJTrack: Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let artist: String
    public let duration: String
    public let bpm: Int
    public let color: Color
    public let source: DJTrackSource

    public var synthSeed: Int {
        switch source {
        case .synth(let seed): seed
        case .file: 17
        }
    }

    public init(
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

    public static let samples: [DJTrack] = [
        DJTrack(title: "Midnight Pulse", artist: "Neon Harbor", duration: "03:48", bpm: 124, color: .cyan, source: .synth(seed: 3)),
        DJTrack(title: "Glass Room", artist: "Mika Lane", duration: "04:12", bpm: 128, color: .pink, source: .synth(seed: 8)),
        DJTrack(title: "Afterglow Run", artist: "Tape Circuit", duration: "05:06", bpm: 122, color: .yellow, source: .synth(seed: 13)),
        DJTrack(title: "Signal Drift", artist: "East Terminal", duration: "03:35", bpm: 132, color: .green, source: .synth(seed: 21))
    ]

    public static let importColors: [Color] = [.mint, .orange, .indigo, .teal, .red]
}

public enum DJTrackSource: Equatable {
    case synth(seed: Int)
    case file(URL)
}

public struct DJDeckState: Equatable {
    public var track: DJTrack
    public var bpm: Int
    public var pitch: Double = 0.0
    public var gain: Double = 0.75
    public var lowEQ: Double = 0.5
    public var midEQ: Double = 0.5
    public var highEQ: Double = 0.5
    public var isPlaying: Bool = false
    public var isMuted: Bool = false

    public var effectiveBPM: Int {
        Int(Double(bpm) * (1.0 + pitch * 0.1))
    }
}

public enum SFXType: String, CaseIterable, Identifiable {
    case drop = "DROP"
    case scratch = "SCRATCH"
    case airhorn = "AIR HORN"
    case laser = "LASER SWEEP"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .drop: "bolt.fill"
        case .scratch: "disc.fill"
        case .airhorn: "speaker.wave.3.fill"
        case .laser: "wand.and.stars"
        }
    }

    public var color: Color {
        switch self {
        case .drop: .yellow
        case .scratch: .cyan
        case .airhorn: .orange
        case .laser: .pink
        }
    }

    public var description: String {
        switch self {
        case .drop: "高能低音爆破音效，適合換歌時帶動氣氛。"
        case .scratch: "經典唱片擦刮聲，展現復古 DJ 搓盤風格。"
        case .airhorn: "派對必備氣笛聲，瞬間集中全場注意力。"
        case .laser: "科幻雷射掃描音效，適合高潮段落過渡。"
        }
    }
}

public struct BeginnerComboPreset: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let description: String
    public let icon: String
    public let color: Color
    public let tags: [String]
    public let targetCrossfader: Double
    public let targetFilter: Double
    public let targetReverb: Double
    public let actionDescription: String

    public static let presets: [BeginnerComboPreset] = [
        BeginnerComboPreset(
            id: "smooth_fade",
            title: "平滑濾波過渡",
            subtitle: "Smooth Filter Fade",
            description: "自動將 Crossfader 平滑移至中央並套用低通濾波，讓兩首歌曲的頻率無縫融合，不卡頓。",
            icon: "slider.horizontal.below.square.filled.and.square",
            color: .cyan,
            tags: ["新手推薦", "無縫銜接", "自動化"],
            targetCrossfader: 0.5,
            targetFilter: 0.5,
            targetReverb: 0.25,
            actionDescription: "推桿移至 50% + 濾波切至溫和中頻"
        ),
        BeginnerComboPreset(
            id: "bass_drop",
            title: "Bass Drop 暴擊切換",
            subtitle: "Bass Drop Switch",
            description: "先壓低 Deck A 低音，觸發炸裂 Drop 衝擊聲，隨後直接切換重音至 Deck B！",
            icon: "bolt.horizontal.circle.fill",
            color: .yellow,
            tags: ["高潮段落", "電子舞曲", "重音切換"],
            targetCrossfader: 1.0,
            targetFilter: 0.7,
            targetReverb: 0.4,
            actionDescription: "觸發 Drop 音效 + 快速推至 Deck B"
        ),
        BeginnerComboPreset(
            id: "filter_buildup",
            title: "高通漸強與迴音衝刺",
            subtitle: "Filter Sweep & Echo Buildup",
            description: "拉高高通濾波器並注入廣闊 Echo 迴音，製造期待感蓄力段落，隨後釋放乾淨主音。",
            icon: "sparkles.tv",
            color: .pink,
            tags: ["蓄力過渡", "情緒拉升", "空間感"],
            targetCrossfader: 0.5,
            targetFilter: 0.88,
            targetReverb: 0.75,
            actionDescription: "濾波升高至 88% + 迴音放大至 75%"
        ),
        BeginnerComboPreset(
            id: "echo_exit",
            title: "Echo 迴音煞車拉離",
            subtitle: "Echo Spin-Out Exit",
            description: "啟動強烈延遲迴音並快速降低當前音量，呈現專業 DJ 瀟灑煞車切歌效果。",
            icon: "dot.radiowaves.forward",
            color: .green,
            tags: ["煞車離場", "經典手法", "乾淨切歌"],
            targetCrossfader: 0.0,
            targetFilter: 0.35,
            targetReverb: 0.85,
            actionDescription: "開大 Echo + 漸隱推桿回到 Deck A"
        ),
        BeginnerComboPreset(
            id: "bpm_sync_blend",
            title: "BPM 對齊並流暢融合",
            subtitle: "Auto BPM Sync & Blend",
            description: "自動將右軌 BPM 對齊左軌，並進行 4 秒平滑交叉漸變，新手也能做出電台等級流暢接歌。",
            icon: "arrow.triangle.2.circlepath.circle.fill",
            color: .indigo,
            tags: ["BPM對齊", "雙軌融合", "自動對拍"],
            targetCrossfader: 0.5,
            targetFilter: 0.58,
            targetReverb: 0.3,
            actionDescription: "對齊 BPM + 雙軌均勻比例"
        ),
        BeginnerComboPreset(
            id: "hype_peak",
            title: "雙軌齊發 Peak Time 暴走",
            subtitle: "Dual Deck Peak Energy",
            description: "同時開啟兩軌播放，拉滿音量與中頻，配合震撼雷射效果，瞬間提升全場熱度！",
            icon: "flame.circle.fill",
            color: .orange,
            tags: ["全場高潮", "雙軌轟炸", "派對熱場"],
            targetCrossfader: 0.5,
            targetFilter: 0.65,
            targetReverb: 0.45,
            actionDescription: "雙軌全亮 + 交叉推桿居中"
        )
    ]
}

public struct MixingGuideItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let category: String
    public let content: String
    public let tip: String
    public let icon: String
    public let color: Color

    public static let guides: [MixingGuideItem] = [
        MixingGuideItem(
            title: "Crossfader（交叉推桿）的使用心法",
            subtitle: "如何流暢切換兩首歌曲",
            category: "基礎觀念",
            content: "Crossfader 決定了 Deck A 與 Deck B 的聲音比例。推至最左邊只會聽到左軌，最右邊只會聽到右軌，居中則兩軌同大聲。新手接歌時，建議在小節開頭（第 1 拍）開始推動推桿。",
            tip: "💡 秘訣：搭配「平滑濾波過渡」快捷鍵，可以避免兩首歌低音重疊產生的渾濁感。",
            icon: "slider.horizontal.3",
            color: .cyan
        ),
        MixingGuideItem(
            title: "EQ 三頻切換技巧（Low / Mid / High）",
            subtitle: "掌握聲部空間，避免頻率衝突",
            category: "進階控音",
            content: "兩首歌曲同時播放時，最大的問題是低音（Low/Bass）會互相打架。聰明的 DJ 會在推入 B 歌時，將 A 歌的 Low EQ 關小，把 Low 的位置留給 B 歌。",
            tip: "💡 秘訣：永遠不要同時將兩首歌的 Low EQ 都開到最大！",
            icon: "waveform.path.ecg",
            color: .pink
        ),
        MixingGuideItem(
            title: "BPM 對拍與節奏同步",
            subtitle: "讓兩首歌拍子合而為一",
            category: "節奏對齊",
            content: "BPM（Beats Per Minute）代表每分鐘拍數。如果 A 歌是 124 BPM，B 歌是 128 BPM，直接接歌會聽起來亂拍。按下 SYNC 按鈕可以快速幫你把 B 歌調整為 124 BPM。",
            tip: "💡 秘訣：使用「BPM 對齊並流暢融合」快捷鍵，系統會幫你瞬間算出最完美的節奏。",
            icon: "metronome",
            color: .yellow
        ),
        MixingGuideItem(
            title: "Hot Cue 與 Loop 循環疊加",
            subtitle: "創造屬於你的專屬節奏段落",
            category: "創意表演",
            content: "Loop 可以將某一段 4 拍或 8 拍的鼓點不斷重複，為接歌爭取更多時間。Hot Cue 則能讓你一鍵跳回最精彩的歌曲開頭或 Drop 點。",
            tip: "💡 秘訣：在主歌前 8 拍定一個 Loop，等前一首歌慢慢淡出後再解開 Loop。",
            icon: "repeat",
            color: .green
        )
    ]
}
