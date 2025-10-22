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
    @Published var selectedPreset: Preset? = nil

    // MARK: - Private
    private var ticker: AnyCancellable?

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
        remainingSeconds = max(0, seconds)
        if let label = label {
            selectedPreset = Preset(name: label, seconds: seconds)
        } else {
            selectedPreset = nil
        }
    }

    /// Start ticking once per second if there is time remaining.
    func start() {
        guard remainingSeconds > 0 else { return }
        guard !isRunning else { return }
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
        } else {
            remainingSeconds = 0
        }
    }

    /// Stop and clear the ticker (used internally).
    func stop() {
        isRunning = false
        ticker?.cancel()
        ticker = nil
    }

    // MARK: - Internal
    private func tick() {
        guard remainingSeconds > 0 else {
            // Completed
            stop()
            // Haptic to notify the user on watch
            WKInterfaceDevice.current().play(.success)
            return
        }
        remainingSeconds -= 1
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
