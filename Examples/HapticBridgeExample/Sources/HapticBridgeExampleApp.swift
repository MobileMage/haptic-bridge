import SwiftUI
import HapticBridge

@main
struct HapticBridgeExampleApp: App {

    init() {
        #if DEBUG
        HapticBridge.install(.init(verbose: true))
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
