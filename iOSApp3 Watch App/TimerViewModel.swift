import Foundation
import Combine
import WatchKit

/// A simple preset model for quick timer selections.
struct Preset: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let seconds: Int
}

/// ViewModel that owns timer state and logic.
/// Uses Combine's `Timer.publish` to tick once per second on the main runloop.
@MainActor
final class TimerViewModel: ObservableObject {

    // MARK: - Published UI State
    @Published var isRunning: Bool = false
    @Published var remainingSeconds: Int = 0
    @Published var totalSeconds: Int = 0                  // <— for progress ring
    @Published var selectedPreset: Preset? = nil
    @Published var completedAt: Date? = nil               // <— set on (round) completion

    // New features
    @Published var roundsTotal: Int = 1
    @Published var currentRound: Int = 1
    @Published var halfwayEnabled: Bool = false

    // MARK: - Private
    private var ticker: AnyCancellable?
    private var halfwayFired: Bool = false

    // MARK: - Presets
    let presets: [Preset] = [
        Preset(name: "20 sec", seconds: 20),
        Preset(name: "1 min",  seconds: 60),
        Preset(name: "5 min",  seconds: 5 * 60),
        Preset(name: "10 min", seconds: 10 * 60)
    ]

    // MARK: - Intent(s)
    /// Set a new timer duration. Stops any running timer first.
    func setTimer(seconds: Int, label: String? = nil) {
        stop()
        let clamped = max(0, seconds)
        totalSeconds = clamped
        remainingSeconds = clamped
        if let label = label {
            selectedPreset = Preset(name: label, seconds: clamped)
        } else {
            selectedPreset = nil
        }
        currentRound = 1
        halfwayFired = false
        completedAt = nil
    }

    /// Start ticking once per second if there is time remaining.
    func start() {
        guard remainingSeconds > 0, !isRunning else { return }
        isRunning = true

        ticker = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    /// Pause without clearing the current `remainingSeconds`.
    func pause() {
        isRunning = false
        ticker?.cancel()
        ticker = nil
    }

    /// Reset back to the selected preset (or 0 if none).
    func reset() {
        pause()
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

    /// Stop and clear the ticker (used internally).
    func stop() {
        isRunning = false
        ticker?.cancel()
        ticker = nil
    }

    /// Nudge remaining time by +/- seconds. Keeps >= 0. If nudging up past total, expand total.
    func nudge(seconds delta: Int) {
        let newRemaining = max(0, remainingSeconds + delta)
        remainingSeconds = newRemaining
        if newRemaining > totalSeconds { totalSeconds = newRemaining }
        // If we nudged above halfway again, allow halfway alert to fire later.
        if totalSeconds > 0, Double(remainingSeconds) / Double(totalSeconds) > 0.5 {
            halfwayFired = false
        }
    }

    // MARK: - Derived
    /// 0...1 remaining progress (safe for 0 total)
    var progressRemaining: Double {
        guard totalSeconds > 0 else { return 0 }
        return max(0, min(1, Double(remainingSeconds) / Double(totalSeconds)))
    }

    // MARK: - Internal
    private func tick() {
        guard remainingSeconds > 0 else {
            // A round has completed.
            // Notify the View (for history + local notification) every round:
            completedAt = Date()

            if currentRound < roundsTotal {
                // Prepare next round without stopping the ticker
                currentRound += 1
                remainingSeconds = totalSeconds
                halfwayFired = false
                WKInterfaceDevice.current().play(.start) // subtle ping to begin new round
                return
            } else {
                // All rounds done — stop the timer
                stop()
                WKInterfaceDevice.current().play(.success)
                return
            }
        }

        // Normal countdown
        remainingSeconds -= 1

        // Halfway alert once per round
        if halfwayEnabled, totalSeconds > 0 {
            let half = totalSeconds / 2
            if !halfwayFired, remainingSeconds == half {
                halfwayFired = true
                WKInterfaceDevice.current().play(.directionUp)
            }
        }
    }
}

// MARK: - Small helpers
extension Int {
    /// Formats seconds as H:MM:SS when >= 1 hour, otherwise M:SS.
    var asClockString: String {
        let h = self / 3600
        let m = (self % 3600) / 60
        let s = self % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}
