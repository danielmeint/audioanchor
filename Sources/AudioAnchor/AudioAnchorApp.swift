import SwiftUI

@main
struct AudioAnchorApp: App {
    @StateObject private var manager = AudioManager()

    var body: some Scene {
        MenuBarExtra("AudioAnchor", systemImage: "waveform") {
            MenuContentView()
                .environmentObject(manager)
        }
        .menuBarExtraStyle(.window)
    }
}
