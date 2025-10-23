import SwiftUI
import WatchKit
import UserNotifications

// Unique history model name to avoid duplicates
struct TimerHistoryItem: Identifiable, Codable {
    let id: UUID
    let when: Date
    let label: String
    let seconds: Int
}

struct ContentView: View {
    @StateObject private var vm = TimerViewModel()

    // Persist last custom H/M/S between launches (watch storage).
    @AppStorage("customHours")   private var customHours: Int = 0
    @AppStorage("customMinutes") private var customMinutes: Int = 0
    @AppStorage("customSeconds") private var customSeconds: Int = 20

    // Persist simple history (JSON-encoded string)
    @AppStorage("historyV1") private var historyJSON: String = "[]"
    // Persist user-saved presets (JSON of [PresetLite] from the previous message)
    @AppStorage("customPresetsV1") private var customPresetsJSON: String = "[]"

    @State private var showingCustom = false

    // MARK: - Compact-aware sizing (fits 41/44/45/49mm)
    private var bounds: CGRect { WKInterfaceDevice.current().screenBounds }
    private var isSmallWatch: Bool { min(bounds.width, bounds.height) <= 170 } // 41/44mm
    private var ringSize: CGFloat {
        // Smaller factor for small watches to avoid top clipping
        let base = min(bounds.width, bounds.height)
        return base * (isSmallWatch ? 0.66 : 0.74)
    }
    private var ringLine: CGFloat { max(4, ringSize * (isSmallWatch ? 0.075 : 0.09)) }
    private var timeFontSize: CGFloat { max(18, ringSize * (isSmallWatch ? 0.22 : 0.26)) }
    private var vStackSpacing: CGFloat { isSmallWatch ? 6 : 8 }
    private var topPad: CGFloat { isSmallWatch ? 2 : 8 }

    var body: some View {
        // ScrollView prevents vertical clipping on smaller faces
        ScrollView {
            VStack(spacing: vStackSpacing) {

                // PROGRESS RING + TIME
                ZStack {
                    Circle()
                        .trim(from: 0, to: 1)
                        .stroke(style: StrokeStyle(lineWidth: ringLine, lineCap: .round))
                        .opacity(0.15)

                    Circle()
                        .trim(from: 0, to: vm.progressRemaining)
                        .stroke(style: StrokeStyle(lineWidth: ringLine, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: vm.progressRemaining)

                    VStack(spacing: isSmallWatch ? 2 : 4) {
                        Text(vm.remainingSeconds.asClockString)
                            .font(.system(size: timeFontSize, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)

                        // Round indicator (hidden for single-round)
                        if vm.roundsTotal > 1 {
                            Text("Round \(vm.currentRound) of \(vm.roundsTotal)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .accessibilityLabel("Round \(vm.currentRound) of \(vm.roundsTotal)")
                        }
                    }
                }
                .frame(width: ringSize, height: ringSize)
                .padding(.top, topPad)

                // Quick adjust row
                HStack(spacing: isSmallWatch ? 10 : 14) {
                    Button("-10s") { vm.nudge(seconds: -10) }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Minus ten seconds")
                    Button("+10s") { vm.nudge(seconds: +10) }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Plus ten seconds")
                }

                // Start / Pause / Reset
                HStack(spacing: 8) {
                    if vm.isRunning {
                        Button("Pause") { vm.pause() }
                    } else {
                        Button("Start") { vm.start() }
                            .disabled(vm.remainingSeconds == 0)
                    }
                    Button("Reset") { vm.reset() }
                        .disabled(vm.selectedPreset == nil && vm.remainingSeconds == 0)
                }
                .buttonStyle(.borderedProminent)

                Divider().padding(.vertical, isSmallWatch ? 1 : 2)

                // Presets + Custom + Options + History
                List {
                    Section("Presets") {
                        ForEach(vm.presets) { preset in
                            presetRow(preset)
                        }
                        if !customPresets.isEmpty {
                            ForEach(customPresets, id: \.id) { p in
                                HStack {
                                    Text(p.name)
                                    Spacer()
                                    Text(p.seconds.asClockString)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    vm.setTimer(seconds: p.seconds, label: p.name)
                                    WKInterfaceDevice.current().play(.click)
                                }
                            }
                            .onDelete(perform: deleteCustomPresets)
                        }
                    }

                    Section {
                        // Pick custom duration
                        HStack {
                            Text("Custom…")
                            Spacer()
                            Text(totalCustomSeconds.asClockString)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { showingCustom = true }

                        // Save current custom duration as a personal preset
                        Button {
                            let secs = totalCustomSeconds
                            let label = customLabel(for: secs)
                            saveCustomPreset(name: label, seconds: secs)
                            WKInterfaceDevice.current().play(.click)
                        } label: {
                            HStack {
                                Text("Save Custom as Preset")
                                Spacer()
                                Text(totalCustomSeconds.asClockString)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .disabled(totalCustomSeconds == 0)
                    }

                    Section("Options") {
                        Picker("Rounds", selection: $vm.roundsTotal) {
                            ForEach(1...10, id: \.self) { Text("\($0)") }
                        }
                        Toggle("Halfway Alert", isOn: $vm.halfwayEnabled)
                    }

                    if !history.isEmpty {
                        Section("History") {
                            ForEach(history.prefix(5)) { item in
                                HStack {
                                    Text(item.label)
                                    Spacer()
                                    Text(item.seconds.asClockString)
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Button(role: .destructive) {
                                historyJSON = "[]"
                            } label: { Text("Clear History") }
                        }
                    }
                }
                .environment(\.defaultMinListRowHeight, isSmallWatch ? 30 : 34)
#if os(watchOS)
                .listStyle(.carousel)
#endif
            }
            .padding(.horizontal, 4)
        }
        .sheet(isPresented: $showingCustom) {
            TimerCustomSheet(
                hours: $customHours,
                minutes: $customMinutes,
                seconds: $customSeconds
            ) {
                vm.setTimer(seconds: totalCustomSeconds, label: "Custom")
                showingCustom = false
                WKInterfaceDevice.current().play(.click)
            }
        }
        // Ask once for notification permission
        .onAppear {
            requestNotificationPermissionIfNeeded()
            // Default a preset so Start works immediately
            if vm.remainingSeconds == 0 && vm.selectedPreset == nil {
                if let first = vm.presets.first {
                    vm.setTimer(seconds: first.seconds, label: first.name)
                }
            }
        }
        // When a (round) completes, save to history and notify
        .onChange(of: vm.completedAt) { _, newValue in
            guard newValue != nil else { return }
            appendHistory(label: vm.selectedPreset?.name ?? "Custom", seconds: vm.totalSeconds)
            scheduleCompletionNotification(isFinalRound: vm.currentRound == vm.roundsTotal && vm.remainingSeconds == 0)
        }
    }

    // MARK: - Rows
    private func presetRow(_ preset: Preset) -> some View {
        HStack {
            Text(preset.name)
            Spacer()
            Text(preset.seconds.asClockString)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            vm.setTimer(seconds: preset.seconds, label: preset.name)
            WKInterfaceDevice.current().play(.click)
        }
    }

    private var totalCustomSeconds: Int {
        (customHours * 3600) + (customMinutes * 60) + customSeconds
    }

    // MARK: - History helpers
    private var history: [TimerHistoryItem] {
        (try? JSONDecoder().decode([TimerHistoryItem].self, from: Data(historyJSON.utf8))) ?? []
    }

    private func appendHistory(label: String, seconds: Int) {
        var items = history
        items.insert(TimerHistoryItem(id: UUID(), when: Date(), label: label, seconds: seconds), at: 0)
        items = Array(items.prefix(20))
        if let data = try? JSONEncoder().encode(items),
           let str = String(data: data, encoding: .utf8) {
            historyJSON = str
        }
    }

    // MARK: - Local notifications (watch-friendly)
    private func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    private func scheduleCompletionNotification(isFinalRound: Bool) {
        let content = UNMutableNotificationContent()
        content.title = isFinalRound ? "Workout Complete" : "Round Finished"
        content.body = isFinalRound ? "Great job! All rounds are done." : "Nice! Start the next round."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    // MARK: - Custom preset storage (same helpers you already have)
    private struct PresetLite: Identifiable, Codable {
        let id: UUID
        let name: String
        let seconds: Int
    }
    private var customPresets: [PresetLite] {
        (try? JSONDecoder().decode([PresetLite].self, from: Data(customPresetsJSON.utf8))) ?? []
    }
    private func saveCustomPreset(name: String, seconds: Int) {
        guard seconds > 0 else { return }
        var list = customPresets
        list.insert(PresetLite(id: UUID(), name: name, seconds: seconds), at: 0)
        list = Array(list.prefix(6))
        if let data = try? JSONEncoder().encode(list),
           let str = String(data: data, encoding: .utf8) {
            customPresetsJSON = str
        }
    }
    private func deleteCustomPresets(at offsets: IndexSet) {
        var list = customPresets
        list.remove(atOffsets: offsets)
        if let data = try? JSONEncoder().encode(list),
           let str = String(data: data, encoding: .utf8) {
            customPresetsJSON = str
        }
    }
    private func customLabel(for seconds: Int) -> String {
        seconds.asClockString
    }
}

// Unique name to avoid duplicates
struct TimerCustomSheet: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var seconds: Int
    var onSet: () -> Void

    private let hourRange = Array(0...5)
    private let minuteRange = Array(0...59)
    private let secondRange = Array(0...59)

    var body: some View {
        VStack(spacing: 8) {
            Text("Custom Timer")
                .font(.headline)

            HStack {
                Picker("H", selection: $hours) { ForEach(hourRange, id: \.self) { Text("\($0)h") } }
                    .frame(maxWidth: .infinity)
                Picker("M", selection: $minutes) { ForEach(minuteRange, id: \.self) { Text("\($0)m") } }
                    .frame(maxWidth: .infinity)
                Picker("S", selection: $seconds) { ForEach(secondRange, id: \.self) { Text("\($0)s") } }
                    .frame(maxWidth: .infinity)
            }
            .labelsHidden()

            Text(totalSeconds.asClockString)
                .font(.title3)
                .monospacedDigit()
                .padding(.top, 2)

            Button("Set Timer") { onSet() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
        }
        .padding()
    }

    private var totalSeconds: Int {
        (hours * 3600) + (minutes * 60) + seconds
    }
}
