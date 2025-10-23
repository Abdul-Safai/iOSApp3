import SwiftUI
import WatchKit
import UserNotifications

struct TimerHistoryItem: Identifiable, Codable {
    let id: UUID
    let when: Date
    let label: String
    let seconds: Int
}

struct ContentView: View {
    @StateObject private var vm = TimerViewModel()

    @AppStorage("customHours")   private var customHours: Int = 0
    @AppStorage("customMinutes") private var customMinutes: Int = 0
    @AppStorage("customSeconds") private var customSeconds: Int = 20

    @AppStorage("historyV1") private var historyJSON: String = "[]"
    @AppStorage("customPresetsV1") private var customPresetsJSON: String = "[]"

    @State private var showingCustom = false

    // Compact layout helpers (same as your latest)
    private var bounds: CGRect { WKInterfaceDevice.current().screenBounds }
    private var isSmallWatch: Bool { min(bounds.width, bounds.height) <= 170 }
    private var ringSize: CGFloat {
        let base = min(bounds.width, bounds.height)
        return base * (isSmallWatch ? 0.66 : 0.74)
    }
    private var ringLine: CGFloat { max(4, ringSize * (isSmallWatch ? 0.075 : 0.09)) }
    private var timeFontSize: CGFloat { max(18, ringSize * (isSmallWatch ? 0.22 : 0.26)) }
    private var vStackSpacing: CGFloat { isSmallWatch ? 6 : 8 }
    private var topPad: CGFloat { isSmallWatch ? 2 : 8 }

    var body: some View {
        ScrollView {
            VStack(spacing: vStackSpacing) {
                // Ring + time (unchanged, uses vm.isResting)
                ZStack {
                    Circle().trim(from: 0, to: 1)
                        .stroke(style: StrokeStyle(lineWidth: ringLine, lineCap: .round))
                        .opacity(0.12)

                    Circle()
                        .trim(from: 0, to: vm.progressRemaining)
                        .stroke(style: StrokeStyle(lineWidth: ringLine, lineCap: .round))
                        .foregroundStyle(vm.isResting ? .gray : .accentColor)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: vm.progressRemaining)

                    VStack(spacing: isSmallWatch ? 2 : 4) {
                        if vm.roundsTotal > 1 {
                            Text(vm.isResting ? "REST" : "WORK")
                                .font(.caption2)
                                .foregroundStyle(vm.isResting ? .secondary : .primary)
                        }

                        Text((vm.isResting ? vm.restRemaining : vm.remainingSeconds).asClockString)
                            .font(.system(size: timeFontSize, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)

                        if vm.roundsTotal > 1 && !vm.isResting {
                            Text("Round \(vm.currentRound) of \(vm.roundsTotal)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
                .frame(width: ringSize, height: ringSize)
                .padding(.top, topPad)

                // Quick adjust (disabled during rest)
                HStack(spacing: isSmallWatch ? 10 : 14) {
                    Button("-10s") { vm.nudge(seconds: -10) }
                        .buttonStyle(.bordered)
                        .disabled(vm.isResting)
                    Button("+10s") { vm.nudge(seconds: +10) }
                        .buttonStyle(.bordered)
                        .disabled(vm.isResting)
                }

                // Start/Pause/Reset
                HStack(spacing: 8) {
                    if vm.isRunning {
                        Button("Pause") { vm.pause() }
                    } else {
                        Button("Start") { vm.start() }
                            .disabled(vm.displayIsZero)
                    }
                    Button("Reset") { vm.reset() }
                        .disabled(vm.selectedPreset == nil && vm.remainingSeconds == 0 && !vm.isResting)
                }
                .buttonStyle(.borderedProminent)

                Divider().padding(.vertical, isSmallWatch ? 1 : 2)

                // List: Presets / Custom / Options / History  (unchanged from your latest)
                List {
                    Section("Presets") {
                        ForEach(vm.presets) { preset in
                            presetRow(preset)
                        }
                        if !customPresets.isEmpty {
                            ForEach(customPresets, id: \.id) { p in
                                HStack {
                                    Text(p.name); Spacer()
                                    Text(p.seconds.asClockString).foregroundStyle(.secondary).monospacedDigit()
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
                        HStack {
                            Text("Custom…"); Spacer()
                            Text(totalCustomSeconds.asClockString).foregroundStyle(.secondary).monospacedDigit()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { showingCustom = true }

                        Button {
                            let secs = totalCustomSeconds
                            let label = customLabel(for: secs)
                            saveCustomPreset(name: label, seconds: secs)
                            WKInterfaceDevice.current().play(.click)
                        } label: {
                            HStack {
                                Text("Save Custom as Preset"); Spacer()
                                Text(totalCustomSeconds.asClockString).foregroundStyle(.secondary).monospacedDigit()
                            }
                        }
                        .disabled(totalCustomSeconds == 0)
                    }

                    Section("Options") {
                        Picker("Rounds", selection: $vm.roundsTotal) {
                            ForEach(1...10, id: \.self) { Text("\($0)") }
                        }
                        Toggle("Halfway Alert", isOn: $vm.halfwayEnabled)
                        Picker("Rest", selection: $vm.restSecondsSetting) {
                            ForEach([0,10,20,30,45,60], id: \.self) { s in
                                Text(s == 0 ? "No Rest" : "\(s)s")
                            }
                        }
                    }

                    if !history.isEmpty {
                        Section("History") {
                            ForEach(history.prefix(5)) { item in
                                HStack {
                                    Text(item.label); Spacer()
                                    Text(item.seconds.asClockString).monospacedDigit().foregroundStyle(.secondary)
                                }
                            }
                            Button(role: .destructive) { historyJSON = "[]"} label: { Text("Clear History") }
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
                hours: $customHours, minutes: $customMinutes, seconds: $customSeconds
            ) {
                vm.setTimer(seconds: totalCustomSeconds, label: "Custom")
                showingCustom = false
                WKInterfaceDevice.current().play(.click)
            }
        }
        // 🔔 We keep notifications, but we no longer auto-save each round here.
        .onChange(of: vm.completedAt) { _, newValue in
            guard newValue != nil else { return }
            scheduleCompletionNotification(isFinalRound: vm.summary != nil)
        }
        // ✅ Present Summary when workout completes
        .sheet(item: $vm.summary) { summary in
            WorkoutSummaryView(
                summary: summary,
                onSave: {
                    // Save one combined history item
                    let label = makeSummaryLabel(summary)
                    appendHistory(label: label, seconds: summary.totalSeconds)
                }
            )
        }
        .onAppear {
            requestNotificationPermissionIfNeeded()
            if vm.remainingSeconds == 0 && vm.selectedPreset == nil, let first = vm.presets.first {
                vm.setTimer(seconds: first.seconds, label: first.name)
            }
        }
    }

    // MARK: - Helper Views / funcs
    private func presetRow(_ preset: Preset) -> some View {
        HStack {
            Text(preset.name); Spacer()
            Text(preset.seconds.asClockString).foregroundStyle(.secondary).monospacedDigit()
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

    private func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    private func scheduleCompletionNotification(isFinalRound: Bool) {
        let content = UNMutableNotificationContent()
        content.title = isFinalRound ? "Workout Complete" : "Round Finished"
        content.body = isFinalRound ? "Great job! All rounds are done." : "Nice! Rest up or start next round."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger))
    }

    // Custom Presets (same as before)
    private struct PresetLite: Identifiable, Codable {
        let id: UUID; let name: String; let seconds: Int
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
    private func customLabel(for seconds: Int) -> String { seconds.asClockString }

    private func makeSummaryLabel(_ s: WorkoutSummary) -> String {
        let restText = s.restSecondsPerGap > 0 ? " + rest \(s.restSecondsPerGap)s" : ""
        return "\(s.presetName) ×\(s.rounds)\(restText)"
    }
}

// MARK: - Summary Sheet UI
private struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 8) {
            Text("Workout Summary").font(.headline)

            Group {
                row("Preset", summary.presetName)
                row("Rounds", "\(summary.rounds)")
                row("Work / round", summary.workSecondsPerRound.asClockString)
                row("Total Work", summary.totalWorkSeconds.asClockString)
                row("Total Rest", summary.totalRestSeconds.asClockString)
                Divider().padding(.vertical, 2)
                row("Total Time", summary.totalSeconds.asClockString)
            }

            Button("Save to History") {
                onSave()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)

            Button("Done") { dismiss() }
                .buttonStyle(.bordered)
        }
        .padding()
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(.secondary)
        }
    }
}

// MARK: - Seconds → clock string
extension Int {
    var asClockString: String {
        let h = self / 3600
        let m = (self % 3600) / 60
        let s = self % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
