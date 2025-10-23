import Foundation
import Combine
import WatchKit

struct Preset: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let seconds: Int
}

/// Summary model to present at the end
struct WorkoutSummary: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let presetName: String
    let workSecondsPerRound: Int
    let rounds: Int
    let restSecondsPerGap: Int
    var totalWorkSeconds: Int { workSecondsPerRound * rounds }
    var totalRestSeconds: Int { max(0, rounds - 1) * restSecondsPerGap }
    var totalSeconds: Int { totalWorkSeconds + totalRestSeconds }
}

@MainActor
final class TimerViewModel: ObservableObject {

    // MARK: - Published UI State (Work)
    @Published var isRunning: Bool = false
    @Published var remainingSeconds: Int = 0
    @Published var totalSeconds: Int = 0
    @Published var selectedPreset: Preset? = nil
    @Published var completedAt: Date? = nil   // fires at END of each WORK round

    // Rounds + Halfway
    @Published var roundsTotal: Int = 1
    @Published var currentRound: Int = 1
    @Published var halfwayEnabled: Bool = false

    // Rest state
    @Published var restSecondsSetting: Int = 20
    @Published var isResting: Bool = false
    @Published var restRemaining: Int = 0

    // NEW: Published summary when workout finishes
    @Published var summary: WorkoutSummary? = nil

    // MARK: - Private
    private var ticker: AnyCancellable?
    private var halfwayFired: Bool = false

    let presets: [Preset] = [
        Preset(name: "20 sec", seconds: 20),
        Preset(name: "1 min",  seconds: 60),
        Preset(name: "5 min",  seconds: 5 * 60),
        Preset(name: "10 min", seconds: 10 * 60)
    ]

    // MARK: - Intents
    func setTimer(seconds: Int, label: String? = nil) {
        stop()
        isResting = false
        restRemaining = 0
        summary = nil

        let clamped = max(0, seconds)
        totalSeconds = clamped
        remainingSeconds = clamped
        selectedPreset = label.map { Preset(name: $0, seconds: clamped) }
        currentRound = 1
        halfwayFired = false
        completedAt = nil
    }

    func start() {
        guard (!isResting && remainingSeconds > 0) || (isResting && restRemaining > 0) else { return }
        guard !isRunning else { return }
        isRunning = true

        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func pause() {
        isRunning = false
        ticker?.cancel()
        ticker = nil
    }

    func reset() {
        pause()
        isResting = false
        restRemaining = 0
        summary = nil
        if let preset = selectedPreset {
            remainingSeconds = preset.seconds
            totalSeconds = preset.seconds
        } else {
            remainingSeconds = 0
            totalSeconds = 0
        }
        currentRound = 1
        halfwayFired = false
        completedAt = nil
    }

    func stop() {
        isRunning = false
        ticker?.cancel()
        ticker = nil
    }

    func nudge(seconds delta: Int) {
        guard !isResting else { return }
        let newRemaining = max(0, remainingSeconds + delta)
        remainingSeconds = newRemaining
        if newRemaining > totalSeconds { totalSeconds = newRemaining }
        if totalSeconds > 0, Double(remainingSeconds) / Double(totalSeconds) > 0.5 {
            halfwayFired = false
        }
    }

    // MARK: - Derived
    var progressRemaining: Double {
        if isResting {
            guard restSecondsSetting > 0 else { return 0 }
            return max(0, min(1, Double(restRemaining) / Double(restSecondsSetting)))
        } else {
            guard totalSeconds > 0 else { return 0 }
            return max(0, min(1, Double(remainingSeconds) / Double(totalSeconds)))
        }
    }

    var displayIsZero: Bool {
        isResting ? restRemaining == 0 : remainingSeconds == 0
    }

    // MARK: - Internal
    private func tick() {
        if isResting {
            tickRest()
        } else {
            tickWork()
        }
    }

    private func tickRest() {
        guard restRemaining > 0 else {
            // Rest finished — begin next work round
            isResting = false
            currentRound += 1
            if currentRound <= roundsTotal {
                remainingSeconds = totalSeconds
                halfwayFired = false
                WKInterfaceDevice.current().play(.start)
            } else {
                // Safety stop
                stop()
            }
            return
        }
        restRemaining -= 1
    }

    private func tickWork() {
        guard remainingSeconds > 0 else {
            // Work round completed
            completedAt = Date()

            if currentRound < roundsTotal {
                if restSecondsSetting > 0 {
                    isResting = true
                    restRemaining = restSecondsSetting
                    WKInterfaceDevice.current().play(.notification)
                    return
                } else {
                    // No rest — immediately start next round
                    currentRound += 1
                    remainingSeconds = totalSeconds
                    halfwayFired = false
                    WKInterfaceDevice.current().play(.start)
                    return
                }
            } else {
                // FINISHED ALL ROUNDS — produce summary and stop
                stop()
                WKInterfaceDevice.current().play(.success)

                let name = selectedPreset?.name ?? "Custom"
                summary = WorkoutSummary(
                    date: Date(),
                    presetName: name,
                    workSecondsPerRound: totalSeconds,
                    rounds: roundsTotal,
                    restSecondsPerGap: restSecondsSetting
                )
                return
            }
        }

        // Count down work
        remainingSeconds -= 1

        // Halfway alert once per WORK round
        if halfwayEnabled, totalSeconds > 0 {
            let half = totalSeconds / 2
            if !halfwayFired, remainingSeconds == half {
                halfwayFired = true
                WKInterfaceDevice.current().play(.directionUp)
            }
        }
    }
}
