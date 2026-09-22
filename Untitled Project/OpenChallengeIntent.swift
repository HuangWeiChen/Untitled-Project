import AppIntents
import Foundation

@MainActor
@Observable
final class ChallengeRouter {
    static let shared = ChallengeRouter()

    var pendingAlarmID: UUID?

    private init() {}

    func open(alarmID: UUID) {
        pendingAlarmID = alarmID
    }

    func clear() {
        pendingAlarmID = nil
    }
}

struct OpenChallengeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "開始鬧鐘任務"
    static let description = IntentDescription("開啟 App 並完成任務後停止鬧鐘。")
    static let supportedModes: IntentModes = [.foreground(.immediate)]

    @Parameter(title: "鬧鐘識別碼")
    var alarmID: String

    init() {
        alarmID = ""
    }

    init(alarmID: UUID) {
        self.alarmID = alarmID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else {
            return .result()
        }

        await MainActor.run {
            ChallengeRouter.shared.open(alarmID: id)
        }
        return .result()
    }
}
