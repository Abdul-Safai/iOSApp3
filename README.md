# iOSApp3 — watchOS Workout Timer (SwiftUI)

A simple, device-focused **watchOS** app built with **SwiftUI** for Assignment 6.  
It demonstrates a timer with presets and a custom time picker that works naturally with the Apple Watch Digital Crown.

## ✨ Features
- Preset timers (20s, 1m, 5m, 10m)
- **Custom time** via `.sheet` with three `Picker`s (hours / minutes / seconds)
- **Start / Pause / Reset** controls
- **Haptic feedback** on completion
- Remembers last custom time via `@AppStorage`
- Clean, beginner-friendly comments throughout the code

## 🛠 Tech
- watchOS App (SwiftUI)
- Combine `Timer.publish` for 1-sec ticks

## 🚀 Run Instructions
1. Open `iOSApp3.xcodeproj` (or the `.xcworkspace` if you add packages later) in Xcode.
2. Select a **watchOS Simulator** (e.g., Apple Watch Series 9).
3. **Build & Run**.

## 📁 Project Structure (key files)
- `WorkoutTimerApp.swift` — App entry point
- `TimerViewModel.swift` — Timer state, ticking, haptics, presets
- `ContentView.swift` — UI (time display, controls, presets list, custom sheet)

## ✅ Assignment Notes
- **Requirement 1:** New project + GitHub repo `iOSApp3` ✔️  
- **Requirement 2:** Device-specific app (**watchOS**) using features from this week (Pickers, sheet, digital-crown-friendly UI) ✔️  
- **Requirement 3:** Code is **commented** and **committed/pushed** ✔️

## 🧩 Future Enhancements (optional)
- Progress ring using `Circle().trim(...)`
- Complications
- Local notification when timer completes (if app isn’t foreground)

## 📷 Screens (optional)
_Add screenshots here when ready (e.g., Simulator captures)._

---
**Author:** Abdul Aziz Safai  
**Course:** triOS College — iOS (Assignment 6)
