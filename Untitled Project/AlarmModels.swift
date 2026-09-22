import AlarmKit
import Foundation
import SwiftUI

enum WakeTask: String, Codable, CaseIterable, Identifiable, Sendable {
    case math
    case memory

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .math: "高強度數學"
        case .memory: "極限記憶"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .math: "完成一題多步驟運算"
        case .memory: "記住限時顯示的數字"
        }
    }

    var icon: String {
        switch self {
        case .math: "function"
        case .memory: "brain.head.profile"
        }
    }

    var color: Color {
        switch self {
        case .math: .blue
        case .memory: .purple
        }
    }
}

enum ChallengeDifficulty: String, Codable, CaseIterable, Identifiable, Sendable {
    case easy
    case medium
    case hard

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .easy: "困難"
        case .medium: "非常困難"
        case .hard: "極限"
        }
    }

    var memoryLength: Int {
        switch self {
        case .easy: 6
        case .medium: 9
        case .hard: 12
        }
    }

    var memoryDisplayDuration: Duration {
        switch self {
        case .easy, .medium: .seconds(3)
        case .hard: .seconds(2)
        }
    }
}

struct AlarmItem: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var label: String
    var hour: Int
    var minute: Int
    var weekdays: Set<Int>
    var isEnabled: Bool
    var task: WakeTask
    var difficulty: ChallengeDifficulty

    init(
        id: UUID = UUID(),
        label: String = "起床",
        hour: Int = 7,
        minute: Int = 30,
        weekdays: Set<Int> = Set(1...7),
        isEnabled: Bool = true,
        task: WakeTask = .math,
        difficulty: ChallengeDifficulty = .medium
    ) {
        self.id = id
        self.label = label
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.isEnabled = isEnabled
        self.task = task
        self.difficulty = difficulty
    }

    var time: Date {
        Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: .now
        ) ?? .now
    }

    var repeatDescription: String {
        if weekdays == Set(1...7) {
            return "每天"
        }
        if weekdays == [1, 7] {
            return "週末"
        }
        if weekdays == Set(2...6) {
            return "平日"
        }

        let symbols = Calendar.current.shortWeekdaySymbols
        return weekdays.sorted().compactMap { day in
            guard symbols.indices.contains(day - 1) else { return nil }
            return symbols[day - 1]
        }.joined(separator: "、")
    }
}

struct AlarmMetadata: AlarmKit.AlarmMetadata {
    let alarmID: UUID
    let taskRawValue: String
    let difficultyRawValue: String
}
