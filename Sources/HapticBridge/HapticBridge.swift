import Foundation

public enum HapticBridge {

    public struct Configuration {
        public var host: String
        public var port: Int
        public var verbose: Bool
        public var includeCoreHaptics: Bool

        public init(
            host: String = "127.0.0.1",
            port: Int = 49374,
            verbose: Bool = false,
            includeCoreHaptics: Bool = false
        ) {
            self.host = host
            self.port = port
            self.verbose = verbose
            self.includeCoreHaptics = includeCoreHaptics
        }
    }

    private static var didInstall = false
    private static let lock = NSLock()

    public static func install(_ configuration: Configuration = Configuration()) {
        lock.lock()
        defer { lock.unlock() }
        guard !didInstall else { return }
        didInstall = true

        HapticEventClient.shared.configure(
            host: configuration.host,
            port: configuration.port,
            verbose: configuration.verbose
        )

        #if targetEnvironment(simulator) && canImport(UIKit)
        Swizzler.installAll(includeCoreHaptics: configuration.includeCoreHaptics)
        if configuration.verbose {
            NSLog("[HapticBridge] installed — forwarding to \(configuration.host):\(configuration.port)")
        }
        #else
        if configuration.verbose {
            NSLog("[HapticBridge] install() is a no-op outside of the iOS Simulator")
        }
        #endif
    }

    public static func fire(_ event: HapticEvent) {
        HapticEventClient.shared.send(event)
    }
}
