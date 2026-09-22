import AlarmKit
import Foundation
import Observation

@MainActor
@Observable
final class AlarmStore {
    private(set) var alarms: [AlarmItem] = []

    private let storageKey = "mission-alarms.v1"

    init() {
        load()
        cancelLegacySystemAlarms()
    }

    var sortedAlarms: [AlarmItem] {
        alarms.sorted {
            if $0.hour == $1.hour {
                return $0.minute < $1.minute
            }
            return $0.hour < $1.hour
        }
    }

    func alarm(id: UUID) -> AlarmItem? {
        alarms.first { $0.id == id }
    }

    func save(_ alarm: AlarmItem) async {
        var updated = alarm
        if updated.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updated.label = "起床"
        }

        if let index = alarms.firstIndex(where: { $0.id == updated.id }) {
            alarms[index] = updated
        } else {
            alarms.append(updated)
        }
        persist()
    }

    func setEnabled(_ enabled: Bool, for alarm: AlarmItem) async {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else {
            return
        }

        alarms[index].isEnabled = enabled
        persist()
    }

    func delete(_ alarm: AlarmItem) {
        alarms.removeAll { $0.id == alarm.id }
        persist()
    }

    func markCompleted(_ alarm: AlarmItem) {
        guard alarm.weekdays.isEmpty else { return }
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else {
            return
        }

        alarms[index].isEnabled = false
        persist()
    }

    private func cancelLegacySystemAlarms() {
        for alarm in alarms {
            try? AlarmManager.shared.cancel(id: alarm.id)
        }
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([AlarmItem].self, from: data)
        else {
            return
        }
        alarms = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(alarms) else {
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
