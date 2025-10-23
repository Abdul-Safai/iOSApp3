import SwiftUI

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
            Text("Custom Timer").font(.headline)

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
