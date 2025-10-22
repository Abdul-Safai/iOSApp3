import SwiftUI

struct ContentView: View {
    @StateObject private var vm = TimerViewModel()

    // Persist last custom H/M/S between launches (watch storage).
    @AppStorage("customHours")   private var customHours: Int = 0
    @AppStorage("customMinutes") private var customMinutes: Int = 0
    @AppStorage("customSeconds") private var customSeconds: Int = 20

    @State private var showingCustom = false

    var body: some View {
        VStack(spacing: 8) {

            // Remaining time displayed prominently
            Text(vm.remainingSeconds.asClockString)
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .padding(.top, 2)

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

            Divider().padding(.vertical, 2)

            // Presets + Custom button
            List {
                Section("Presets") {
                    ForEach(vm.presets) { preset in
                        Button {
                            vm.setTimer(seconds: preset.seconds, label: preset.name)
                        } label: {
                            HStack {
                                Text(preset.name)
                                Spacer()
                                Text(preset.seconds.asClockString)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                Section {
                    Button {
                        showingCustom = true
                    } label: {
                        HStack {
                            Text("Custom…")
                            Spacer()
                            Text(totalCustomSeconds.asClockString)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
#if os(watchOS)
            .listStyle(.carousel) // watchOS-friendly scrolling list
#endif
        }
        .sheet(isPresented: $showingCustom) {
            CustomTimeSheet(
                hours: $customHours,
                minutes: $customMinutes,
                seconds: $customSeconds
            ) {
                vm.setTimer(seconds: totalCustomSeconds, label: "Custom")
                showingCustom = false
            }
        }
        .padding(.horizontal, 4)
    }

    private var totalCustomSeconds: Int {
        (customHours * 3600) + (customMinutes * 60) + customSeconds
    }
}

/// The custom time picker presented as a sheet.
/// Uses 3 separate pickers (H/M/S) that work nicely with the Digital Crown.
struct CustomTimeSheet: View {
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
                Picker("H", selection: $hours) {
                    ForEach(hourRange, id: \.self) { Text("\($0)h") }
                }
                .frame(maxWidth: .infinity)

                Picker("M", selection: $minutes) {
                    ForEach(minuteRange, id: \.self) { Text("\($0)m") }
                }
                .frame(maxWidth: .infinity)

                Picker("S", selection: $seconds) {
                    ForEach(secondRange, id: \.self) { Text("\($0)s") }
                }
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
