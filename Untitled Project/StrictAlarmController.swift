import AVFAudio
import Foundation
import Observation

@MainActor
@Observable
final class StrictAlarmController {
    private(set) var activeAlarmID: UUID?
    private(set) var isMonitoring = false

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioIsConfigured = false
    private var appIsActive = true
    private var triggeredMinuteKeys: Set<String> = []

    func setAppIsActive(_ isActive: Bool) {
        appIsActive = isActive
        if !isActive {
            stopSound()
        } else if activeAlarmID != nil {
            startSound()
        }
    }

    func monitor(store: AlarmStore) async {
        guard !isMonitoring else { return }
        isMonitoring = true
        defer { isMonitoring = false }

        while !Task.isCancelled {
            checkForDueAlarm(in: store, now: .now)
            try? await Task.sleep(for: .seconds(1))
        }
    }

    func complete(_ alarm: AlarmItem, store: AlarmStore) {
        stopSound()
        activeAlarmID = nil
        store.markCompleted(alarm)
    }

    private func checkForDueAlarm(in store: AlarmStore, now: Date) {
        guard appIsActive, activeAlarmID == nil else { return }

        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.year, .month, .day, .weekday, .hour, .minute],
            from: now
        )
        guard
            let weekday = components.weekday,
            let hour = components.hour,
            let minute = components.minute
        else {
            return
        }

        let dueAlarm = store.sortedAlarms.first { alarm in
            guard alarm.isEnabled, alarm.hour == hour, alarm.minute == minute else {
                return false
            }
            return alarm.weekdays.isEmpty || alarm.weekdays.contains(weekday)
        }
        guard let dueAlarm else { return }

        let minuteKey = [
            dueAlarm.id.uuidString,
            String(components.year ?? 0),
            String(components.month ?? 0),
            String(components.day ?? 0),
            String(hour),
            String(minute)
        ].joined(separator: "-")
        guard !triggeredMinuteKeys.contains(minuteKey) else { return }

        triggeredMinuteKeys.insert(minuteKey)
        discardOldTriggerKeysIfNeeded()
        activeAlarmID = dueAlarm.id
        startSound()
    }

    private func discardOldTriggerKeysIfNeeded() {
        guard triggeredMinuteKeys.count > 100 else { return }
        triggeredMinuteKeys.removeAll(keepingCapacity: true)
    }

    private func startSound() {
        guard appIsActive, !playerNode.isPlaying else { return }

        do {
            try configureAudioIfNeeded()
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let buffer = makeAlarmBuffer()
            playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
            if !audioEngine.isRunning {
                try audioEngine.start()
            }
            playerNode.play()
        } catch {
            // Error handling ignored
        }
    }

    private func configureAudioIfNeeded() throws {
        guard !audioIsConfigured else { return }

        let format = AVAudioFormat(
            standardFormatWithSampleRate: 44_100,
            channels: 1
        )!
        audioEngine.attach(playerNode)
        try audioEngine.connectNode(
            playerNode,
            to: audioEngine.mainMixerNode,
            format: format
        )
        audioIsConfigured = true
    }

    private func makeAlarmBuffer() -> AVAudioPCMBuffer {
        let sampleRate = 44_100.0
        let frameCount = AVAudioFrameCount(sampleRate)
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        )!
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        )!
        buffer.frameLength = frameCount

        let samples = buffer.floatChannelData![0]
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let pulsing = Int(time * 4).isMultiple(of: 2)
            let frequency = pulsing ? 880.0 : 660.0
            samples[frame] = Float(sin(2 * .pi * frequency * time) * 0.32)
        }
        return buffer
    }

    private func stopSound() {
        playerNode.stop()
        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }
}
